#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $CaseRoot,
    [Parameter(Mandatory = $true)][string] $EvidenceIds,
    [Parameter(Mandatory = $true)][string] $FindingId,
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Description,
    [string] $Severity = 'medium',
    [string] $Status = 'validated',
    [string] $Confidence = 'medium',
    [string] $Location = 'see evidence_ids'
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
    throw "Timed out waiting for report lock: $Path"
}

function Test-StructuralDescription([string] $Text) {
    return $Text -match '(?m)^\s*(?:#{1,6}[ \t]+|-[ \t]+[A-Za-z0-9_]+:)'
}

if (-not (Test-Path -LiteralPath $CaseRoot -PathType Container)) { throw "CaseRoot not found: $CaseRoot" }

$caseRootFull = (Resolve-Path -LiteralPath $CaseRoot).Path
$evidenceDir = Join-Path $caseRootFull "evidence"
$reportDir = Join-Path $caseRootFull "report"
$evidenceItem = Get-Item -LiteralPath $evidenceDir -Force -ErrorAction SilentlyContinue
if ($null -eq $evidenceItem -or -not $evidenceItem.PSIsContainer -or (($evidenceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "Case evidence directory is missing or a symlink: $evidenceDir"
}
$reportItem = Get-Item -LiteralPath $reportDir -Force -ErrorAction SilentlyContinue
if ($null -ne $reportItem -and (($reportItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "Case report directory is a symlink: $reportDir"
}
if ($null -eq $reportItem) { New-Item -ItemType Directory -Path $reportDir -ErrorAction Stop | Out-Null }

$idList = @($EvidenceIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($idList.Count -eq 0) { throw "No Evidence IDs provided." }
if (($idList | Select-Object -Unique).Count -ne $idList.Count -or ($idList | Where-Object { $_ -notmatch '^E-[A-Za-z0-9][A-Za-z0-9_-]*$' })) {
    throw "Evidence IDs must be unique and match E-<alphanumeric-or-_>-..."
}
if ($FindingId -notmatch '^F-[A-Za-z0-9][A-Za-z0-9_-]*$') {
    throw "Finding ID must match F-<alphanumeric-or-_>-..."
}
$severityValue = ($Severity -replace '\s+', ' ').Trim().ToLowerInvariant()
$statusValue = ($Status -replace '\s+', ' ').Trim().ToLowerInvariant()
$confidenceValue = ($Confidence -replace '\s+', ' ').Trim().ToLowerInvariant()
if (@('critical','high','medium','low','info','n/a','n/a_re') -notcontains $severityValue) { throw "Invalid Severity: $Severity" }
if (@('candidate','validated','false_positive','accepted_risk','superseded') -notcontains $statusValue) { throw "Invalid Status: $Status" }
if (@('high','medium','low') -notcontains $confidenceValue) { throw "Invalid Confidence: $Confidence" }
if ($statusValue -eq 'validated' -and $confidenceValue -eq 'low') { throw 'A validated Finding cannot have low confidence.' }
$titleValue = ($Title -replace '[\x00-\x1F]', ' ' -replace '\s+', ' ').Trim()
$locationValue = ($Location -replace '[\x00-\x1F]', ' ' -replace '\s+', ' ').Trim()
$descriptionValue = $Description -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
if (Test-StructuralDescription $descriptionValue) { throw 'Description must not contain Markdown headings or field lines.' }
if ([string]::IsNullOrWhiteSpace($titleValue) -or [string]::IsNullOrWhiteSpace($locationValue)) { throw 'Title and Location must be non-empty single-line values.' }

foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    $item = Get-Item -LiteralPath $evidenceFile -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { throw "Evidence file missing: $evidenceFile" }
    if ($item.PSIsContainer) { throw "Evidence path is a directory: $evidenceFile" }
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Evidence file is a symlink or reparse point: $evidenceFile"
    }
}

foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    Write-Host "Referenced $id without modifying immutable Evidence"
}

$timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)
$joined = ($idList -join ', ')
$findingBlock = @"
### $FindingId
- title: $titleValue
- severity: $severityValue
- status: $statusValue
- confidence: $confidenceValue
- location: $locationValue
- evidence_ids: $joined
- consolidated_at: $timestamp

$descriptionValue
"@

$reportFile = Join-Path $reportDir "report.md"
$lockStream = Enter-ExclusiveFileLock (Join-Path $reportDir '.report.md.lock')
try {
    $reportItem = Get-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
    if ($null -ne $reportItem -and (($reportItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Report file is a symlink or reparse point: $reportFile"
    }
    if ($null -ne $reportItem -and $reportItem.PSIsContainer) {
        throw "Report path is a directory: $reportFile"
    }
    if ($null -ne $reportItem) {
        $reportContent = Get-Content -LiteralPath $reportFile -Raw -Encoding UTF8
        if ($reportContent -match ("(?m)^###\s+" + [regex]::Escape($FindingId) + "\s*$")) {
            throw "Finding already exists: $FindingId"
        }
        if ($reportContent -notmatch "(?m)^##[ \t]+Findings[ \t]*\r?$") {
            $reportContent = $reportContent.TrimEnd() + "`r`n`r`n## Findings`r`n"
        }
        Set-Content -LiteralPath $reportFile -Value ($reportContent.TrimEnd() + "`r`n`r`n" + $findingBlock + "`r`n") -Encoding UTF8 -NoNewline
    } else {
        $initialReport = @"
# Case Report

## Findings

$findingBlock
"@
        Set-Content -LiteralPath $reportFile -Value $initialReport -Encoding UTF8
    }
} finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}
