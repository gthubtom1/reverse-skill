# Process Lifecycle Contract

## Scope

This contract covers provider processes started by REA and raw fallback processes started by `reverse-skill`. It prevents unowned Ghidra, radare2, capa, IDA, Frida, and helper processes from surviving a work item.

## Process lease

Every process started outside the target itself MUST have a lease containing:

```yaml
process_lease:
  case_id: <case id>
  work_item_id: WI-###
  provider: <provider>
  pid: <pid>
  parent_pid: <parent pid when known>
  executable: <resolved executable path>
  started_at: <ISO-8601>
  expected_exit: true
  cleanup_on:
    - success
    - timeout
    - cancellation
    - session_interruption
```

The lease is case-local and belongs under `work/<case>/`, never in client-global configuration.

## Lifecycle

```text
prepare -> start -> record lease -> poll -> collect evidence
       -> stop/cancel -> terminate owned descendants
       -> verify absence -> record cleanup -> close work item
```

The owner MUST be able to answer which case and work item own every process. An unowned process is a failed execution state.

## Resource gates

Default budgets for R0 are:

| Work | Wall time | Memory soft limit | Heavy providers |
|---|---:|---:|---:|
| artifact/PE triage | 60 s | 512 MB | 0 |
| targeted static lookup | 180 s | 1 GB | 1 |
| selected-function decompilation | 300 s | 1.5 GB | 1 |
| full native analysis | explicit work item | explicit | 1 |

The limits are defaults, not a reason to kill a healthy in-flight operation blindly. Crossing a limit requires a status check and an explicit stop or re-plan decision recorded in the timeline.

## Cleanup requirements

- A normal completion MUST verify that the lease PID and owned descendants exited.
- A timeout MUST cancel before starting any replacement provider.
- A user interruption MUST run the same cleanup path.
- Cleanup MUST never terminate the target application unless the target is itself the owned runtime process for that work item.
- If cleanup cannot verify absence, the work item remains `blocked` and the session reports the remaining PID.

## Forbidden execution patterns

```text
nohup <heavy-provider> ... &
full capa scan without a bounded timeout
multiple `aaa`/full decompilation passes without a new work item
starting a replacement provider while the previous lease is active
```

Use `skills/scripts/process-lease.ps1` for Windows raw fallback processes. REA-managed providers must expose equivalent session and cleanup status through the REA result contract.
