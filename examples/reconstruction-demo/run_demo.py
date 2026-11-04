#!/usr/bin/env python3
"""Execute source-owned O/C/N fixtures. This is not an REA proof producer."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent


def observe(node, program, case, cwd=None):
    request = case.get('raw_input', json.dumps(case.get('input'), ensure_ascii=False))
    process = subprocess.run([str(node), str(program)], input=request, text=True,
                             encoding='utf-8', capture_output=True, timeout=10, cwd=cwd)
    parsed = None
    error = None
    try:
        parsed = json.loads(process.stdout)
    except (ValueError, TypeError) as exc:
        error = str(exc)
    return {'exit_code': process.returncode, 'stdout': process.stdout,
            'stderr': process.stderr, 'json': parsed, 'parse_error': error}


def compare(node, original, replica, cases):
    records = []
    for case in cases:
        left = observe(node, original, case)
        right = observe(node, replica, case)
        comparable = (left['exit_code'] == right['exit_code'] == 0 and
                      isinstance(left['json'], dict) and isinstance(right['json'], dict) and
                      'result' in left['json'] and 'result' in right['json'])
        result_matches = comparable and left['json']['result'] == right['json']['result']
        ui_matches = isinstance(right['json'], dict) and right['json'].get('ui') == {'brand': 'My Lab', 'theme': 'indigo'}
        records.append({'case_id': case['id'], 'input': case, 'original': left,
                        'replica': right, 'behavior_match': result_matches,
                        'custom_ui_preserved': ui_matches})
    return records


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--node', default=shutil.which('node'))
    parser.add_argument('--out', type=Path)
    args = parser.parse_args(argv)
    if not args.node:
        parser.error('Node.js is required; select an existing runtime with --node')
    cases = json.loads((ROOT / 'cases.json').read_text(encoding='utf-8'))['cases']
    old_cases = [case for case in cases if case['id'].startswith('old-') or case['id'] in ('malformed-json', 'null-request')]
    old = compare(args.node, ROOT / 'original-v1.cjs', ROOT / 'replica-v1.cjs', old_cases)
    stale = compare(args.node, ROOT / 'original-v1.1.cjs', ROOT / 'replica-v1.cjs', cases)
    updated = compare(args.node, ROOT / 'original-v1.1.cjs', ROOT / 'replica-v1.1.cjs', cases)
    out = args.out or Path(tempfile.mkdtemp(prefix='reverse-follow-update-'))
    out.mkdir(parents=True, exist_ok=True)
    for name, rows in [('old-baseline', old), ('stale-replica', stale), ('updated-replica', updated)]:
        (out / (name + '.json')).write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with tempfile.TemporaryDirectory(prefix='replica-only-') as scratch:
        copied = Path(scratch) / 'application.cjs'
        shutil.copyfile(ROOT / 'replica-v1.1.cjs', copied)
        isolated_copy = observe(args.node, copied, cases[0], cwd=scratch)
    # A clean copy demonstrates no project-relative original dependency. It is not OS access isolation.
    summary = {
        'scope': 'source-owned CLI fixture, not arbitrary binary reconstruction or REA closure',
        'old_baseline_passed': sum(row['behavior_match'] and row['custom_ui_preserved'] for row in old),
        'old_baseline_total': len(old),
        'stale_replica_mismatches': sum(not row['behavior_match'] for row in stale),
        'updated_passed': sum(row['behavior_match'] and row['custom_ui_preserved'] for row in updated),
        'updated_total': len(updated),
        'clean_copy_execution_passed': isolated_copy['exit_code'] == 0 and isolated_copy['json'] == updated[0]['replica']['json'],
        'os_access_isolation_verified': False,
        'cases_are_public_regression_not_holdout': True,
        'program_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in
                           ('original-v1.cjs', 'original-v1.1.cjs', 'replica-v1.cjs', 'replica-v1.1.cjs')},
        'comparison_rule': 'Exact result object and successful JSON process output; custom UI checked separately. No other normalization.',
    }
    passed = (summary['old_baseline_passed'] == summary['old_baseline_total'] and
              summary['stale_replica_mismatches'] > 0 and
              summary['updated_passed'] == summary['updated_total'] and
              summary['clean_copy_execution_passed'])
    summary['status'] = 'pass' if passed else 'fail'
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=True))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
