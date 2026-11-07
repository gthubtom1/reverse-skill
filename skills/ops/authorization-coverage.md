# Authorization surface coverage and closure — schema v2

Use this contract when an already authorized case includes authorization, licensing, entitlement, feature gating, integrity or bypass behavior. Inventory every in-scope component/gate before changing an analysis copy. One patch, one working feature or a successful process start cannot close the aggregate goal.

The inventory and coverage manifest are case artifacts under the **existing** `work/<case>/`, typically `notes/authorization-inventory.json` and `notes/authorization-coverage.json`. They reference the existing `scope.md` and `evidence/E-*.md`. They are not another case, task ledger, authorization system or permission grant. Preserve the existing authorization, scope, network and work-item authority.

## Run the read-only checker

```text
python -B skills/scripts/check-authorization-coverage.py work/<case>/notes/authorization-coverage.json --case-root work/<case> --format json
python -B skills/scripts/check-authorization-coverage.py work/<case>/notes/authorization-coverage.json --case-root work/<case> --require-complete --format json
```

Before any aggregate completion claim, run the second command with `--require-complete`, require `summary.complete: true`, then independently review the supporting behavior/regression Evidence and cleanup. The ordinary progress command's exit `0` is never a completion signal.

The checker uses only the Python standard library. The caller supplies the existing case root explicitly; the manifest cannot redirect it. It reads and hashes files, parses records and computes coverage. It never patches files, runs manifest/Evidence commands, executes tests, applies rollback, changes scope, writes case state, starts providers or contacts the network.

| Exit | Meaning |
|---|---|
| `0` | Schema and referenced bytes are valid. Without `--require-complete`, this **also permits incomplete progress**. Inspect `summary.complete`. |
| `1` | Invalid schema, unsafe/missing reference, hash or identity mismatch, or a false `complete: true` claim. |
| `2` | With `--require-complete`, a valid manifest remains incomplete. Argparse also uses `2` for CLI usage errors. |

JSON output includes `ok`, `errors`, `blockers`, `summary` and `exit_code`. `ok` means no schema/provenance errors; it does not mean closed. `summary.complete` is only mechanical closure within the supplied records. `summary.mechanical_only` is always `true`. Text output explicitly says `INCOMPLETE`, `INVALID` or `MECHANICALLY COMPLETE`; it never treats a valid partial manifest as a successful closure.

## Existing scope and immutable inventory linkage

Keep the existing `## meta` / `case_id`, `## auth` and `## signoff` fields. Once the inventory revision is established in the case, add this closure-specific section to that same `scope.md`:

```markdown
## authorization_coverage
- target_sha256: <original target artifact SHA-256>
- inventory_sha256: <exact inventory JSON file SHA-256>
```

This section records byte identities; **it does not authorize anything**. Do not change `auth.status` or manufacture authorization to make this check pass. Existing scope that is not `auth.status: granted` and `signoff.ready_for_act: true` remains an explicit closure blocker, while a structurally valid partial report can still be inspected. This checker does not replace `case-guard` or evaluate the legal/operational sufficiency of scope.

Register the original target and the inventory as artifacts of existing case Evidence records. The checker verifies this chain:

```text
explicit case root
  -> scope.md hash + meta.case_id
  -> scope.authorization_coverage target/inventory hash pins
  -> manifest target/inventory Evidence references
  -> Evidence file hashes and matching E-* headings
  -> Evidence artifact_path + content_hash
  -> exact target/inventory artifact bytes
```

Changing only the manifest, inventory artifact or its Evidence pointer cannot shrink the pinned denominator. Every inventory surface must have exactly one manifest entry. There is no `required`, `required_for_completion` or optional-row escape hatch; those fields are rejected.

A legitimate discovery, scope revision or corrected neighbor model requires a reviewed new inventory revision through the existing case workflow. Update its existing case pins/references deliberately and preserve the previous revision through normal Evidence/timeline practice. The inventory hash changes, so old results must be replaced with fresh results for the new revision. The checker never repins anything.

“Immutable” here means a fixed hash in trusted existing case authority, not write protection or a cryptographic signature. Someone who can replace the scope, Evidence and artifacts together can fabricate a consistent bundle. Preserve/review the case authority outside this checker.

## Shared field types

All JSON objects below use **exact fields**: required fields must exist and unknown fields are rejected. `complete` is the sole optional manifest field. Schema version must be integer `2`, never a boolean or string. The v1 draft with bare Evidence/test IDs is unsupported.

