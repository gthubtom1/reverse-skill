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
    $lease = Get-Content -LiteralPath $LeasePath -Raw | ConvertFrom-Json
    $leasePid = 0
    if (-not [int]::TryParse([string](Get-LeaseField $lease 'pid'), [ref]$leasePid) -or $leasePid -le 0) {
        throw 'Lease has no valid PID; cleanup is blocked'
    }
    return $lease
}

function Get-LeaseField($Lease, [string]$Name) {
    if ($null -ne $Lease -and $null -ne $Lease.PSObject.Properties[$Name]) { return $Lease.$Name }
    return $null
}

function ConvertTo-ProcessIdentity($CimProcess) {
    $created = $null
    try {
        if ($CimProcess.CreationDate -is [datetime]) {
            $created = $CimProcess.CreationDate.ToUniversalTime()
        } elseif ($CimProcess.CreationDate -is [string] -and $CimProcess.CreationDate) {
            $created = [System.Management.ManagementDateTimeConverter]::ToDateTime($CimProcess.CreationDate).ToUniversalTime()
        }
    } catch { $created = $null }
    [pscustomobject]@{
        pid = [int]$CimProcess.ProcessId
        parent_pid = [int]$CimProcess.ParentProcessId
        executable = [string]$CimProcess.ExecutablePath
        creation_filetime_utc = if ($null -ne $created) { $created.ToFileTimeUtc() } else { $null }
    }
}

function Get-ProcessIdentity([int]$ProcessId) {
    # A failed query is unknown, never evidence of absence.
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -OperationTimeoutSec 2 -ErrorAction Stop | Select-Object -First 1
    if ($null -eq $cim) { return $null }
    return ConvertTo-ProcessIdentity $cim
}

function Test-ProcessIdentity($Expected, $Actual) {
    if ($null -eq $Expected -or $null -eq $Actual) { return $false }
    $expectedTime = 0L
    $actualTime = 0L
    if (-not [int64]::TryParse([string]$Expected.creation_filetime_utc, [ref]$expectedTime) -or $expectedTime -le 0) { return $false }
    if (-not [int64]::TryParse([string]$Actual.creation_filetime_utc, [ref]$actualTime)) { return $false }
    return ($Expected.pid -eq $Actual.pid -and $expectedTime -eq $actualTime -and
        -not [string]::IsNullOrWhiteSpace($Expected.executable) -and
        [string]::Equals($Expected.executable, $Actual.executable, [System.StringComparison]::OrdinalIgnoreCase))
}

function Test-RootOwnership($Lease, [ref]$Identity) {
    $Identity.Value = Get-ProcessIdentity -ProcessId ([int]$Lease.pid)
    $expected = [pscustomobject]@{
        pid = [int]$Lease.pid
        executable = [string](Get-LeaseField $Lease 'root_process_executable')
        creation_filetime_utc = Get-LeaseField $Lease 'root_creation_filetime_utc'
    }
    return Test-ProcessIdentity $expected $Identity.Value
}

function Get-OwnedSnapshot($RootIdentity) {
    $byParent = @{}
    $snapshotRoot = $null
    foreach ($proc in @(Get-CimInstance Win32_Process -OperationTimeoutSec 2 -ErrorAction Stop)) {
        $identity = ConvertTo-ProcessIdentity $proc
        if ($identity.pid -eq $RootIdentity.pid) { $snapshotRoot = $identity }
        if (-not $byParent.ContainsKey($identity.parent_pid)) { $byParent[$identity.parent_pid] = @() }
        $byParent[$identity.parent_pid] += $identity
    }
    if (-not (Test-ProcessIdentity $RootIdentity $snapshotRoot)) { throw 'Root changed during snapshot' }
    $owned = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    [void]$owned.Add($RootIdentity)
    $seen[$RootIdentity.pid] = $true
    for ($i = 0; $i -lt $owned.Count; $i++) {
        $parent = $owned[$i]
        if (-not $byParent.ContainsKey($parent.pid)) { continue }
        foreach ($child in $byParent[$parent.pid]) {
            if ($seen.ContainsKey($child.pid) -or $owned.Count -ge 256) { throw 'Process snapshot cycle or 256-process limit reached' }
            if (-not (Test-ProcessIdentity $child $child) -or $child.creation_filetime_utc -lt $parent.creation_filetime_utc) {
                throw "Unknown child identity or reused parent PID: $($child.pid)"
            }
            $seen[$child.pid] = $true
            [void]$owned.Add($child)
        }
    }
    return $owned.ToArray()
}

