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
if (-not ([System.Linq.Enumerable]::SequenceEqual($beforePy, $afterPy))) { throw "py modified immutable Evidence" }

# reset for ps1
Remove-Item (Join-Path $scratch "report") -Recurse -Force
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-001.md") (Join-Path $scratch "evidence\E-001.md") -Force
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-002.md") (Join-Path $scratch "evidence\E-002.md") -Force
$beforePs = [System.IO.File]::ReadAllBytes((Join-Path $scratch "evidence\E-001.md"))
& (Join-Path $root "skills\scripts\consolidate-evidence.ps1") -CaseRoot $scratch -EvidenceIds "E-001,E-002" -FindingId F-CONSOL-2 -Title "triage merge ps1" -Description "merged two triage notes" -Severity info -Status validated -Confidence medium -Location "see E-001 E-002"
$r2 = Get-Content (Join-Path $scratch "report\report.md") -Raw
Assert-FindingFields $r2
$afterPs = [System.IO.File]::ReadAllBytes((Join-Path $scratch "evidence\E-001.md"))
if (-not ([System.Linq.Enumerable]::SequenceEqual($beforePs, $afterPs))) { throw "ps1 modified immutable Evidence" }

# review_case accepts immutable consolidation and keeps hashes
$demo = Join-Path $scratch "ctf"
Copy-Item (Join-Path $root "examples\ctf-demo") $demo -Recurse
python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $demo --evidence-ids "E-001" --finding-id F-001 --title "keep contract" --description "ok" --severity info --status validated --confidence medium --location "E-001" | Out-Null
$review = python (Join-Path $root "skills\case-review\scripts\review_case.py") $demo --verify-hashes --strict 2>&1 | Select-Object -Last 8
if ($LASTEXITCODE -ne 0) { throw "review_case failed immutable consolidated case:`n$($review -join [Environment]::NewLine)" }
Write-Host "CONSOLIDATE_ALIGN_OK"
Remove-Item $scratch -Recurse -Force
