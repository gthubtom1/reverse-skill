#Requires -Version 5.1
# Append one Evidence item under work/<case>/evidence/ (ops Evidence contract).
#
# Usage (simple):
#   powershell -File skills/scripts/append-evidence.ps1 -CaseRoot work\my-case `
#     -Id E-001 -Title "Open clock API" -ReproCommand 'curl -sI https://example/' `
#     -Severity info -Status observed
#
# Special characters / spaces / quotes in excerpts (recommended for nested -File):
#   Set-Content excerpt.txt -Value '"XML parsing error" / Entities are not allowed'
#   powershell -File skills/scripts/append-evidence.ps1 ... -RawExcerptFile excerpt.txt
#
# NOTE: Nested `powershell -File` splits unquoted multi-word values. Prefer -RawExcerptFile
# or call the script in-process: & .\append-evidence.ps1 -RawExcerpt 'full text here'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [Parameter(Mandatory = $true)]
    [string] $Id,

    [Parameter(Mandatory = $true)]
    [string] $Title,

    [Parameter(Mandatory = $true)]
    [string] $ReproCommand,

    [string] $Severity = 'info',
    [string] $Status = 'observed',
    [string] $SourceType = 'command',
    [string] $RawExcerpt = '',
    [string] $RawExcerptFile = '',
    [string] $Location = '',
    [string] $Notes = '',
    [string] $NotesFile = '',
    [string] $ReproCommandFile = '',
    [string] $ArtifactPath = ''
)
$ErrorActionPreference = 'Stop'

function Enter-ExclusiveFileLock([string] $Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -ne $item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Lock path is a symlink or reparse point: $Path"
    }
    for ($attempt = 0; $attempt -lt 200; $attempt++) {
        try {
            return [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 25
        }
    }
    throw "Timed out waiting for Evidence index lock: $Path"
}

# Advanced functions reject unknown positionals at bind time; keep explicit check for edge hosts.
if ($args -and $args.Count -gt 0) {
    $extra = ($args | ForEach-Object { [string]$_ }) -join ' | '
    throw ("Unexpected arguments (likely -RawExcerpt/-Title quoting broke multi-word value): {0}. Use -RawExcerptFile for special characters, or pass a single quoted string." -f $extra)
}

$allowedSeverity = @('critical', 'high', 'medium', 'low', 'info', 'n/a', 'n/a_re')
$allowedStatus = @('observed', 'candidate', 'validated', 'false_positive', 'accepted_risk')

