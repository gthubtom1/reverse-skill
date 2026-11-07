# Guided operator contract

This is the interaction contract for all reverse entrypoints. It changes presentation; `routing.json` and the native router still select PRIMARY. The original case owns scope, Evidence, Findings, Paths, workitems and completion. Cards do not implement a router or require a host GOAL engine.

## User decisions

Show only feasible choices relevant to the current decision. Preserve a clear natural-language request without making the user select the same goal again. The following IDs name decision categories; they never grant blanket permission or replace the full option text.

| Family | Stable ID | Plain-language result or effect |
|---|---|---|
| Goal | `GOAL-REPORT` | 查明当前能证明的内容并交付报告 |
| Goal | `GOAL-LOGIC` | 解释指定行为及关键逻辑 |
| Goal | `GOAL-RECONSTRUCT` | 证据足够后，在独立项目实现指定功能 |
| Goal | `GOAL-COMPARE` | 对照原版和指定实现的行为 |
| Goal | `GOAL-UPDATE` | 复用原 case，适配指定新版本 |
| Scope | `SCOPE-STATIC-ONLY` | 只检查文件，不运行目标 |
| Scope | `SCOPE-ISOLATED-RUNTIME` | 在已说明的隔离环境运行指定副本 |
| Scope | `SCOPE-AUTHORIZED-DEVICE` | 在明确指定的授权设备上执行列明的动作 |
| Scope | `SCOPE-WORKCOPY` | 修改指定工作副本并保留原件和回滚 |
| Delivery | `DELIVERY-REPORT` | 交付证据报告及限制 |
| Delivery | `DELIVERY-CORE` | 先交付指定核心功能及其验证 |
| Delivery | `DELIVERY-COVERAGE` | 完成约定功能覆盖和回归矩阵 |
| Delivery | `DELIVERY-UNKNOWN` | 收束当前成果，明确保留未验证项 |

Goal, scope and delivery are separate dimensions. A reconstruction goal does not authorize target execution. A work-copy allowance does not authorize runtime/network/device access. An isolated runtime allowance does not authorize network, installation on a real device, persistent system changes or modification of the original. Bind every scope option to exact assets, allowed operations, environment, network profile, budget and cleanup/rollback conditions in `scope.md`; reuse the user's existing authorization. A scope change may restrict previous permissions as well as extend them. Device/network details must be explicit; never infer them from an ID.

## Copyable options

For a genuine result, target, authorization/effect or delivery choice, offer 2–5 short options in plain language with a recommendation and the material effect. Use A/B/C or 1/2/3 as local aliases to the displayed stable ID and complete text. The user may copy a whole option, its ID, or its displayed alias. Resolve aliases only against the latest unambiguous offered set for the same case/target; on stale or ambiguous input ask only the missing clarification. In that clarification, do not invent a new option set, repeat old scope/delivery menus or select a recommendation on the user's behalf; ask which existing decision the input refers to, then wait only on dependent work. A bare ID with no prior scoped option is a category, not permission.

Example when the requested output is undecided:

```text
A. GOAL-LOGIC：先解释这个程序的指定功能，给出证据和未知项。（推荐）
B. GOAL-RECONSTRUCT：证据足够后做指定功能的独立实现；未验证部分单独列出。
```

Example at a real runtime boundary (fill the brackets from the case before offering):

```text
A. SCOPE-ISOLATED-RUNTIME：允许在[隔离环境]运行[目标副本]，禁网，限时[预算]，结束后清理自有进程。（推荐）
B. SCOPE-STATIC-ONLY：继续只检查文件；需要运行才能确认的行为保持未知。
```

A file, credential or device identity that only the user possesses usually needs one concise input request. Do not fabricate delivery choices to disguise missing input. A single technical next step needs no option or permission round. Do not require a card when ordinary language already supplies a clear decision, and never use “继续” as the main interaction protocol.

## Internal choices and progress

The agent selects REA, providers, Static/Dynamic, unpack/dump/IAT, hooks, Java/native, subagents and verification methods within scope. These are never operator menus. Grilling is used only for an explicit interview request or an unresolved material goal/scope/product/delivery decision. Load its official instructions unchanged; facts come from analysis. Existing answers continue to apply. Spec Kit starts in the independent deliverable project after behavior Evidence handoff.

After a material result or blocker, report briefly in the user's language:

```text
本轮做了什么
目前确认了什么
目前还不知道什么
当前阻碍（如有）
下一步会做什么；仅有真实取舍时附可复制选项
```

Do not print the entire form after every command. Reports do not pause authorized work. If no in-scope route remains, state the limitation; a technical failure does not guarantee that a viable fallback exists.

## Recovery and completion

Store selected goal text, target identity, scope source, success criteria, stop conditions, phase and Evidence/unknown/blocker pointers in the existing case. Record a changed decision as `decision_delta` and carry unchanged sources via `carry_forward_refs`. Continuity can index these pointers; it is never a parallel task, permission or Evidence authority. Restore original sources and their current applicability before relying on memory.

For packed, dynamically loaded, anti-analysis or virtualized targets, use the adaptive transitions in `../reverse-engineering/references/re-agent-workflow.md`. A dump or decompilation does not establish source recovery. Use the L0–L6 definitions in `../reconstruction/SKILL.md` and differential evidence for the chosen scope.

For multi-component authorization/licensing/feature-gate work, follow `authorization-coverage.md`. A successful patch or one working feature never closes the aggregate goal. Report the actual counts, for example: “已验证 1/7 个授权面；其余 6 个尚未完成。” Failed regressions reopen affected rows. Unknown, blocked, unexamined or failed required surfaces prevent completion; a reduced delivery remains partial unless the user explicitly changes the requested scope.
