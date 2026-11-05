#!/usr/bin/env python3
"""Validate the provider-neutral hard-target evaluation contract."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS = ROOT / "evals/hard-target-evals.json"
REQUIRED = {"id", "domain", "phenomenon", "hypothesis", "required_evidence", "next_probe", "failure_transition", "cannot_claim", "method_review", "local_validation"}
DOMAINS = {"pe", "android", "js", "protocol", "provider-neutral"}
ALLOWED_REVIEW = {"source_supported", "cross_checked", "process-contract"}
ALLOWED_LOCAL = {"not_reproduced", "installer-dependent", "local_reproduced", "target_validated"}


def main():
    data = json.loads(EVALS.read_text(encoding="utf-8"))
    cases = data.get("cases")
    assert data.get("schema_version") == 1
    assert isinstance(cases, list) and len(cases) >= 15
    ids = set()
    by_domain = {domain: 0 for domain in DOMAINS}
    for case in cases:
        assert REQUIRED <= set(case), case.get("id")
        assert case["id"] not in ids, case["id"]
        ids.add(case["id"])
        assert case["domain"] in DOMAINS, case["domain"]
        by_domain[case["domain"]] += 1
        assert case["required_evidence"] and all(str(x).startswith("E-") for x in case["required_evidence"])
        assert case["method_review"] in ALLOWED_REVIEW
        assert case["local_validation"] in ALLOWED_LOCAL
        for field in ("phenomenon", "hypothesis", "next_probe", "failure_transition", "cannot_claim"):
            assert isinstance(case[field], str) and case[field].strip(), (case["id"], field)
    for domain in ("pe", "android", "js", "protocol", "provider-neutral"):
        assert by_domain[domain] >= 2, (domain, by_domain)
    print(f"PASS: {len(cases)} hard-target evals; " + ", ".join(f"{k}={v}" for k, v in by_domain.items()))


if __name__ == "__main__":
    main()
