#Requires -Version 5.1
# Lightweight scope gate before ACT. Exit 0 = ok, 2 = not ready, 1 = usage/error.
# Usage:
#   powershell -File skills/scripts/case-guard.ps1 -CaseRoot work\my-case
#   powershell -File skills/scripts/case-guard.ps1 -CaseRoot work\my-case -Force   # compatibility flag; never bypasses scope hard gates
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [switch] $Force,
    [switch] $Quiet
)
$ErrorActionPreference = 'Stop'

function Write-Info([string] $m) {
    if (-not $Quiet) { Write-Host $m }
}

if (-not (Test-Path -LiteralPath $CaseRoot)) {
    Write-Host ("ERROR: CaseRoot missing: {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scopePath = Join-Path $CaseRoot 'scope.md'
if (-not (Test-Path -LiteralPath $scopePath)) {
    Write-Host ("ERROR: scope.md missing under {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8
$issues = New-Object System.Collections.Generic.List[string]

function Get-ScopeSection([string] $Text, [string] $Name) {
    $pattern = '(?ims)^##[ \t]+' + [regex]::Escape($Name) + '[ \t]*\r?$\n(?<body>.*?)(?=^##[ \t]+|\z)'
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}

function Get-SectionFieldValues([string] $Section, [string] $Name) {
    $pattern = '(?im)^-[ \t]+' + [regex]::Escape($Name) + ':[ \t]*(?<value>[^\r\n]*)\r?$'
    return @([regex]::Matches($Section, $pattern) | ForEach-Object { $_.Groups['value'].Value.Trim() })
}

function Get-SectionField([string] $Section, [string] $Name) {
    $values = @(Get-SectionFieldValues -Section $Section -Name $Name)
    if ($values.Count -gt 0) { return $values[0] }
    return ''
}

function Get-SectionFieldNames([string] $Section) {
    return @([regex]::Matches($Section, '(?im)^-[ \t]+(?<name>[A-Za-z0-9_]+):') |
        ForEach-Object { $_.Groups['name'].Value.ToLowerInvariant() })
}

function Test-ReadableRegularFile([string] $Asset, [string] $Root) {
    if ([string]::IsNullOrWhiteSpace($Asset) -or $Asset -match '^[A-Za-z][A-Za-z0-9+.-]*://') { return $false }
    $candidate = if ([System.IO.Path]::IsPathRooted($Asset)) { $Asset } else { Join-Path $Root $Asset }
    $item = Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer -or (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) { return $false }
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($item.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        return $true
    } catch { return $false }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
}

$requiredSections = @('auth', 'in_scope', 'network_profile', 'signoff')
foreach ($sectionName in $requiredSections) {
    $sectionCount = [regex]::Matches($scope, '(?im)^##[ \t]+' + [regex]::Escape($sectionName) + '[ \t]*\r?$').Count
    if ($sectionCount -ne 1) { [void]$issues.Add("scope section '$sectionName' must appear exactly once (found $sectionCount)") }
}

$authSection = Get-ScopeSection -Text $scope -Name 'auth'
$networkSection = Get-ScopeSection -Text $scope -Name 'network_profile'
$signoffSection = Get-ScopeSection -Text $scope -Name 'signoff'
$inScopeSection = Get-ScopeSection -Text $scope -Name 'in_scope'
foreach ($pair in @(
    @($authSection, 'auth'),
    @($inScopeSection, 'in_scope'),
    @($networkSection, 'network_profile'),
    @($signoffSection, 'signoff')
)) {
    $seen = @{}
    foreach ($fieldName in @(Get-SectionFieldNames $pair[0])) {
        if ($seen.ContainsKey($fieldName)) {
            [void]$issues.Add("scope field '$fieldName' is duplicated in $($pair[1])")
        } else { $seen[$fieldName] = $true }
    }
}
foreach ($pair in @(
    @($authSection, 'status'),
    @($networkSection, 'mode'),
    @($signoffSection, 'ready_for_act')
)) {
    $values = @(Get-SectionFieldValues -Section $pair[0] -Name $pair[1])
    if ($values.Count -ne 1) { [void]$issues.Add("scope field '$($pair[1])' must appear exactly once (found $($values.Count))") }
}

# auth.status
$authGranted = (Get-SectionField -Section $authSection -Name 'status').ToLowerInvariant() -eq 'granted'
if (-not $authGranted) { [void]$issues.Add('auth.status is not granted') }

# network_profile.mode: the complete value is authoritative; trailing tokens are invalid.
$netMode = (Get-SectionField -Section $networkSection -Name 'mode').ToLowerInvariant()
$allowedNetworkModes = @('offline', 'lab_only', 'authorized_target_only', 'unrestricted_lab')
if ([string]::IsNullOrWhiteSpace($netMode)) {
    [void]$issues.Add('network_profile.mode missing')
} elseif ($netMode -notin $allowedNetworkModes) {
    [void]$issues.Add("network_profile.mode is unsupported: $netMode")
}

function Get-InScopeAssets([string] $Section) {
    $values = New-Object System.Collections.Generic.List[string]
    $inAssets = $false
    foreach ($line in ($Section -split '\r?\n')) {
        if ($line -match '^-[ \t]*assets:[ \t]*$') {
            $inAssets = $true
            continue
        }
        if ($inAssets -and $line -match '^-[ \t]+[A-Za-z0-9_]+:') {
            break
        }
        if ($inAssets -and $line -match '^[ \t]+-[ \t]+(?<value>\S.*)$') {
            $value = $Matches['value'].Trim()
            if ($value -notmatch '^\[[ \t]*\]$') { [void]$values.Add($value) }
        }
    }
    return @($values)
}

# in_scope assets: parse only list entries under the authoritative field.
$inScopeAssets = @(Get-InScopeAssets $inScopeSection)
$hasAsset = $inScopeAssets.Count -gt 0
if (-not $hasAsset) { [void]$issues.Add('in_scope.assets appears empty') }
if ($netMode -eq 'offline') {
    $caseRootFull = (Resolve-Path -LiteralPath $CaseRoot).Path
    $readableAsset = @($inScopeAssets | Where-Object { Test-ReadableRegularFile -Asset $_ -Root $caseRootFull })
    if ($readableAsset.Count -eq 0) {
        [void]$issues.Add('offline scope has no local in_scope asset that is a readable regular file (unable to determine a local sample)')
    }
}

# ready_for_act
$ready = (Get-SectionField -Section $signoffSection -Name 'ready_for_act').ToLowerInvariant() -eq 'true'
if (-not $ready) { [void]$issues.Add('ready_for_act is not true') }

if ($issues.Count -eq 0) {
    Write-Info ("CASE-GUARD OK: {0}" -f $CaseRoot)
    exit 0
}

Write-Host ("CASE-GUARD NOT READY: {0}" -f $CaseRoot) -ForegroundColor Yellow
foreach ($i in $issues) { Write-Host (" - {0}" -f $i) -ForegroundColor Yellow }

if ($Force) {
    Write-Host 'CASE-GUARD: -Force does not bypass scope hard gates.' -ForegroundColor Yellow
}

Write-Host 'Edit the existing scope.md and continue this case; use a new CaseName only when initializing a new case.' -ForegroundColor Yellow
exit 2