function Get-ProcessState([int]$ProcessId) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    $identity = Get-ProcessIdentity -ProcessId $ProcessId
    if ($null -eq $process) {
        return [pscustomobject]@{ pid = $ProcessId; running = $false }
    }
    return [pscustomobject]@{
        pid = $ProcessId
        running = $true
        name = $process.ProcessName
        executable = if ($identity) { $identity.executable } else { $null }
        creation_filetime_utc = if ($identity) { $identity.creation_filetime_utc } else { $null }
        started_at = $process.StartTime.ToString('o')
        working_set_mb = [math]::Round($process.WorkingSet64 / 1MB, 1)
    }
}

function Stop-OwnedTree($Lease) {
    $blocked = New-Object System.Collections.Generic.List[string]
    $remaining = New-Object System.Collections.Generic.List[int]
    # A snapshot cannot account for exited parents, late forks or detached children.
    [void]$blocked.Add('No Job Object containment; complete descendant cleanup cannot be verified')
    $owned = @()
    $handles = New-Object System.Collections.Generic.List[object]
    try {
        $rootIdentity = $null
        if (-not (Test-RootOwnership -Lease $Lease -Identity ([ref]$rootIdentity))) {
            throw 'Root identity unknown/mismatched, or legacy lease lacks creation/executable identity'
        }
        $owned = @(Get-OwnedSnapshot $rootIdentity)
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        # Pin and validate parents before children, before terminating anything.
        # If an ancestor has exited/reused its PID, the snapshot is not ownership.
        foreach ($expected in $owned) {
            if ($timer.Elapsed.TotalSeconds -ge 10) { throw 'Cleanup time budget reached' }
            $process = Get-Process -Id $expected.pid -ErrorAction Stop
            [void]$handles.Add($process)
            $null = $process.Handle
            if ($process.HasExited -or -not (Test-ProcessIdentity $expected (Get-ProcessIdentity $expected.pid))) {
                throw "Snapshot identity changed: $($expected.pid)"
            }
        }
        # Reverse traversal, not descending PID order: children precede parents.
        for ($i = $owned.Count - 1; $i -ge 0; $i--) {
            $expected = $owned[$i]
            $process = $handles[$i]
            try {
                if ($timer.Elapsed.TotalSeconds -ge 10) { throw 'Cleanup time budget reached' }
                $current = Get-ProcessIdentity $expected.pid
                if ($null -eq $current) { continue }
                if (-not (Test-ProcessIdentity $expected $current)) { throw 'Process identity changed before stop' }
                $process.Kill()
                if (-not $process.WaitForExit(250)) { throw 'Exit not confirmed within wait budget' }
            } catch {
                [void]$blocked.Add("PID $($expected.pid): $($_.Exception.Message)")
                # Preserve ancestors for reconciliation when a child cannot be stopped.
                break
            }
        }
        foreach ($expected in $owned) {
            if ($timer.Elapsed.TotalSeconds -ge 15) { throw 'Cleanup verification time budget reached' }
            $current = Get-ProcessIdentity $expected.pid
            if ($null -ne $current) {
                [void]$remaining.Add($expected.pid)
                if (-not (Test-ProcessIdentity $expected $current)) { [void]$blocked.Add("PID reused during verification: $($expected.pid)") }
            }
        }
    } catch {
        [void]$blocked.Add($_.Exception.Message)
        # Includes unknown PIDs; do not present query failures as verified absence.
        foreach ($processId in (@([int]$Lease.pid) + @($owned | ForEach-Object { $_.pid }))) {
            if (-not $remaining.Contains($processId)) { [void]$remaining.Add($processId) }
        }
    } finally {
        foreach ($process in $handles) { $process.Dispose() }
    }
    [pscustomobject]@{
        remaining = @($remaining.ToArray())
        blocked = @($blocked.ToArray())
        observed_cleanup_completed = ($owned.Count -gt 0 -and $remaining.Count -eq 0 -and $blocked.Count -eq 1)
    }
}

