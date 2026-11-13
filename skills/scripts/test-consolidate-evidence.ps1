#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here "..\..")).Path
$scratch = Join-Path $env:TEMP ("rs-consol-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path (Join-Path $scratch "evidence") | Out-Null
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-001.md") (Join-Path $scratch "evidence\E-001.md")
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-002.md") (Join-Path $scratch "evidence\E-002.md")

function Assert-FindingFields([string]$report) {
    foreach ($f in @("confidence:","location:","evidence_ids:","status:")) {
        if ($report -notmatch [regex]::Escape($f)) { throw "missing field $f" }
    }
    if ($report -match "evidence_refs:") { throw "legacy evidence_refs leaked" }
}

# Python path
$beforePy = [System.IO.File]::ReadAllBytes((Join-Path $scratch "evidence\E-001.md"))
python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $scratch --evidence-ids "E-001,E-002" --finding-id F-CONSOL-1 --title "triage merge" --description "merged two triage notes" --severity info --status validated --confidence medium --location "see E-001 E-002" | Out-Null
$r1 = Get-Content (Join-Path $scratch "report\report.md") -Raw
Assert-FindingFields $r1
$afterPy = [System.IO.File]::ReadAllBytes((Join-Path $scratch "evidence\E-001.md"))
if ([Convert]::ToBase64String($beforePy) -cne [Convert]::ToBase64String($afterPy)) { throw "py modified immutable Evidence" }
$savedErrorActionPreference = $ErrorActionPreference
try {
    # Windows PowerShell wraps native stderr in NativeCommandError; expected
    # negative CLI results must be judged by their actual exit code.
    $ErrorActionPreference = 'Continue'
    $duplicatePy = python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $scratch --evidence-ids "E-001" --finding-id F-CONSOL-1 --title "duplicate" --description "duplicate" --severity info --status validated --confidence medium --location "E-001" 2>&1
    if ($LASTEXITCODE -eq 0) { throw "py accepted duplicate Finding" }
    $injectedPy = python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $scratch --evidence-ids "E-001" --finding-id F-CONSOL-INJECT --title "inject" --description "ok`n- status: accepted_risk" --severity info --status validated --confidence medium --location "E-001" 2>&1
    if ($LASTEXITCODE -eq 0) { throw "py accepted structural description injection" }
} finally { $ErrorActionPreference = $savedErrorActionPreference }

# reset for ps1
Remove-Item (Join-Path $scratch "report") -Recurse -Force
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-001.md") (Join-Path $scratch "evidence\E-001.md") -Force
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-002.md") (Join-Path $scratch "evidence\E-002.md") -Force
$beforePs = [System.IO.File]::ReadAllBytes((Join-Path $scratch "evidence\E-001.md"))
& (Join-Path $root "skills\scripts\consolidate-evidence.ps1") -CaseRoot $scratch -EvidenceIds "E-001,E-002" -FindingId F-CONSOL-2 -Title "triage merge ps1" -Description "merged two triage notes" -Severity info -Status validated -Confidence medium -Location "see E-001 E-002"
$r2 = Get-Content (Join-Path $scratch "report\report.md") -Raw
Assert-FindingFields $r2
$afterPs = [System.IO.File]::ReadAllBytes((Join-Path $scratch "evidence\E-001.md"))
if ([Convert]::ToBase64String($beforePs) -cne [Convert]::ToBase64String($afterPs)) { throw "ps1 modified immutable Evidence" }
try {
    & (Join-Path $root "skills\scripts\consolidate-evidence.ps1") -CaseRoot $scratch -EvidenceIds "E-001" -FindingId F-CONSOL-2 -Title "duplicate" -Description "duplicate" -Severity info -Status validated -Confidence medium -Location "E-001" | Out-Null
    throw "ps1 accepted duplicate Finding"
} catch {
    if ($_.Exception.Message -notmatch 'Finding already exists') { throw }
}
try {
    & (Join-Path $root "skills\scripts\consolidate-evidence.ps1") -CaseRoot $scratch -EvidenceIds "E-001" -FindingId F-CONSOL-INJECT -Title "inject" -Description "ok`n- status: accepted_risk" -Severity info -Status validated -Confidence medium -Location "E-001" | Out-Null
    throw "ps1 accepted structural description injection"
} catch {
    if ($_.Exception.Message -notmatch 'Description must not contain') { throw }
}

# review_case accepts immutable consolidation and keeps hashes
$demo = Join-Path $scratch "ctf"
Copy-Item (Join-Path $root "examples\ctf-demo") $demo -Recurse
python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $demo --evidence-ids "E-001" --finding-id F-CONSOL-3 --title "keep contract" --description "ok" --severity info --status validated --confidence medium --location "E-001" | Out-Null
$review = python (Join-Path $root "skills\case-review\scripts\review_case.py") $demo --verify-hashes --strict 2>&1 | Select-Object -Last 8
if ($LASTEXITCODE -ne 0) { throw "review_case failed immutable consolidated case:`n$($review -join [Environment]::NewLine)" }
$demoReport = Get-Content (Join-Path $demo "report\report.md") -Raw
if ($demoReport -notmatch '(?m)^### F-CONSOL-3\s*$') { throw "consolidated finding was not written or parsed" }
Write-Host "CONSOLIDATE_ALIGN_OK"
Remove-Item $scratch -Recurse -Force
