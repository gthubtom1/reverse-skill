# Beginner Operator Guidance Contract

## Purpose

This is a presentation and interaction contract for zero-beginner operators. It does not create a second router, PRIMARY, case system, provider, or GOAL engine. The reverse core remains the only authority for route, scope, case, work item, Evidence, Finding, Path, REA delegation, budgets and cleanup.

The operator should be able to start with plain language and choose a numbered recommendation without knowing Ghidra, radare2, REA, Static, Dynamic, or Evidence terminology.

Routine evidence-driven work is not gated on a goal-candidate selection. Once package activation, the disclosed first-side-effect plan and the case scope gate are satisfied, bounded work inside the existing goal, scope, effects and budget proceeds automatically from task start.

## Stage response contract

At a meaningful milestone, changed finding or blocker, report in plain Chinese. Related routine work items may be grouped into one progress update; do not emit a full form after each small step. The report is informational: a progress report MUST NOT be phrased as, or treated as, an approval request. When the next action is routine and stays inside the existing goal, scope, effects and budget, report it and continue without waiting for a reply.

```text
本轮做了什么
目前确认了什么
目前还不知道什么
下一步建议
```

`下一步建议` is generated from the current Evidence, Unknowns, stage gate and available providers. It is not a fixed menu and must not be copied unchanged between unrelated states. If the next action is routine, or only one technically valid path exists, it states that single bounded action and the assistant proceeds; it MUST NOT manufacture a menu or ask the user to reply “continue” as approval.

For a real outcome choice, explain each option in one or two plain-language sentences: what it achieves, material effects, and the recommendation. Keep the mapping to case/work-item ids, prerequisites, expected artifacts and stop conditions in the existing case notes; do not display this internal schema as YAML or require the operator to fill it.

A missing file or new authorization is usually one short question, not a menu. For example: “下一步必须运行这个程序并连接指定服务器，超出了当前的离线分析范围。请确认是否允许；确认前这一步保持暂停。” Do not pad it with reports, half-solutions, unrelated options or repeated continue confirmations.

When there are genuinely several user-owned outcomes, show 2–5 numbered options. The user can reply with an id; translate it into the corresponding work item. A recommendation explains why it is useful and what changes for the user. Existing technical steps resume automatically after the decision is settled.

## Menus only for genuine user decisions

A menu is allowed only when the next action needs a real decision that belongs to the user:

- a real outcome or value tradeoff between materially different final results;
- new authority, effect, network/runtime scope, or original/irreversible target modification;
- missing user-only input such as a file, credential, device, account, or live process;
- unresolved owned-process cleanup, or no feasible path within the current budget;
- the target or goal scope must change.

Multiple technical paths to the same outcome are not a user decision. Choosing a provider, tool, method, subagent/delegation, whether to fact-check, or how to report is internal. Do not ask the user to choose between REA, Ghidra, IDA or radare2, and do not turn a recoverable provider failure into a menu once owned cleanup is verified.

- Several genuine outcome choices → show 2–5 numbered options. A simple missing input or authority request → ask only that question.
- Routine bounded action, or one technically valid path → show no menu; state the next action and proceed.
- Never emit a one-option menu and never ask the user to reply “continue” as approval.
- When there is only one remedy for a blocker, state it directly instead of padding a menu.
- Do not expose raw addresses, command lines, YAML or long pseudocode in the main explanation. Put technical detail in an optional appendix or Evidence reference.

## Goal candidate contract

Only when the goal remains unresolved or new Evidence invalidates it, and triage or synthesis supports more than one materially different outcome, offer 2–5 feasible goal candidates. Candidates must be based on current Evidence, not a generic fixed list. Offering candidates does not gate routine work: bounded actions inside the current task continue while the user considers the longer-term outcome.

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

After activation, approval of the disclosed first-side-effect plan, and satisfaction of the case scope gate, routine evidence-driven bounded work proceeds automatically from task start. It does not require a selected long-term goal candidate, a fresh approval per work item, or a new menu after each progress report.

The assistant pauses only when a real user-owned decision or blocker exists:

- a user-held file, credential, device, account, or live process is required;
- a new authority, effect, network or runtime scope, or modification of the original target or another irreversible effect is required;
- the final outcome or user-visible value has a real tradeoff between materially different results;
- the target or goal scope must change;
- owned cleanup remains unresolved after a provider failure or timeout;
- no feasible path remains inside the current budget.

A provider failure, timeout, or multiple technical routes with the same outcome is not by itself a user decision. Resolve it internally while preserving the work-item budget and cleanup contract; escalate only if it becomes one of the blockers above. A blocker response MUST say what was completed, what is blocked, why it is blocked, and what each option changes. “The agent is stuck” is not an acceptable operator-facing result.

## Reuse decisions

Read the current case and conversation before asking. Record settled goals, scope, preferences, user-only answers and their source once in the existing timeline/notes. Do not ask them again at stage transitions or after a provider change. If a missing answer is not blocking current work, ask once and continue independent bounded work; do not repeat it in every progress report. New Evidence may reopen only the decision it invalidates, with a specific reason.

### Keep the operator question small

For a missing input or a request for new authority, ask one concise question stating the required input/effect and why it blocks this step. Do not display a menu for an authorization-only question. Do not recommend a report, a partial action that cannot complete the stated check, or another approval round merely to create options. Record the technical plan internally and carry existing approval forward.

## Evidence and truthfulness

Plain-language summaries are a rendering of the authoritative case state. They must distinguish observed facts, inferences and unknowns. A string, source path, command name, package member or static candidate is not a confirmed behavior until targeted Evidence or runtime observation supports it.
