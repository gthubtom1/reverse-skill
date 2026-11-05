# REA Delegation Contract

## Purpose

`reverse-skill` remains the only router and case authority. Official REA is a bounded execution backend used after PRIMARY has selected a specialist workflow. REA does not create a second route, scope, case, or evidence graph.

## Work item contract

Every REA request MUST be represented by one bounded work item with these fields:

```yaml
work_item:
  id: WI-###
  case_id: <case id>
  primary: <PRIMARY skill id>
  target:
    path: <artifact path>
    sha256: <digest when available>
  question: <one evidence question>
  mode: triage | static | dynamic | synthesis
  provider: rea
  allowed_actions: []
  forbidden_actions: []
  time_budget_seconds: 60
  memory_soft_limit_mb: 512
  max_heavy_providers: 1
  expected_artifacts: []
  cleanup_required: true
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

A result without provider status or cleanup status is incomplete and MUST remain an unknown until verified.

## Ownership rules

- `reverse-skill` owns route, scope, case, work item, timeline, Evidence, Finding, Path, budgets, and re-planning.
- REA owns the provider session and the bounded analysis operation.
- Raw CLIs are fallback providers only when REA lacks the required capability or reports a provider failure.
- `routing.json` remains the only route table; REA never becomes a PRIMARY.
- Client adapters and global MCP configuration are outside this contract.

## Provider rules

- One heavy native provider per work item by default.
- Do not run Ghidra, IDA, radare2, capa, or another heavy native provider concurrently for the same target unless a new work item explicitly records the comparison reason and resource budget.
- A timeout, provider error, or missing progress triggers cancellation and re-planning. It does not authorize another heavy process automatically.
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