function ConvertTo-YamlBlock([string] $text) {
    if ([string]::IsNullOrEmpty($text)) { return '    n/a' }
    $clean = ($text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    $lines = $clean -split "`r?`n", -1
    if ($lines.Count -eq 0) { return '    n/a' }
    return (($lines | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine)
}

function ConvertTo-SingleLine([string] $text) {
    if ([string]::IsNullOrEmpty($text)) { return 'n/a' }
    $t = ($text -replace '[\x00-\x1F]', ' ')
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Read-OptionalFile([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "File not found: $path"
    }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $path), [System.Text.Encoding]::UTF8)
}

$CaseRoot = (Resolve-Path -LiteralPath $CaseRoot).Path
$evPath = Join-Path $CaseRoot 'evidence'
$evItem = Get-Item -LiteralPath $evPath -Force -ErrorAction SilentlyContinue
if ($null -eq $evItem) {
    [System.IO.Directory]::CreateDirectory($evPath) | Out-Null
    $evItem = Get-Item -LiteralPath $evPath -Force
}
if (-not $evItem.PSIsContainer -or (($evItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "Case evidence directory is missing or a symlink: $CaseRoot/evidence"
}

# File overrides beat inline strings (safe path for special characters under powershell -File)
$fromReproFile = Read-OptionalFile $ReproCommandFile
if ($null -ne $fromReproFile) { $ReproCommand = $fromReproFile }

$fromExcerptFile = Read-OptionalFile $RawExcerptFile
if ($null -ne $fromExcerptFile) { $RawExcerpt = $fromExcerptFile }

$fromNotesFile = Read-OptionalFile $NotesFile
if ($null -ne $fromNotesFile) { $Notes = $fromNotesFile }

$contentHash = 'n/a'
$artifactRef = 'n/a'
if (-not [string]::IsNullOrWhiteSpace($ArtifactPath)) {
    if ($ArtifactPath -match '[\x00-\x1F]') { throw 'ArtifactPath must be a single-line path without control characters.' }
    $artifactCandidate = $ArtifactPath
    if (-not [System.IO.Path]::IsPathRooted($artifactCandidate)) {
        $caseArtifact = Join-Path $CaseRoot $artifactCandidate
        if (Test-Path -LiteralPath $caseArtifact -PathType Leaf) { $artifactCandidate = $caseArtifact }
    }
    if (-not (Test-Path -LiteralPath $artifactCandidate -PathType Leaf)) {
        throw "ArtifactPath must point to a file inside CaseRoot: $ArtifactPath"
    }
    $caseRootFull = (Resolve-Path -LiteralPath $CaseRoot).Path
    $artifactFull = (Resolve-Path -LiteralPath $artifactCandidate).Path
    $casePrefix = $caseRootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $artifactFull.StartsWith($casePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "ArtifactPath must point inside CaseRoot: $ArtifactPath"
    }
    $artifactCursor = $artifactFull
    while ($artifactCursor) {
        $artifactItem = Get-Item -LiteralPath $artifactCursor -Force
        if (($artifactItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "ArtifactPath contains a symlink or reparse point inside CaseRoot: $ArtifactPath"
        }
        if ($artifactCursor.TrimEnd('\', '/') -eq $caseRootFull.TrimEnd('\', '/')) { break }
        $artifactCursor = Split-Path -Parent $artifactCursor
    }
    $artifactRef = $artifactFull.Substring($casePrefix.Length) -replace '\\', '/'
    $contentHash = (Get-FileHash -LiteralPath $artifactFull -Algorithm SHA256).Hash.ToLowerInvariant()
}

$evDir = Join-Path $CaseRoot 'evidence'

if ($Id -notmatch '^E-[A-Za-z0-9][A-Za-z0-9_-]*$') {
    throw "Invalid -Id '$Id'. Evidence IDs must match E-<alphanumeric-or-_>-..."
}
$fileName = $Id + '.md'
$path = Join-Path $evDir $fileName

$observed = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ", [System.Globalization.CultureInfo]::InvariantCulture)
$titleLine = ConvertTo-SingleLine $Title
$sev = (ConvertTo-SingleLine $Severity).ToLowerInvariant()
if ($allowedSeverity -notcontains $sev) {
    throw ("Invalid -Severity '{0}' (allowed: {1})" -f $Severity, ($allowedSeverity -join ', '))
}
$st = (ConvertTo-SingleLine $Status).ToLowerInvariant()
if ($allowedStatus -notcontains $st) {
    throw ("Invalid -Status '{0}' (allowed: {1})" -f $Status, ($allowedStatus -join ', '))
}
$src = ConvertTo-SingleLine $SourceType
$loc = ConvertTo-SingleLine $(if ($Location) { $Location } else { 'n/a' })
if ([string]::IsNullOrWhiteSpace($ReproCommand)) {
    throw '-ReproCommand (or -ReproCommandFile) is required and must be non-empty'
}
$reproBlock = ConvertTo-YamlBlock $ReproCommand
$excerptBlock = ConvertTo-YamlBlock $(if ($RawExcerpt) { $RawExcerpt } else { 'n/a' })
$notesBlock = ConvertTo-YamlBlock $(if ($Notes) { $Notes } else { 'n/a' })

$body = @"
### $Id
- title: $titleLine
- observed_at: $observed
- source_type: $src
- source_ref: append-evidence.ps1
- content_hash: $contentHash
- artifact_path: $artifactRef
- severity: $sev
- status: $st
- location: $loc
- repro_command: |
$reproBlock
- raw_excerpt: |
$excerptBlock
- linked_workitem: n/a
- supersedes: none
- notes: |
$notesBlock
"@

$utf8 = New-Object System.Text.UTF8Encoding $false
$stream = $null
$writer = $null
try {
    try {
        $stream = [System.IO.File]::Open(
            $path,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
    } catch [System.IO.IOException] {
        if (Test-Path -LiteralPath $path) {
            throw ("Evidence record already exists and is immutable: {0}. Use a new -Id." -f $fileName)
        }
        throw
    }
    $writer = [System.IO.StreamWriter]::new($stream, $utf8)
    $writer.Write($body)
} finally {
    if ($null -ne $writer) {
        $writer.Dispose()
    } elseif ($null -ne $stream) {
        $stream.Dispose()
    }
}

$index = Join-Path $evDir 'INDEX.md'
$line = "- $Id | $sev | $st | $($titleLine -replace '\|', '\\|') | $fileName"
$indexLock = Enter-ExclusiveFileLock (Join-Path $evDir '.INDEX.md.lock')
try {
    $indexItem = Get-Item -LiteralPath $index -Force -ErrorAction SilentlyContinue
    if ($null -ne $indexItem -and (($indexItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Evidence INDEX is a symlink or reparse point: $index"
    }
    if ($null -ne $indexItem -and $indexItem.PSIsContainer) { throw "Evidence INDEX is a directory: $index" }
    if ($null -eq $indexItem) {
        $hdr = @"
# Evidence index

| id | severity | status | title | file |
|----|----------|--------|-------|------|

"@
        [System.IO.File]::WriteAllText($index, $hdr, $utf8)
    } else {
        $indexText = [System.IO.File]::ReadAllText($index, [System.Text.Encoding]::UTF8)
        if ($indexText -match ("(?m)^-\s+" + [regex]::Escape($Id) + "\s+\|")) {
            throw "Evidence INDEX already contains $Id; refusing a duplicate index row."
        }
    }
    $indexStream = $null
    $indexWriter = $null
    try {
        $indexStream = [System.IO.File]::Open($index, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $indexWriter = [System.IO.StreamWriter]::new($indexStream, $utf8)
        $indexWriter.WriteLine($line)
        $indexWriter.Flush()
    } finally {
        if ($null -ne $indexWriter) { $indexWriter.Dispose() }
        elseif ($null -ne $indexStream) { $indexStream.Dispose() }
    }
} finally {
    if ($null -ne $indexLock) { $indexLock.Dispose() }
}

Write-Host ("EVIDENCE -> {0}" -f $path) -ForegroundColor Green
Write-Host ("ID: {0} | {1} | {2}" -f $Id, $sev, $st)
exit 0