switch ($Action) {
    'Start' {
        if ([string]::IsNullOrWhiteSpace($FilePath)) { throw 'FilePath is required for Start' }
        if ([string]::IsNullOrWhiteSpace($CaseId)) { throw 'CaseId is required for Start' }
        if ([string]::IsNullOrWhiteSpace($WorkItemId)) { throw 'WorkItemId is required for Start' }
        if ([string]::IsNullOrWhiteSpace($Provider)) { throw 'Provider is required for Start' }
        if (Test-Path -LiteralPath $LeasePath) {
            throw "Existing lease requires cleanup reconciliation before replacement: $LeasePath"
        }
        $resolvedExecutable = (Resolve-Path -LiteralPath $FilePath).Path
        $parent = Split-Path -Parent $LeasePath
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        $startParams = @{
            FilePath = $FilePath
            PassThru = $true
            WindowStyle = 'Hidden'
        }
        if ($ArgumentList) { $startParams.ArgumentList = $ArgumentList }
        if ($WorkingDirectory) { $startParams.WorkingDirectory = $WorkingDirectory }
        # Reserve the lease before launching; two Starts must not overwrite
        # each other's process identity after both pass the existence check.
        $reservation = [System.IO.File]::Open($LeasePath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $pending = [System.Text.Encoding]::UTF8.GetBytes('{"status":"startup-pending"}')
            $reservation.Write($pending, 0, $pending.Length)
        } finally { $reservation.Dispose() }
        $process = Start-Process @startParams
        $startedPid = $process.Id
        # Persist the PID even if identity capture fails; unknown must stay blocked.
        $lease = [ordered]@{
            case_id = $CaseId
            work_item_id = $WorkItemId
            provider = $Provider
            pid = $startedPid
            parent_pid = $PID
            executable = $resolvedExecutable
            root_process_executable = $null
            root_creation_filetime_utc = $null
            started_at = (Get-Date).ToString('o')
            expected_exit = $true
            cleanup_on = @('success', 'timeout', 'cancellation', 'session_interruption')
        }
        try {
            $lease | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $LeasePath -Encoding UTF8
            $null = $process.Handle
            $rootIdentity = Get-ProcessIdentity -ProcessId $startedPid
            if ($process.HasExited -or -not (Test-ProcessIdentity $rootIdentity $rootIdentity)) {
                throw 'Creation time/executable identity unavailable or launched process already exited'
            }
            $lease.root_process_executable = $rootIdentity.executable
            $lease.root_creation_filetime_utc = $rootIdentity.creation_filetime_utc
            $lease | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $LeasePath -Encoding UTF8
        } catch {
            # Do not stop an unknown PID, including on the startup failure path.
            throw "Startup blocked for PID $startedPid; inspect lease/process: $($_.Exception.Message)"
        } finally {
            $process.Dispose()
        }
        $lease | ConvertTo-Json -Depth 5
    }
    'Status' {
        $lease = Read-Lease
        $rootPid = [int]$lease.pid
        $states = @()
        $blocked = @()
        try {
            $states += Get-ProcessState -ProcessId $rootPid
            $rootIdentity = $null
            if (-not (Test-RootOwnership -Lease $lease -Identity ([ref]$rootIdentity))) { throw 'Root ownership unknown or mismatched' }
            foreach ($child in @(Get-OwnedSnapshot $rootIdentity | Select-Object -Skip 1)) {
                $states += Get-ProcessState -ProcessId $child.pid
            }
        } catch { $blocked += $_.Exception.Message }
        [pscustomobject]@{
            lease = $lease
            processes = $states
            blocked = $blocked
        } | ConvertTo-Json -Depth 8
    }
    'Stop' {
        $lease = Read-Lease
        $cleanup = Stop-OwnedTree -Lease $lease
        [pscustomobject]@{
            lease = $lease
            cleanup_requested = $true
            cleanup_completed = $false
            observed_cleanup_completed = $cleanup.observed_cleanup_completed
            remaining_pids = $cleanup.remaining
            blocked = $cleanup.blocked
        } | ConvertTo-Json -Depth 8
    }
    'Cleanup' {
        $lease = Read-Lease
        $cleanup = Stop-OwnedTree -Lease $lease
        [pscustomobject]@{
            lease = $lease
            cleanup_requested = $true
            cleanup_completed = $false
            observed_cleanup_completed = $cleanup.observed_cleanup_completed
            remaining_pids = $cleanup.remaining
            blocked = $cleanup.blocked
        } | ConvertTo-Json -Depth 8
    }
}
