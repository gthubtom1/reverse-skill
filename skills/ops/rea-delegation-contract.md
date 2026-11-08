# REA Delegation Contract

## Purpose

`reverse-skill` remains the only router and case authority. In a Pi session, the **Pi main agent / lead is the sole final authority** for route, scope, case, timeline, work item, Evidence, Finding, Path, budgets and replanning. Official REA is a bounded execution backend used after PRIMARY has selected a specialist workflow. REA does not create a second route, scope, case, or evidence graph.

Every role handoff, including advisory and review handoffs, uses the same bounded envelope below. A Worker result is a proposal until the main agent accepts it into the existing case. Missing fields are a handoff failure, not permission to infer defaults.

## Shared handoff envelope

Every handoff MUST carry all of these fields:

```yaml
handoff:
  case_id: <existing case id>
  target:
    identity: <stable target identity>
    sha256: <target/artifact digest; record an explicit unavailable reason if no digest exists>
  current_phase: triage | static | dynamic | synthesis | reconstruction | review
  evidence_question: <one evidence question>
  allowed_actions: []
  write_scope:
    mode: none | bounded
    paths: []
  budget:
    time_seconds: 60
    memory_soft_limit_mb: 512
    max_heavy_providers: 1
  cleanup:
    required: true
    before_provider_replacement: true
  acceptance: []
```

`write_scope` may cover bounded raw artifacts or an explicitly assigned reconstruction workspace; it MUST NOT silently include route, scope, case, timeline, workitems, or the Evidence ledger. `reverse-reviewer`, `planner`, and `scout` use `mode: none`. The `acceptance` list must state the observable Evidence or result the main agent will use to accept or reject the handoff. `evidence_question` is singular even when the result has several observations.


## Work item contract

Every REA request MUST be represented by one bounded work item with these fields:

```yaml
work_item:
  id: WI-###
  case_id: <case id>
  primary: <PRIMARY skill id>
  target:
    identity: <stable target identity>
    path: <artifact path>
    sha256: <digest; explicit unavailable reason if no digest exists>
  current_phase: triage | static | dynamic | synthesis | reconstruction | review
  question: <one evidence question>
  mode: triage | static | dynamic | synthesis
  provider: rea
  allowed_actions: []
  forbidden_actions: []
  write_scope:
    mode: none | bounded
    paths: []
  time_budget_seconds: 60
  memory_soft_limit_mb: 512
  max_heavy_providers: 1
  expected_artifacts: []
  cleanup_required: true
  cleanup_before_provider_replacement: true
  acceptance: []
```

The `question` must identify one material decision. Examples:

- locate references to one string and return the containing functions;
- decompile one selected function and list unresolved branches;
- inspect one PE's certificate table and imports;
- capture one bounded runtime observation.

A request that combines unrestricted strings, full disassembly, dynamic execution, and multiple providers MUST be split before execution.

## Result contract

REA results MUST be carried back into the current case and work item:

```yaml
result:
  work_item_id: WI-###
  status: completed | timed_out | cancelled | failed | blocked
  evidence: []
  findings: []
  unknowns: []
  provider:
    name: <provider>
    session_id: <provider session>
  resources:
    elapsed_seconds: 0
    peak_memory_mb: 0
    process_ids: []
  cleanup:
    requested: true
    completed: true
    remaining_processes: []
```

A result without provider status or cleanup status is incomplete and MUST remain an unknown until verified. A result with failed or unverified cleanup MUST NOT be promoted or used to start a replacement provider.

## Ownership rules

- The Pi main agent / lead owns route, scope, case, work item, timeline, Evidence, Finding, Path, budgets, acceptance and re-planning. It is the only authority that can promote a Worker result or close a phase.
- `reverse-operator` / `cre` owns only the bounded provider operation described by its handoff. It may return raw artifacts and observations within `write_scope`, but it cannot recursively delegate or alter authoritative state.
- `reverse-reviewer` is read-only. It may report review findings, but it cannot execute the target or write the case, Evidence ledger, source tree or reconstruction workspace.
- `planner` / `scout` are advisory. Their suggestions do not create a route, scope, case, work item or Evidence item.
- An implementation Worker may enter `reconstruction` only after the main agent has accepted a behavior Evidence handoff containing the target identity, observed behavior, success criteria and unknowns. The implementation Worker remains bounded by its new handoff and does not become a router.
- `routing.json` remains the only route table; REA never becomes a PRIMARY. Client adapters and global MCP configuration are outside this contract.

## Provider rules

- One heavy native provider per work item by default.
- Heavy providers for the same target MUST run serially across Workers and work items. A comparison requires a new work item with an explicit comparison reason and resource budget, but it starts only after the previous provider's cleanup is verified; do not overlap Ghidra, IDA, radare2, capa, or another heavy native provider for the same target.
- A timeout, provider error, or missing progress requires cancellation, owned-process cleanup, and verified cleanup status before recording the failure and starting any replacement provider. Cleanup is a prerequisite for provider replacement, not a best-effort note.
- Evidence from strings or source-path remnants must be labeled as static indicators until a targeted reference or runtime observation confirms the behavior.

## Transition record

At every REA transition, append a timeline entry with:

```text
work_item_id
provider/session
question
status
resource summary
Evidence IDs
unknowns
cleanup status
next decision_delta
```

The authoritative scope and previous evidence remain referenced through `carry_forward_refs`; they are not copied into the transition.