- **ID**: 1–128 characters matching `[A-Za-z0-9][A-Za-z0-9_.-]*`.
- **SHA-256**: exactly 64 lowercase hexadecimal characters, computed over file bytes.
- **UTC time**: `YYYY-MM-DDTHH:MM:SS[.ffffff]Z`, with 1–6 optional fractional digits. Offsets and timezone-less timestamps are rejected.
- **FileRef**: `{"path": "artifacts/example.bin", "sha256": "<SHA-256>"}`.
- **EvidenceRef**: `{"id": "E-example", "path": "evidence/E-example.md", "sha256": "<Evidence Markdown file SHA-256>"}`. The ID must start with `E-`, the path must match that ID, and conflicting hashes for one Evidence ID are rejected.

Every reference must resolve to an existing regular file inside the explicit case root. Use canonical relative paths with `/`. Absolute/drive/UNC paths, `..`, `.`, empty segments, backslashes, colons/alternate streams, percent escapes, control characters, trailing dots/spaces and Windows device names are rejected. Symlinks, Windows reparse points and hard-linked files are rejected, including linked path ancestors. Supply a physical case-root path without linked ancestors. The manifest itself must also be a regular case-local file. No external URLs are fetched.

JSON and Evidence/scope documents are limited to 2 MiB each; binary artifacts are hashed incrementally. Duplicate JSON keys, non-finite constants, invalid UTF-8, unsupported types and excessive nesting are errors. A missing artifact is an error even on an incomplete row; use honest status fields to represent unfinished analysis, not invented references.

Evidence uses the existing one-record-per-file Markdown convention:

```markdown
### E-example
- title: Observation or result provenance
- observed_at: 2026-11-07T01:00:00Z
- source_type: file
- source_ref: artifacts/example.log
- content_hash: <artifact SHA-256>
- artifact_path: artifacts/example.log
- repro_command: |
    descriptive reproduction command, never executed by this checker
- raw_excerpt: |
    redacted observation
- linked_workitem: WI-001
- supersedes: none
```

The first Markdown heading must identify the referenced E-ID, optionally followed by a title separated by whitespace. The checker consumes `observed_at`, `artifact_path` and `content_hash`, checks the heading and both hashes, and rejects future observation times. Keep the remaining provenance fields according to the existing Evidence contract; their substantive sufficiency is the case-review responsibility. Indented/fenced command text is not executed. Coverage references require file-backed Evidence rather than `content_hash: n/a`; attach an appropriate case-local observation artifact to existing manual/network Evidence when needed.

## Inventory JSON

The inventory has these required fields:

| Field | Type and rule |
|---|---|
| `schema_version` | Integer `2`. |
| `case_id` | Existing case ID, identical to scope and manifest. |
| `target_sha256` | Original target hash, identical to the scope pin and manifest. |
| `review` | `{"status": "pending" or "reviewed", "evidence": [EvidenceRef, ...]}`. `reviewed` requires nonempty Evidence. Pending review permits progress but blocks aggregate closure. |
| `surfaces` | Nonempty array of surface objects below. |
| `regressions` | Nonempty array of regression definitions below. |

Inventory review Evidence must address **completeness**, the in-scope component discovery sources, exclusions, boundary/error states and the affected-neighbor model. A bare `reviewed` flag is insufficient. The checker verifies the records and hashes, not the truth or quality of this review.

Each surface has exactly these fields:

```json
{
  "id": "AUTH-main-license",
  "component": "main binary",
  "source": {"path": "artifacts/original-main.bin", "sha256": "<SHA-256>"},
  "gate": "offline license validation",
  "entry_point": "LicenseGate::validate",
  "expected_behavior": "Allow the authorized fixture; reject invalid and expired fixtures with the recorded errors.",
  "neighbors": ["AUTH-plugin-export"],
  "regression_ids": ["T-main-license"]
}
```

The example is schematic: replace placeholders with real hashes and include the referenced neighbor and regression definitions. `component`, `gate`, `entry_point` and `expected_behavior` are nonempty strings. `source` hashes the component's baseline artifact independently of the aggregate target hash. For a genuinely unexamined location, explicitly describe the unresolved entry point and keep the row unexamined; text alone cannot verify it.

`neighbors` is a directed list of other surface IDs whose behavior may be affected by changing this surface. It may be empty only when the completeness/impact review supports that conclusion. Self, duplicate and unknown neighbors are rejected. Include another gate in the same component when relevant, not only another binary. Each component/gate has its own ID. `regression_ids` is nonempty and duplicate-free.

A regression definition has exactly these fields:

```json
{
  "id": "T-main-license",
  "covers": ["AUTH-main-license"],
  "specification": {"path": "artifacts/test-main-license.md", "sha256": "<SHA-256>"},
  "max_age_hours": 168
}
```

