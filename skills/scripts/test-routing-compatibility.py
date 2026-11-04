#!/usr/bin/env python3
"""Check the original routing contract without providing a second router."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'skills/tests/upstream-routing-contract.json'


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def main():
    baseline = json.loads(FIXTURE.read_text(encoding='utf-8'))
    config = json.loads((ROOT / 'skills/config/routing.json').read_text(encoding='utf-8-sig'))
    cases = json.loads((ROOT / 'skills/tests/routing-benchmark.json').read_text(encoding='utf-8-sig'))['cases']
    errors = []
    if digest(cases[:baseline['case_count']]) != baseline['case_prefix_sha256']:
        errors.append('Original benchmark inputs/order/expectations changed')
    original_ids = set(baseline['route_sha256'])
    if [rid for rid in config['priority'] if rid in original_ids] != baseline['priority']:
        errors.append('Original relative route priority changed')
    for rid, expected in baseline['route_sha256'].items():
        route = config['routes'].get(rid)
        if route is None:
            errors.append('Original route missing: ' + rid)
            continue
        route = json.loads(json.dumps(route))
        if rid == 'R15':
            # The only approved existing-rule extension appends new follow-update terms.
            keyword = route['keywords'][0]
            must = keyword.get('must', '')
            length = baseline['r15_original_must_length']
            if must[length:] != baseline['r15_approved_suffix']:
                errors.append('R15 has an unreviewed keyword extension')
            keyword['must'] = must[:length]
            keyword.pop('note', None)
        if digest(route) != expected:
            errors.append('Original route semantics changed: ' + rid)
    if config['meta']['fallbackId'] != baseline['fallback_id']:
        errors.append('Original fallback changed')
    if errors:
        print('\n'.join('FAIL: ' + item for item in errors))
        return 1
    print(f"PASS: {len(original_ids)} original routes, {baseline['case_count']} unchanged cases, original priority and fallback")
    return 0


if __name__ == '__main__':
    sys.exit(main())
