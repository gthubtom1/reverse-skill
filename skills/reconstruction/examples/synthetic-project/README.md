# Synthetic handoff project

This project is an entirely synthetic, anonymized pointer-format fixture. It contains no target executable, customer sample, credentials or real application. All source files are Markdown, Python or JSON.

The `synthetic-bundle.json` and `synthetic-obligations.json` documents are explicitly fixture-only material. They are NOT authentic REA exports, proof, generated semantic IDs or semantic verification results. The human-readable obligation name is a synthetic reviewed-claim label. No `passed` flag or fabricated native Evidence ID is supplied.

The fixture describes only a literal empty-input observation: an imaginary original returns exit code 2. Changing the spec to claim exit code 0 while updating the spec commitment demonstrates a semantic mis-citation that a path/hash/reference checker cannot detect. Independent review must reject that spec; the checker must continue to say `semantic_verification: not_performed`.

From the skill-package root:

```text
python -B skills/reconstruction/scripts/check_handoff.py skills/reconstruction/examples/synthetic-project case-fixture/demo/notes/handoff-manifest.json --format json
python -B -m unittest discover -s skills/reconstruction/tests -p "test_*.py" -v
```

The static example uses `case-fixture/demo/` so the package's runtime `work/` ignore rule cannot hide its source files. Real outcome projects MUST use the original `work/<case>/` convention. All native case filenames and reference semantics are preserved here.

Expected checker exit is 0, strictly `machine_check_only`. This demonstrates pointer mechanics, not implementation readiness, official-tool compatibility or an end-to-end reconstruction/update experiment. Scope, timeline, workitems and feature documents are original-contract-shaped synthetic records, retained as the recovery entry. The handoff JSON is a disposable projection of those documents, not their state store.
