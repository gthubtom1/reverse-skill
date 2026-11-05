# Beginner Operator Guidance Contract

## Purpose

This is a presentation and interaction contract for zero-beginner operators. It does not create a second router, PRIMARY, case system, provider, or GOAL engine. The reverse core remains the only authority for route, scope, case, work item, Evidence, Finding, Path, REA delegation, budgets and cleanup.

The operator should be able to start with plain language and choose a numbered recommendation without knowing Ghidra, radare2, REA, Static, Dynamic, or Evidence terminology.

## Stage response contract

After each material stage or work item, the assistant MUST present these parts in plain Chinese:

```text
本轮做了什么
目前确认了什么
目前还不知道什么
下一步建议
```

`下一步建议` is generated from the current Evidence, Unknowns, stage gate and available providers. It is not a fixed menu and must not be copied unchanged between unrelated states.

Each option MUST include:

```yaml
option:
  id: "1"
  plain_label: <plain-language action>
  technical_label: <technical term in parentheses>
  purpose: <why this action matters now>
  effect: <read-only, writes case artifacts, starts runtime observation, or other effect>
  prerequisites: []
  recommendation: true | false
  next_work_item: <bounded work item intent>
  expected_output: []
  stop_conditions: []
```

The user can reply with the option id. The assistant maps that id to the recorded `next_work_item`; the user does not need to restate a technical prompt or select a tool. `1` and `A` are both acceptable when the displayed menu uses them, but one response must use one consistent id style.

A recommendation must explain why it is recommended. An option that changes scope, starts a target, uses network access, modifies a file, or requires user-held input must state that effect in plain language.

## No artificial menus

- If the next action is a hard gate with only one valid path, the assistant may show one numbered recommendation so a beginner can approve it, but must not invent alternatives.
- If there are materially different Evidence-supported paths, show 2–5 options.
- Do not ask the user to choose between REA, Ghidra, IDA or radare2. The provider is an internal execution choice.
- Do not expose raw addresses, command lines, YAML or long pseudocode in the main explanation. Put technical detail in an optional appendix or Evidence reference.
- Do not ask the user to reply “continue” as the only interaction. The displayed option id is the control input.

## Goal candidate contract

When triage or a later synthesis stage has enough Evidence to evaluate longer-term outcomes, the assistant MUST offer multiple feasible goal candidates when more than one materially different outcome exists. Candidates must be based on current Evidence, not a generic fixed list.

Each candidate MUST contain:

```text
目标名称（白话 + 技术术语）
最终能得到什么
当前可行性：高 / 中 / 低 / 未知
已经具备的证据
还缺什么
预计阶段
限制和可能阻塞
可复制的 GOAL 文本
```

The GOAL text is for a separate host-provided goal mode. `reverse-skill` does not implement or own that goal engine. The text must define the target outcome, scope, constraints, success criteria, unknown handling, stop conditions, and the requirement to reuse the current case. It must be copyable without requiring the user to understand technical terms.

A goal candidate must not promise source-level recovery or behavioral equivalence when the current Evidence cannot support that claim. It must label the closest achievable outcome and preserve unknowns.

## Goal candidate examples

These are examples of outcome categories, not a mandatory menu:

- source structure recovery (源码结构恢复);
- behavior-equivalent independent implementation (行为等价独立实现);
- bounded binary modification on a copy (副本上的二进制修改验证);
- protocol/API reconstruction (协议/API 重建);
- UI and feature reconstruction after behavior is confirmed (UI/功能重建);
- version adaptation and original-vs-new comparison (跨版本适配与行为对比);
- specification and test package only (功能规格与测试包).

The current target, Evidence coverage, provider availability, and unknowns determine which candidates appear and how they are described.

## Autonomy and blockers

After the user selects a goal candidate, routine deterministic work proceeds automatically inside bounded work items. The assistant pauses with a short numbered blocker menu only when:

- a user-held file, credential, device, account, or live process is required;
- a new network or runtime scope is required;
- two Evidence-supported paths would change the outcome;
- the target or goal scope must change;
- a provider fails, times out, or leaves cleanup unverified;
- the next action would modify the original target or create an irreversible effect.

A blocker response MUST say what was completed, what is blocked, why it is blocked, and what each option changes. “The agent is stuck” is not an acceptable operator-facing result.

## Evidence and truthfulness

Plain-language summaries are a rendering of the authoritative case state. They must distinguish observed facts, inferences and unknowns. A string, source path, command name, package member or static candidate is not a confirmed behavior until targeted Evidence or runtime observation supports it.
