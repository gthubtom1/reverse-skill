# 专家角色 → Skill 映射（无多 Agent 服务器）

> 本文件约束现有 `route → PRIMARY → case → bounded work item → Evidence` 链，不创建第二 router、case 或状态账本。

## P0 多代理编排边界

- **Pi 主代理 / lead 是唯一最终权威**：它负责并最终决定 `route`、`scope`、`case`、`timeline`、`workitem` 以及 Evidence 的创建、修改、晋级、阻断和结论。Worker 的输出在主代理明确接收前都只是候选结果。
- **reverse-operator / cre 是 bounded executor**：只能执行 handoff 指定的一个问题、阶段、动作、写入范围和预算；不能改 route、scope 或 case 边界，也不能自行宣布 Evidence/Finding/Path 已完成。
- **reverse-reviewer 是 read-only**：只审查现有 scope、handoff、产物和 Evidence 引用；不得对目标执行动作、修改源文件、case 权威文件或 Evidence ledger。审查结果返回主代理，由主代理决定是否接收。
- **planner / scout 只有 advisory 权限**：可以提出拆分、线索和风险提示，但不能执行目标动作、分配新的 Worker、改变范围或创建账本。
- **实现型 Worker 只能在行为 Evidence handoff 被主代理接收后进入 `reconstruction/`**。没有目标身份、已观察行为、成功标准和未决 unknowns 的 Evidence handoff，不得开始独立实现或复刻。
- 任何 handoff 都必须携带：现有 `case_id`（仅 pre-case 只读规划/维护可写 `n/a` 并说明原因）、目标 identity 与 hash（或明确说明缺失原因）、`carry_forward_refs`、current phase、一个 Evidence question、allowed actions、write scope、budget、cleanup 和 acceptance。涉及目标动作时必须引用并读取现有 scope/授权；字段或引用缺失时阻断并退回主代理补齐，不创建假 case，也不由 Worker 猜测。
- 子代理不得递归委派、创建第二 router、case、timeline、workitem 或 Evidence ledger；未改变的权威状态通过原文件/条目引用传递。
- **仅 R46 选定 implement task 的窄后端例外**：lead MAY 明确授权一个确定性执行后端持有一个指定 Builder 编码 session，替代本批 implementation-worker，而不是在 Worker 下继续派 Worker。必须先满足 [execution-backend](../reconstruction/references/execution-backend.md) version 1 的接收、单写租约、总预算与退出门；Builder 禁止委派，不增控制 LLM，同批不再派宿主编码 Worker。普通 Worker 的 no-recursive 不变；改称工具不能自动取得例外。
- 同一目标的重型 provider 必须串行。timeout 或 provider failure 后，先取消并验证 cleanup，再记录失败并切换 provider；cleanup 未确认时不得启动替代 provider。

## 角色表

| Code | 名称（可本地化） | 职责 | PRIMARY / 工具 skill |
|------|------------------|------|----------------------|
| **lead** | Pi Lead / 主代理 | 拆任务、定 scope、阶段门控、汇总报告；是 route、scope、case、timeline、workitem 和 Evidence 的唯一最终权威 | `attack-chain/` 或当前 PRIMARY hub；结束 → `docs-generator/` |
| **reverse-operator** | Reverse Operator / 逆向执行 Worker | `cre` 的 bounded executor 标签；按 handoff 做有限逆向动作，只能在明确 write scope 内产出原始结果 | 由当前 PRIMARY 指定的逆向 skill |
| **reverse-reviewer** | Reverse Reviewer / 逆向审查 Worker | 只读核对 handoff、Evidence、产物、unknowns 和 acceptance；不执行目标动作、不写权威状态 | `case-review/` 或对应只读审查路径 |
| **planner / scout** | Planner / Scout / 规划与侦察顾问 | 只提供 advisory 计划、线索和拆分建议；不拥有 scope、route、case 或 Evidence 决策权 | 由 lead 指定；不得自行路由 |
| **implementation-worker** | Implementation Worker / 实现 Worker | 仅接收主代理已接收的行为 Evidence handoff 后进入 `reconstruction/`；实现范围受 handoff 的 acceptance 与 write scope 限制；选定任务 MAY 由获授权确定性后端内的唯一 Builder 承担，不取得 Spec tasks 或 Evidence 接收权 | `reconstruction/`；按需 execution-backend |
| **cie** | 情报收集 | 资产发现、暴露面、关系 | `pentest-tools/`（recon）；浏览器 → `browser-automation/`；云面 → `cloud-k8s/` |
| **cpe** | 渗透验证 | 扫描、利用验证、影响确认 | `pentest-tools/`；API → `api-security/`；AD → `windows-ad/`；无线 → `wifi-wireless/`；库 → `database-security/`；SSO → `identity-federation/`；OT → `ot-ics/` |
| **cre** | 逆向分析 | 作为 bounded reverse executor 执行二进制/固件/移动/前端逻辑分析；结果须经 lead 接收后才进入下一阶段 | `ida-reverse/` `ghidra-reverse/` `binary-ninja-reverse/` `radare2/` `apk-reverse/` `mobile-reverse/` `macos-reverse/` `js-reverse/` `browser-extension-reverse/` `dotnet-reverse/` `go-rust-reverse/` `firmware-pentest/` `hardware-security/` `malware-analysis/` `protocol-reverse/` `thick-client/` `reverse-engineering/` |
| **cae** | 代码审计 | 源码/依赖/供应链 | `code-audit/` + `supply-chain-security/` |
| **cbe** | 蓝队/取证 | 狩猎、检测、IR 伪影 | `threat-hunting/` `digital-forensics/` |
| **cce** | 密码学 | 算法/协议/密钥误用 | `reverse-engineering` 模式文档 |
| **llm** | AI 安全 | Prompt/Agent | `llm-security/` |
| **doc** | 文档官 | 报告/writeup/图 | `docs-generator/` + `diagram-generator/` |

## Lead 强制协议

```text
1. 输出 PRIMARY（master-route）+ lead_role=lead
2. 写 scope.md（ops/scope-contract）
3. 指定 specialist_roles[] 与 handoff 条件
4. 每阶段结束：更新 timeline + workitems；决定继续/换角色/出报告
5. 禁止跳过 scope 直接 cpe 扫生产
```

## 交接（Handoff）规则

| 从 → 到 | 触发 | 交付物 |
|---------|------|--------|
| lead → cie | 需要资产面 | scope + 已知域名/IP |
| cie → cpe | 有存活面/服务 | assets 列表 + 端口/URL |
| cpe → cre | 需逆向校验/客户端逻辑 | 样本路径 + 可疑点 |
| cre → cpe | 还原出协议/密钥/校验 | 算法说明 + 复现命令 |
| any → doc | 阶段或任务完成 | Evidence/Finding/Path 草稿 |
| any → lead | 阻塞/越权/换路径 | timeline 备注 + blocked 原因 |

## 单人 Agent 怎么用（特色）

不必真起 6 个 Agent：

```text
同一会话内：
  [lead] 规划
  [cie] 执行侦察 skill
  [cpe] 切换 pentest-tools
  …
输出时用角色前缀标签，方便 timeline 检索：
  [cpe] nuclei high findings → E-003
```

## 与 master-route 关系

- `master-route` 定 **PRIMARY skill**  
- `role-map` 定 **谁在当前阶段负责**（可写在 scope.md）  
- 多阶段任务 PRIMARY 常为 `attack-chain/`，由 lead 再分发  

## MUST NOT

- 不要假设存在 Z3r0 会话 API  
- 不要为角色启动未授权目标的额外扫描  