`covers` is a nonempty, duplicate-free list of known surface IDs. Every listed surface must include this test in its `regression_ids`, and every test a surface requires must cover that surface. There are no unrequired regression definitions. The specification can be the case-local test source or a precise test procedure; its bytes are hashed but never executed. `max_age_hours` is an integer from 1 to 8760 and forms part of the pinned inventory policy.

Include all applicable surfaces: main binary, modules/plugins, Java/native/JNI, offline cache, online validation, license/device binding, feature flags, update/heartbeat, integrity/self-check and relevant success/failure states. For an external service, use a scoped case-local observation/snapshot as the source identity; the checker cannot independently establish current remote state.

## Coverage manifest JSON

```json
{
  "schema_version": 2,
  "case_id": "case-example",
  "goal_id": "GOAL-LOGIC",
  "target_sha256": "<original target SHA-256>",
  "scope": {"path": "scope.md", "sha256": "<current scope SHA-256>"},
  "target_evidence": {"id": "E-target", "path": "evidence/E-target.md", "sha256": "<SHA-256>"},
  "inventory_evidence": {"id": "E-inventory", "path": "evidence/E-inventory.md", "sha256": "<SHA-256>"},
  "entries": [],
  "regression_results": [],
  "complete": false
}
```

This is a field overview, not a passing fixture: fill `entries` with every pinned surface. `regression_results` can be empty during partial work. `complete` is optional and boolean. `true` asserts closure and is rejected if any condition remains open; `false` or omission allows the checker to compute progress without making that assertion.

Each entry has exactly these fields:

```json
{
  "id": "AUTH-main-license",
  "status": "patched",
  "current": {"path": "artifacts/workcopy-main.bin", "sha256": "<SHA-256>"},
  "changed_at": "2026-11-07T01:00:00Z",
  "patch": {"path": "artifacts/main-change.diff", "sha256": "<SHA-256>"},
  "rollback": {"path": "artifacts/main-revert.diff", "sha256": "<SHA-256>"},
  "evidence": [{"id": "E-main", "path": "evidence/E-main.md", "sha256": "<SHA-256>"}],
  "reason": "",
  "side_effects": "Plugin export is affected; linked Evidence records the change/impact and rollback review."
}
```

`current` records the present case-local component bytes. For an unchanged/unexamined component, use its baseline file, set both `patch` and `rollback` to `null`, and record when that state was established in `changed_at`. A changed hash requires both patch and rollback FileRefs. A patch may also describe an environment/configuration change while component bytes remain identical; include every relevant changed input in the inventory/state. `changed_at` must not be in the future.

`reason` and `side_effects` are always strings. `side_effects` must be nonempty for a patch. Patched rows require nonempty Evidence documenting the observed behavior, patch, affected-neighbor/side-effect review and rollback record. An unchanged verified row needs no invented patch. Hashing a rollback record does not prove rollback was tested or will work.

| Status | Meaning and requirements |
|---|---|
| `unexamined` | Inventoried but not investigated. No patch; may have empty Evidence. |
| `observed` | Observation exists; nonempty Evidence, no patch. |
| `patched` | Change exists; patch, rollback and Evidence required. Still incomplete. |
| `verified` | Candidate closed state; nonempty Evidence, plus all own and affected-neighbor results must pass. Patch is optional if unchanged. |
| `blocked` | Nonempty reason; incomplete. Keep any already-made patch and rollback visible. |
| `unknown` | Nonempty reason; incomplete. Keep any already-made patch and rollback visible. |
| `not-applicable` | Nonempty reason and Evidence; no patch, current hash equals baseline. Planned regression checks must still pass, for example a check of the claimed absence. |

## Regression result artifacts and freshness

`regression_results` contains EvidenceRefs, not test IDs or inline status claims. Each Evidence artifact is a JSON result with exactly these fields:

```json
{
  "schema_version": 2,
  "id": "T-main-license",
  "case_id": "case-example",
  "target_sha256": "<original target SHA-256>",
  "inventory_sha256": "<pinned inventory artifact SHA-256>",
  "state_sha256": "<current component state digest>",
  "specification_sha256": "<test specification FileRef SHA-256>",
  "tested_surfaces": ["AUTH-main-license"],
  "status": "pass",
  "executed_at": "2026-11-07T02:00:00Z",
  "evidence": [{"id": "E-run-main", "path": "evidence/E-run-main.md", "sha256": "<SHA-256>"}]
}
```

