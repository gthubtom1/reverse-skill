[CmdletBinding()]
param(
    [ValidateSet('Start', 'Status', 'Stop', 'Cleanup')]
    [string]$Action = 'Status',
    [Parameter(Mandatory = $true)]
    [string]$LeasePath,
    [string]$FilePath,
    [string[]]$ArgumentList,
    [string]$WorkingDirectory,
    [int]$RootPid,
    [string]$CaseId,
    [string]$WorkItemId,
    [string]$Provider
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Lease {
    if (-not (Test-Path -LiteralPath $LeasePath)) {
        throw "Lease not found: $LeasePath"
    }
    return (Get-Content -LiteralPath $LeasePath -Raw | ConvertFrom-Json)
}

function Get-DescendantPids([int]$RootPid) {
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $RootPid" -ErrorAction SilentlyContinue)
    $result = @()
    foreach ($child in $children) {
        $result += [int]$child.ProcessId
        $result += Get-DescendantPids -RootPid ([int]$child.ProcessId)
    }
    return $result
}

function Get-ProcessState([int]$ProcessId) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return [pscustomobject]@{ pid = $ProcessId; running = $false }
    }
    return [pscustomobject]@{
        pid = $ProcessId
        running = $true
        name = $process.ProcessName
        started_at = $process.StartTime.ToString('o')
        working_set_mb = [math]::Round($process.WorkingSet64 / 1MB, 1)
    }
}

function Stop-OwnedTree([int]$RootPid) {
    $descendants = @(Get-DescendantPids -RootPid $RootPid | Sort-Object -Descending)
    foreach ($childPid in $descendants) {
        Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 250
    $remaining = @($RootPid) + $descendants | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }
    return @($remaining)
}

switch ($Action) {
    'Start' {
        if ([string]::IsNullOrWhiteSpace($FilePath)) { throw 'FilePath is required for Start' }
        if ([string]::IsNullOrWhiteSpace($CaseId)) { throw 'CaseId is required for Start' }
        if ([string]::IsNullOrWhiteSpace($WorkItemId)) { throw 'WorkItemId is required for Start' }
        if ([string]::IsNullOrWhiteSpace($Provider)) { throw 'Provider is required for Start' }
        if (Test-Path -LiteralPath $LeasePath) {
            $existing = Get-Content -LiteralPath $LeasePath -Raw | ConvertFrom-Json
            if ($existing.pid -and (Get-Process -Id ([int]$existing.pid) -ErrorAction SilentlyContinue)) {
                throw "Active lease already exists for PID $($existing.pid): $LeasePath"
            }
        }
        $parent = Split-Path -Parent $LeasePath
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        $startParams = @{
            FilePath = $FilePath
            PassThru = $true
            WindowStyle = 'Hidden'
        }
        if ($ArgumentList) { $startParams.ArgumentList = $ArgumentList }
        if ($WorkingDirectory) { $startParams.WorkingDirectory = $WorkingDirectory }
        $process = Start-Process @startParams
        $lease = [ordered]@{
            case_id = $CaseId
            work_item_id = $WorkItemId
            provider = $Provider
            pid = $process.Id
            parent_pid = $PID
            executable = (Resolve-Path -LiteralPath $FilePath).Path
            started_at = (Get-Date).ToString('o')
            expected_exit = $true
            cleanup_on = @('success', 'timeout', 'cancellation', 'session_interruption')
        }
        $lease | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $LeasePath -Encoding UTF8
        $lease | ConvertTo-Json -Depth 5
    }
    'Status' {
        $lease = Read-Lease
        $rootPid = [int]$lease.pid
        $states = @((Get-ProcessState -ProcessId $rootPid))
        foreach ($childPid in @(Get-DescendantPids -RootPid $rootPid)) {
            $states += Get-ProcessState -ProcessId $childPid
        }
        [pscustomobject]@{
            lease = $lease
            processes = $states
        } | ConvertTo-Json -Depth 8
    }
    'Stop' {
        $lease = Read-Lease
        $remaining = @(Stop-OwnedTree -RootPid ([int]$lease.pid))
        [pscustomobject]@{
            lease = $lease
            cleanup_requested = $true
            cleanup_completed = ($remaining.Count -eq 0)
            remaining_pids = $remaining
        } | ConvertTo-Json -Depth 8
    }
    'Cleanup' {
        $lease = Read-Lease
        $remaining = @(Stop-OwnedTree -RootPid ([int]$lease.pid))
        [pscustomobject]@{
            lease = $lease
            cleanup_requested = $true
            cleanup_completed = ($remaining.Count -eq 0)
            remaining_pids = $remaining
        } | ConvertTo-Json -Depth 8
    }
}
