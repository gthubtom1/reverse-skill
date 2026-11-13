<#
.SYNOPSIS
Start IDA Pro MCP HTTP server (background, non-blocking)

.DESCRIPTION
1. Resolve IDADIR (env / portable IDA / registry / common paths)
2. Resolve idalib-mcp (PATH, IDA Python314 Scripts, or python -m)
3. If HTTP already healthy, reuse it (unless -Force)
4. Otherwise kill stale listeners and start a logged supervisor
5. Wait for service ready (max 30 seconds)
6. Output OK:<tool_count>, OK:<tool_count>:reuse, or ERR:...

Usage: run without parameters
#>

param(
    [string]$IdaDir,
    [int]$Port = 13337,
    [string]$ServerPath,
    [int]$WaitSeconds = 30,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'IdaOpenHelpers.ps1')

function Get-IdaMcpLogDir {
    $dir = Join-Path $env:LOCALAPPDATA 'reverse-skill\ida-mcp'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Rotate-IdaMcpLog {
    param(
        [string]$Path,
        [int]$MaxBytes = 5MB
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ((Get-Item -LiteralPath $Path).Length -le $MaxBytes) { return }
    $bak = "$Path.1"
    if (Test-Path -LiteralPath $bak) {
        Remove-Item -LiteralPath $bak -Force
    }
    Move-Item -LiteralPath $Path -Destination $bak -Force
}

function Test-IdaMcpHealth {
    param([int]$Port)
    $probe = Probe-IdaMcp -Port $Port
    if ($probe.Status -eq 'healthy') { return $probe.Count }
    return 0
}

function Probe-IdaMcp {
    param([int]$Port)
    $owners = @(Get-IdaMcpPortOwners -Port $Port)
    $guiOwners = @($owners | Where-Object { Test-IdaGuiProcess -ProcessId $_ })
    $listening = $owners.Count -gt 0

    try {
        $r = Invoke-RestMethod "http://127.0.0.1:$Port/mcp" -Method Post `
            -Body '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' `
            -ContentType 'application/json' -TimeoutSec 3 -ErrorAction Stop
        $tools = @($r.result.tools)
        $count = $tools.Count
        $names = @($tools | ForEach-Object { $_.name })
        # Supervisor without --unsafe is "up" but missing py_eval. Treat as stale.
        if ($count -gt 0 -and ($names -contains 'py_eval')) {
            return @{ Status = 'healthy'; Count = $count; Owners = $owners; GuiOwners = $guiOwners }
        }
        if ($count -gt 0) {
            return @{ Status = 'stale'; Count = $count; Owners = $owners; GuiOwners = $guiOwners }
        }
    } catch {}

    if ($guiOwners.Count -gt 0) {
        return @{ Status = 'gui_busy'; Count = 0; Owners = $owners; GuiOwners = $guiOwners }
    }
    # Single-threaded supervisor cannot answer tools/list during idb_open.
    # A listen socket is busy, not dead — never taskkill on RPC timeout.
    if ($listening) {
        return @{ Status = 'busy'; Count = 0; Owners = $owners; GuiOwners = $guiOwners }
    }
    return @{ Status = 'down'; Count = 0; Owners = $owners; GuiOwners = $guiOwners }
}

function Get-IdaMcpPortOwners {
    param([int]$Port)
    return @(
        Get-NetTCPConnection -ErrorAction Stop |
            Where-Object { $_.LocalPort -eq $Port -and $_.State -eq 'Listen' } |
            Select-Object -ExpandProperty OwningProcess -Unique |
            Where-Object { $_ -and $_ -gt 0 }
    )
}

function Get-IdaMcpProcessInfo {
    param([int]$ProcessId)
    return Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -OperationTimeoutSec 2 -ErrorAction Stop
}

function Get-IdaMcpIdentity {
    param($ProcessInfo)
    if ($null -eq $ProcessInfo) { return $null }
    $created = $null
    try {
        if ($ProcessInfo.CreationDate -is [datetime]) {
            $created = $ProcessInfo.CreationDate.ToUniversalTime()
        } elseif ($ProcessInfo.CreationDate -is [string] -and $ProcessInfo.CreationDate) {
            $created = [System.Management.ManagementDateTimeConverter]::ToDateTime($ProcessInfo.CreationDate).ToUniversalTime()
        }
    } catch { $created = $null }
    return [pscustomobject]@{
        pid = [int]$ProcessInfo.ProcessId
        executable = [string]$ProcessInfo.ExecutablePath
        creation_filetime_utc = if ($null -ne $created) { $created.ToFileTimeUtc() } else { $null }
        command_line = [string]$ProcessInfo.CommandLine
    }
}

function Test-IdaMcpIdentity {
    param($Expected, $Actual)
    if ($null -eq $Expected -or $null -eq $Actual) { return $false }
    foreach ($field in @('pid', 'executable', 'creation_filetime_utc', 'command_line')) {
        if ($null -eq $Expected.PSObject.Properties[$field] -or $null -eq $Actual.PSObject.Properties[$field]) { return $false }
    }
    $expectedTime = 0L
    $actualTime = 0L
    if (-not [int64]::TryParse([string]$Expected.creation_filetime_utc, [ref]$expectedTime) -or $expectedTime -le 0) { return $false }
    if (-not [int64]::TryParse([string]$Actual.creation_filetime_utc, [ref]$actualTime)) { return $false }
    return ($Expected.pid -eq $Actual.pid -and $expectedTime -eq $actualTime -and
        -not [string]::IsNullOrWhiteSpace($Expected.executable) -and
        -not [string]::IsNullOrWhiteSpace($Expected.command_line) -and
        [string]::Equals($Expected.executable, $Actual.executable, [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals($Expected.command_line, $Actual.command_line, [System.StringComparison]::Ordinal))
}

function Test-IdaGuiProcess {
    param([int]$ProcessId)
    $proc = Get-IdaMcpProcessInfo -ProcessId $ProcessId
    if (-not $proc) { return $false }
    return [string]$proc.Name -match '(?i)^(ida|ida64|idaq|idaq64)\.exe$'
}

function Test-IdaMcpSupervisorCandidate {
    param($ProcessInfo, [int]$Port)
    $name = [string]$ProcessInfo.Name
    $cmd = [string]$ProcessInfo.CommandLine
    if ($name -match '(?i)^(ida|ida64|idaq|idaq64)\.exe$') { return $false }
    $managed = if ($name -match '(?i)^(python|pythonw|cmd)\.exe$') {
        $cmd -match '(?i)(run-supervisor\.py|idalib_supervisor|idalib-mcp|ida-pro-mcp)'
    } else {
        $name -match '(?i)^(idalib-mcp|ida-pro-mcp|idalib_supervisor)'
    }
    $portToken = '(?i)(^|\s)--port(?:\s|=)["'']?' + [regex]::Escape([string]$Port) + '["'']?(\s|$)'
    return $managed -and ($cmd -match $portToken)
}

function Test-ManagedSupervisorProcess {
    param(
        [int]$ProcessId,
        [string]$IdaDirPath,
        [int]$Port,
        $ProcessInfo
    )
    $proc = $ProcessInfo
    if ($null -eq $proc) { $proc = Get-IdaMcpProcessInfo -ProcessId $ProcessId }
    if (-not $proc -or -not (Test-IdaMcpSupervisorCandidate $proc $Port)) { return $false }
    $cmd = [string]$proc.CommandLine
    # Port alone is not ownership. A saved launch identity binds env-only IDADIR
    # to this installation, including external Python + run-supervisor.py.
    $lease = $script:IdaMcpLease
    if ($null -ne $lease -and $null -ne $lease.PSObject.Properties['identity'] -and
        $null -ne $lease.PSObject.Properties['ida_dir'] -and $null -ne $lease.PSObject.Properties['port'] -and
        $lease.port -eq $Port -and
        [string]::Equals([string]$lease.ida_dir, $IdaDirPath, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-IdaMcpIdentity $lease.identity (Get-IdaMcpIdentity $proc))) { return $true }
    # Legacy processes need an explicit installation path in their command line.
    # No receipt + env-only IDADIR is unknown, and must not be adopted by port/name.
    $idaToken = '(?i)(^|[\s"''=])' + [regex]::Escape($IdaDirPath.TrimEnd('\','/')) + '(?=[\\/\s"'']|$)'
    return $cmd -match $idaToken
}

function Get-IdaMcpSupervisorCandidateIds {
    param([int]$Port)
    $ids = New-Object System.Collections.Generic.List[int]
    foreach ($proc in @(Get-CimInstance Win32_Process -OperationTimeoutSec 2 -ErrorAction Stop)) {
        if (-not $proc.ProcessId) { continue }
        $candidateId = [int]$proc.ProcessId
        # Include unknown candidates, even before they listen: Stop must refuse
        # them and block replacement rather than silently overlooking them.
        if (Test-IdaMcpSupervisorCandidate $proc $Port) {
            [void]$ids.Add($candidateId)
        }
    }
    return @($ids | Select-Object -Unique)
}

function Stop-IdaMcpManagedProcess {
    param(
        [int]$ProcessId,
        [string]$IdaDirPath,
        [int]$Port,
        $ExpectedIdentity
    )
    if ($ProcessId -le 0) { return $false }
    $process = $null
    try {
        $proc = Get-IdaMcpProcessInfo -ProcessId $ProcessId
        if ($null -eq $proc) { return $true }
        $identity = Get-IdaMcpIdentity $proc
        if (-not (Test-IdaMcpIdentity $identity $identity) -or
            ($null -ne $ExpectedIdentity -and -not (Test-IdaMcpIdentity $ExpectedIdentity $identity)) -or
            -not (Test-ManagedSupervisorProcess -ProcessId $ProcessId -IdaDirPath $IdaDirPath -Port $Port -ProcessInfo $proc)) {
            throw 'Ownership/creation/executable identity unknown or mismatched'
        }
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $null = $process.Handle
        $current = Get-IdaMcpProcessInfo -ProcessId $ProcessId
        if (-not (Test-IdaMcpIdentity $identity (Get-IdaMcpIdentity $current))) { throw 'Identity changed before stop' }
        # Only this supervisor handle; never terminate GUI children or a PID tree.
        $process.Kill()
        if (-not $process.WaitForExit(1000)) { throw 'Supervisor exit not confirmed' }
        if ($null -ne (Get-IdaMcpProcessInfo -ProcessId $ProcessId)) { throw 'PID still present or reused after stop' }
        return $true
    } catch {
        # Keep the success stream boolean-only: warning strings must not become true.
        Write-Warning "cleanup_blocked: PID=$ProcessId; $($_.Exception.Message)"
        return $false
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

function Get-PortableIdaCandidates {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $userProfile = $env:USERPROFILE
    return @(
        (Join-Path $desktop 'IDA Pro 9.4\App\IDA Pro'),
        (Join-Path $desktop 'IDA Pro\App\IDA Pro'),
        (Join-Path $userProfile 'Desktop\IDA Pro 9.4\App\IDA Pro'),
        (Join-Path $userProfile 'Tools\IDA Pro 9.4\App\IDA Pro'),
        (Join-Path $userProfile 'Tools\IDA Pro\App\IDA Pro'),
        (Join-Path $userProfile 'Tools\IDA'),
        'C:\Program Files\IDA Professional 9.4',
        'C:\Program Files\IDA Pro 9.4',
        'C:\Program Files\IDA Pro',
        'C:\Program Files\IDA',
        'C:\IDA Pro',
        'C:\IDA',
        'D:\IDA',
        'D:\Tools\IDA Pro 9.4\App\IDA Pro',
        'E:\Program Files\IDA'
    )
}

function Test-IdaInstallDir {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $idaExe = Join-Path $Path 'ida.exe'
    $idaDll = Join-Path $Path 'ida.dll'
    return (Test-Path -LiteralPath $idaExe) -or (Test-Path -LiteralPath $idaDll)
}

function Get-InstalledIdaDir {
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $fromRegistry = $registryPaths |
        ForEach-Object {
            Get-ItemProperty $_ -ErrorAction SilentlyContinue
        } |
        Where-Object {
            ($_.DisplayName -match 'IDA|Hex-Rays') -and
            -not [string]::IsNullOrWhiteSpace($_.InstallLocation) -and
            (Test-IdaInstallDir -Path $_.InstallLocation)
        } |
        Select-Object -ExpandProperty InstallLocation -First 1

    if ($fromRegistry) {
        return $fromRegistry
    }

    return Get-PortableIdaCandidates | Where-Object { Test-IdaInstallDir -Path $_ } | Select-Object -First 1
}

function Resolve-IdaDir {
    param([string]$Preferred)

    if (-not [string]::IsNullOrWhiteSpace($Preferred) -and (Test-IdaInstallDir -Path $Preferred)) {
        return [System.IO.Path]::GetFullPath($Preferred)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:IDADIR) -and (Test-IdaInstallDir -Path $env:IDADIR)) {
        return [System.IO.Path]::GetFullPath($env:IDADIR)
    }

    foreach ($scope in @('User', 'Machine')) {
        $persisted = [Environment]::GetEnvironmentVariable('IDADIR', $scope)
        if (-not [string]::IsNullOrWhiteSpace($persisted) -and (Test-IdaInstallDir -Path $persisted)) {
            return [System.IO.Path]::GetFullPath($persisted)
        }
    }

    $found = Get-InstalledIdaDir
    if ($found) {
        return [System.IO.Path]::GetFullPath($found)
    }

    return $null
}

function Test-PythonHasIdaProMcp {
    param([string]$PythonExe)
    if ([string]::IsNullOrWhiteSpace($PythonExe) -or -not (Test-Path -LiteralPath $PythonExe)) {
        return $false
    }
    # pythonw.exe has no console — probe with sibling python.exe when possible
    $probeExe = $PythonExe
    if ($PythonExe -match '(?i)pythonw\.exe$') {
        $sibling = Join-Path (Split-Path $PythonExe -Parent) 'python.exe'
        if (Test-Path -LiteralPath $sibling) { $probeExe = $sibling }
    }
    try {
        $check = & $probeExe -c "import ida_pro_mcp; print('ok')" 2>$null
        return ($LASTEXITCODE -eq 0) -or ($check -match 'ok')
    } catch {
        return $false
    }
}

function Get-WindowlessPythonPath {
    param([string]$PythonExe)
    if ([string]::IsNullOrWhiteSpace($PythonExe)) { return $PythonExe }
    if ($PythonExe -match '(?i)pythonw\.exe$') { return $PythonExe }
    if ($PythonExe -match '(?i)python\.exe$') {
        $pythonw = Join-Path (Split-Path $PythonExe -Parent) 'pythonw.exe'
        if (Test-Path -LiteralPath $pythonw) { return $pythonw }
    }
    return $PythonExe
}

function Find-IdalibServer {
    param(
        [string]$IdaDirPath,
        [string]$PreferredServerPath
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredServerPath) -and (Test-Path -LiteralPath $PreferredServerPath)) {
        return @{ Mode = 'exe'; Path = $PreferredServerPath }
    }

    # Prefer direct `pythonw -m ida_pro_mcp.idalib_supervisor` (no console window; more stable than .cmd)
    $pythonCandidates = @(
        (Join-Path $IdaDirPath 'Python314\pythonw.exe'),
        (Join-Path $IdaDirPath 'Python314\python.exe'),
        (Join-Path $IdaDirPath 'python\pythonw.exe'),
        (Join-Path $IdaDirPath 'python\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\pythonw.exe'),
        (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\pythonw.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\pythonw.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Get-Command pythonw -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
        (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($py in $pythonCandidates) {
        # `py` launcher is not a real interpreter for -m in Start-Process; skip bare py.exe
        if ($py -match '\\py\.exe$') { continue }
        if (Test-PythonHasIdaProMcp -PythonExe $py) {
            $launch = Get-WindowlessPythonPath -PythonExe $py
            return @{ Mode = 'module'; Path = $launch; Module = 'ida_pro_mcp.idalib_supervisor' }
        }
    }

    # Prefer native .exe entrypoints over .cmd wrappers
    $scriptCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\Scripts\idalib-mcp.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\Scripts\idalib-mcp.exe'),
        (Join-Path $IdaDirPath 'Python314\Scripts\idalib-mcp.exe'),
        (Join-Path $IdaDirPath 'Python314\Scripts\ida-pro-mcp.exe')
    )
    foreach ($candidate in $scriptCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            return @{ Mode = 'exe'; Path = $candidate }
        }
    }

    foreach ($name in @('idalib-mcp', 'ida-pro-mcp')) {
        $resolved = Get-Command $name -ErrorAction SilentlyContinue
        if ($resolved) {
            return @{ Mode = 'exe'; Path = $resolved.Source }
        }
    }

    foreach ($candidate in @(
        (Join-Path $env:USERPROFILE 'Tools\bin\idalib-mcp.cmd'),
        (Join-Path $env:USERPROFILE 'Tools\bin\ida-pro-mcp.cmd')
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return @{ Mode = 'exe'; Path = $candidate }
        }
    }

    $roamingPython = Join-Path $env:APPDATA 'Python'
    if (Test-Path -LiteralPath $roamingPython) {
        $candidate = Get-ChildItem -LiteralPath $roamingPython -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $scripts = Join-Path $_.FullName 'Scripts'
                @('idalib-mcp.exe', 'ida-pro-mcp.exe') | ForEach-Object { Join-Path $scripts $_ }
            } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
        if ($candidate) {
            return @{ Mode = 'exe'; Path = $candidate }
        }
    }

    return $null
}

$script:IdaMcpLease = $null
$probe = Probe-IdaMcp -Port $Port
$guiOwners = @($probe.GuiOwners)

if ($guiOwners.Count -gt 0) {
    Write-Output ("WARN:gui_busy:port={0} pid={1}" -f $Port, ($guiOwners -join ','))
    Write-Output 'HINT: IDA GUI owns 13337; not killing ida.exe. Wait for analysis or close IDA.'
    exit 0
}

if (-not $Force) {
    if ($probe.Status -eq 'healthy') {
        Write-IdaMcpLastHealthy -Port $Port
        Write-Output "OK:$($probe.Count)`:reuse"
        exit 0
    }
    if ($probe.Status -eq 'busy') {
        $deadlock = Test-IdaMcpKeepaliveDeadlockFromFacts `
            -GuiOwnsPort $false `
            -OpeningInFlight (Test-IdaMcpOpeningInFlight -Port $Port) `
            -LastHealthy (Read-IdaMcpLastHealthy -Port $Port) `
            -Now (Get-Date)
        if (-not $deadlock) {
            Write-Output ("WARN:busy:port={0} pid={1}" -f $Port, ($probe.Owners -join ','))
            Write-Output 'HINT: 13337 is listening but tools/list timed out (likely idb_open). Not killing supervisor.'
            exit 0
        }
        Write-Output ("INFO:deadlock:port={0} pid={1} (tools/list unhealthy >180s, replacing)" -f $Port, ($probe.Owners -join ','))
    }
}

$resolvedIdaDir = Resolve-IdaDir -Preferred $IdaDir
if (-not $resolvedIdaDir) {
    Write-Output "ERR:IDADIR not set and IDA Pro not found. Set IDADIR to your IDA install dir (folder containing ida.exe)."
    exit 1
}

$IdaDir = $resolvedIdaDir
$env:IDADIR = $IdaDir

# Ensure IDA bins + bundled Python are visible to the child process
$idaPythonDir = Join-Path $IdaDir 'Python314'
if (-not (Test-Path -LiteralPath $idaPythonDir)) {
    $idaPythonDir = Join-Path $IdaDir 'python'
}
$env:PATH = "$IdaDir;$idaPythonDir;$(Join-Path $idaPythonDir 'Scripts');$env:PATH"

$server = Find-IdalibServer -IdaDirPath $IdaDir -PreferredServerPath $ServerPath

# Auto-bootstrap only if still missing
if (-not $server) {
    $bootstrapScript = Join-Path $PSScriptRoot '..\..\scripts\bootstrap-reverse.ps1'
    if (Test-Path -LiteralPath $bootstrapScript) {
        Write-Output "INFO: ida-pro-mcp not found, attempting auto-bootstrap (installing mrexodia/ida-pro-mcp)..."
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrapScript -Capability @('idalib-mcp') -SkipRefresh
        $server = Find-IdalibServer -IdaDirPath $IdaDir -PreferredServerPath $ServerPath
    }
}

if (-not $server) {
    Write-Output 'ERR:Missing idalib-mcp — install into IDA Python: <IDADIR>\Python314\python.exe -m pip install git+https://github.com/mrexodia/ida-pro-mcp.git'
    exit 1
}

# Replace only proven supervisors. Any refusal/failure blocks this launch.
$logDir = Get-IdaMcpLogDir
$supervisorLeasePath = Join-Path $logDir "supervisor-$Port.lease.json"
if (Test-Path -LiteralPath $supervisorLeasePath) {
    try {
        $script:IdaMcpLease = Get-Content -LiteralPath $supervisorLeasePath -Raw | ConvertFrom-Json
        if ($null -ne $script:IdaMcpLease.PSObject.Properties['startup_blocked'] -and $script:IdaMcpLease.startup_blocked) {
            throw 'Previous startup identity is unresolved'
        }
    }
    catch {
        Write-Output "ERR:cleanup_blocked:unresolved_or_invalid_supervisor_lease:$supervisorLeasePath"
        exit 1
    }
}
$stopIds = @(@(Get-IdaMcpPortOwners -Port $Port) + @(Get-IdaMcpSupervisorCandidateIds -Port $Port) | Select-Object -Unique)
if ($stopIds.Count -gt 256) {
    Write-Output 'ERR:cleanup_blocked:supervisor_count_limit'
    exit 1
}
foreach ($managedPid in $stopIds) {
    if (-not (Stop-IdaMcpManagedProcess -ProcessId $managedPid -IdaDirPath $IdaDir -Port $Port)) {
        Write-Output "ERR:cleanup_blocked:pid=$managedPid"
        exit 1
    }
}
if (@(Get-IdaMcpPortOwners -Port $Port).Count -gt 0 -or
    @(Get-IdaMcpSupervisorCandidateIds -Port $Port).Count -gt 0) {
    Write-Output 'ERR:cleanup_blocked:supervisor_or_listener_remains'
    exit 1
}

$wrapper = Join-Path $PSScriptRoot 'run-supervisor.py'
# --unsafe exposes py_eval / py_exec_file. dbg_* stay hidden (need ?ext=dbg; do not add).
$argList = @('--host', '127.0.0.1', '--port', "$Port", '--unsafe')
if (Test-Path -LiteralPath $wrapper) {
    $filePath = $server.Path
    if ($filePath -match '(?i)python\.exe$') {
        $pythonw = Join-Path (Split-Path $filePath -Parent) 'pythonw.exe'
        if (Test-Path -LiteralPath $pythonw) { $filePath = $pythonw }
    }
    if ($filePath -notmatch '(?i)pythonw?\.exe$') {
        $filePath = $server.Path
        if ($server.Mode -eq 'module') {
            $argList = @('-u', '-m', $server.Module) + $argList
        }
    } else {
        $argList = @('-u', $wrapper) + $argList
    }
} elseif ($server.Mode -eq 'module') {
    $filePath = $server.Path
    $argList = @('-u', '-m', $server.Module) + $argList
} else {
    $filePath = $server.Path
}

$logDir = Get-IdaMcpLogDir
$logFile = Join-Path $logDir 'supervisor.log'
Rotate-IdaMcpLog -Path $logFile

Write-Output "INFO:IDADIR=$IdaDir"
Write-Output "INFO:server=$filePath $($argList -join ' ')"
Write-Output "INFO:log=$logFile"
Write-Output 'INFO:window=hidden (pythonw / no console)'

# Detached + hidden start:
# pythonw + run-supervisor.py keeps logs without a cmd.exe window.
# This persistent supervisor is not a Job Object with descendant cleanup guarantees.
# Win32_Process.Create so the server survives agent/terminal Job Objects.
$quotedArgs = foreach ($a in $argList) {
    if ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' } else { $a }
}
$useCmd = $filePath -match '(?i)\.cmd$'
if ($useCmd) {
    $commandLine = 'cmd.exe /d /c "' + $filePath + '" ' + ($quotedArgs -join ' ')
} else {
    $commandLine = '"' + $filePath + '" ' + ($quotedArgs -join ' ')
}
$procId = 0
$startedProcess = $null
$launchNotBefore = [datetime]::UtcNow.AddMilliseconds(-1).ToFileTimeUtc()
$expectedExecutable = if ($useCmd) { (Get-Command cmd.exe -CommandType Application -ErrorAction Stop).Source } else {
    (Get-Command $filePath -CommandType Application -ErrorAction Stop).Source
}

try {
    $create = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine      = $commandLine
        CurrentDirectory = $IdaDir
    }
    if ($create -and $create.ReturnValue -eq 0 -and $create.ProcessId) {
        $procId = [int]$create.ProcessId
    } elseif ($null -eq $create -or $create.ReturnValue -eq 0) {
        throw 'Process creation result is unknown'
    }
} catch {
    # A failed CIM call may have created a process before losing its reply.
    # Only an explicit failure result permits the alternate start path.
    Write-Output "ERR:startup_blocked:creation_result_unknown; $($_.Exception.Message)"
    exit 1
}

if ($procId -le 0) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        if ($useCmd) {
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = '/d /c "' + $filePath + '" ' + ($quotedArgs -join ' ')
        } else {
            $psi.FileName = $filePath
            $psi.Arguments = ($quotedArgs -join ' ')
        }
        $psi.WorkingDirectory = $IdaDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $p = [System.Diagnostics.Process]::Start($psi)
        if ($p) {
            $procId = $p.Id
            $startedProcess = $p
            $commandLine = '"' + $psi.FileName.Trim('"') + '" ' + $psi.Arguments
        }
    } catch {}
}

if ($procId -le 0) {
    Write-Output 'ERR:failed_to_start_process'
    exit 1
}
Write-Output "INFO:pid=$procId"

$launchedIdentity = $null
$launchProcess = $startedProcess
try {
    # Preserve an unresolved startup across invocations instead of losing its PID.
    $script:IdaMcpLease = [pscustomobject]@{ ida_dir = $IdaDir; port = $Port; pid = $procId; identity = $null; startup_blocked = $true }
    $script:IdaMcpLease | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $supervisorLeasePath -Encoding UTF8
    if ($null -eq $launchProcess) { $launchProcess = Get-Process -Id $procId -ErrorAction Stop }
    $null = $launchProcess.Handle
    $launchedIdentity = Get-IdaMcpIdentity (Get-IdaMcpProcessInfo -ProcessId $procId)
    if ($launchProcess.HasExited -or -not (Test-IdaMcpIdentity $launchedIdentity $launchedIdentity) -or
        $launchedIdentity.creation_filetime_utc -lt $launchNotBefore -or
        -not [string]::Equals($launchedIdentity.executable, $expectedExecutable, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals($launchedIdentity.command_line, $commandLine, [System.StringComparison]::Ordinal)) {
        throw 'Launched process identity could not be established'
    }
    $script:IdaMcpLease.identity = $launchedIdentity
    $script:IdaMcpLease.startup_blocked = $false
    $script:IdaMcpLease | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $supervisorLeasePath -Encoding UTF8
} catch {
    Write-Output "ERR:startup_identity_blocked:pid=$procId; $($_.Exception.Message)"
    # Unknown identity must not trigger a bare-PID kill or another launch.
    exit 1
} finally {
    if ($null -ne $launchProcess) { $launchProcess.Dispose() }
}

# Wait for readiness via MCP tools/list, with a wall-clock deadline.
$ready = $false
$toolCount = 0
$readyDeadline = [datetime]::UtcNow.AddSeconds([math]::Max(0, $WaitSeconds))
try {
    while ([datetime]::UtcNow -lt $readyDeadline) {
        Start-Sleep -Seconds 1
        $health = Probe-IdaMcp -Port $Port
        if ($health.Status -eq 'healthy') {
            $current = Get-IdaMcpIdentity (Get-IdaMcpProcessInfo -ProcessId $procId)
            if (-not (Test-IdaMcpIdentity $launchedIdentity $current) -or
                $health.Owners.Count -ne 1 -or $health.Owners[0] -ne $procId) {
                throw 'Healthy listener does not match the launched supervisor'
            }
            $toolCount = $health.Count
            Write-IdaMcpLastHealthy -Port $Port
            Write-Output "OK:$toolCount"
            $ready = $true
            break
        }
    }
} catch {
    Write-Warning "startup_wait_failed: $($_.Exception.Message)"
}

if (-not $ready) {
    $stopped = Stop-IdaMcpManagedProcess -ProcessId $procId -IdaDirPath $IdaDir -Port $Port -ExpectedIdentity $launchedIdentity
    Write-Output "ERR:timeout"
    if ($stopped) {
        Write-Output 'INFO:launched_supervisor_exit_verified; descendant_cleanup_unverified'
    } else {
        Write-Output "ERR:cleanup_blocked:pid=$procId"
    }
    Write-Output "HINT:check $logFile"
    exit 1
}