The result ID must name a pinned regression definition. Duplicate/unknown IDs, a different case/target, a different `tested_surfaces` set or missing raw observation Evidence are errors. The result's Evidence records reference real case-local logs/differential outputs; merely writing `pass` is not sufficient provenance. Keep one current result per test in the manifest; retain history through existing Evidence practice.

`status` is `pass`, `fail`, `blocked`, `unknown` or `skipped`. Non-pass is a legitimate result that blocks closure. Matching target/case with a stale inventory/state/specification digest is also a blocker, so historical results can remain visible without being accepted as current. A changed referenced file with an unchanged FileRef hash is instead a provenance error.

A current pass must satisfy all of these:

- Inventory, component state and specification digests match the current inputs.
- `executed_at` is no earlier than **every** entry's `changed_at`.
- `executed_at` is not in the future and is at most the pinned `max_age_hours` old, using the checker's current UTC clock.
- All result and underlying observation references exist and match their hashes.

The whole-state digest intentionally invalidates all old regressions after **any** component/patch/rollback/time change. This is conservative and avoids pretending that the checker can prove independence between components.

To compute `state_sha256`, construct one object per entry containing exactly these six fields, using the matching inventory surface for `source_sha256`:

```json
{
  "id": "AUTH-main-license",
  "source_sha256": "<baseline component hash>",
  "current_sha256": "<current component hash>",
  "patch_sha256": "<patch hash, or JSON null>",
  "rollback_sha256": "<rollback hash, or JSON null>",
  "changed_at": "2026-11-07T01:00:00Z"
}
```

Sort the array by `id`, serialize with Python `json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")`, then SHA-256 those exact bytes. Use actual JSON `null` for an absent patch or rollback, not the string `"null"`. The checker exposes the computed value as `summary.state_sha256` even on a structurally valid partial manifest, allowing the test runner to bind results without executing anything through the checker. Status/evidence text changes do not alter the state digest; artifact bytes and pinned inventory definitions do.

## Aggregate closure and reopening

Mechanical closure requires all of the following:

1. Existing scope identity/pins, target, inventory, sources, current bytes, patch/rollback, specifications, Evidence and results pass schema/path/hash checks.
2. Inventory completeness/neighbor review is `reviewed` with file-backed Evidence.
3. Every inventoried surface is present exactly once and declares `verified` or evidenced `not-applicable`.
4. Every planned required regression has a current bound `pass`. Unknown, blocked, skipped, failing, missing or stale results cannot close a surface. `not-applicable` cannot hide required tests.
5. For each changed surface, all tests required by its declared affected neighbors also pass.

If a plugin regression fails, the plugin and any patched surface declaring that plugin as affected reopen. `summary.reopened` lists affected closed rows, reasons and an `effective_status` of `patched` or `unknown`. The checker does not rewrite the manifest. Update the existing case row/Evidence honestly; only a fresh bound pass restores closure. A result declaring `pass` but referring to the previous patch is still stale.

Report `summary.verified / summary.required` separately from `summary.not_applicable` and `summary.closed`. For example: **“1/7 authorization surfaces verified; 6 remain unexamined.”** The denominator is always the pinned inventory, never the subset that was patched or tested.

## Tests and limits

Run the offline synthetic test suite:

```text
python -B skills/scripts/test-authorization-coverage.py
```

It creates a new temporary directory and prints its location. `--work-dir <new-absent-directory>` chooses that location. Fixtures are retained for inspection and can then be moved to the recycle bin; the test script never deletes files. No real target, provider, network access or extra package is required. Tests cover complete/partial closure, `1/7`, false completion, omitted components/inventory shrink, review Evidence, result identity/hash/time freshness, neighbor reopening, not-applicable constraints, malformed types/JSON, unsafe paths, links and read-only behavior. Link tests explicitly report a skip if the operating system cannot create that link type.

This is a practical mechanical validator, **not a proof engine**. It cannot discover components omitted from the trusted inventory, determine whether a neighbor graph/expected behavior is correct, prove that recorded tests ran, establish independent observation provenance, validate patch/rollback semantics, infer unrecorded runtime/environment changes, or certify business equivalence. Result timestamps depend on the case records and local clock; no attested time or full execution-history ordering is provided. Selecting an older still-fresh matching pass while withholding a newer failure is outside this checker's visibility and remains an Evidence-review failure.

Use a stable trusted case snapshot while checking. Path/link checks are conservative but are not a filesystem sandbox against concurrent hostile path replacement. Hashes detect changed referenced bytes; they are not signatures. Existing case review, actual differential validation, cleanup verification and authorization controls remain necessary before any broader completion claim.
