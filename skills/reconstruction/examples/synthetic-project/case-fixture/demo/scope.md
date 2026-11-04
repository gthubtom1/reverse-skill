# Case Scope

## meta
- case_id: synthetic-demo
- operator: synthetic-fixture
- primary_skill: reconstruction

## auth
- status: granted
- basis: lab_only
- evidence_of_auth: synthetic document-only fixture; no target execution authorized

## in_scope
- assets:
  - evidence/observation.md
- activities: [read_fixture]

## out_of_scope
- activities: [target_execution, network]

## network_profile
- mode: offline

## signoff
- ready_for_act: false

This fixture is for read-only pointer tests. Neither the scope text nor checker PASS grants permission to execute any target.
