# Evidence 到原生规格 / Evidence to spec

本步骤 MUST 复用 [Evidence→Finding→Path](../../ops/evidence-finding-path.md)、[timeline/workitems](../../ops/timeline-workitem.md) 与原 [case-review](../../case-review/SKILL.md)。这些 Markdown 是分析权威，Spec Kit 是规格/任务权威，REA bundle/ledger 是原工具的证据与有限声明权威。交接 JSON 仅为可丢弃并重新生成的指针清单。

## 可执行交接

1. MUST 在用户成果项目恢复原 scope/case，固定目标/样本来源、版本、摘要、运行环境。检查 scope 是否涵盖本轮目标和活动；原授权不因阶段切换扩大。
2. MUST 用实际安装版 REA `export_evidence_bundle` 导出完整文件，原样归档到原 case 的 evidence。MUST 固定文件 SHA，并用原 `append-evidence` 契约创建新 E 条目引用它。会话 ID、摘要视图、聊天摘录不能替代完整导出。MUST 保留 evidence_id、provider/environment、authority、limitations 和 unknowns；不得手工伪造 ID 或调整资格。
3. MUST 在 spec/notes 建 FR→Finding（如有）→E→bundle 原 evidence_id→行为边界→测试的引用表。来源列 MUST 区分观察、推断、未知、用户新增设计。每项 FR 映射到原生生成或 reviewed obligation 的原输出引用，保留 ID/version、required_case_kinds、authority、依赖与 unknown；清单仅保存 JSON pointer，不存第二份 obligation 状态。
4. MUST 在原 workitems 给每个缺件或关键 unknown 一个补证据工作项，引用原 unknown；只有受影响需求阻断。其余独立 feature 可继续。MUST NOT 为了过检查删除 unknown、将 candidate/inferred 升格 observed 或让 Spec Kit 自动补默认值。
5. MUST 用原 case-review `--verify-hashes --strict` 审原 case 图，再以 [handoff-manifest](handoff-manifest.md) 指针检查路径、摘要与引用。脚本不读取/执行 repro_command、verifier 或任何目标。
6. MUST 由独立审阅者逐项核“原文是否支持行为、来源是否够资格、是否遗漏 unknown”，必要时再询问原版并委派 REA 有限 claim。机械通过后仍不满足语义交接条件时 MUST 回原专业分析；保留 spec 中的不确定标注。
7. 交接成立后 MUST 在原 timeline 追加本次决定与原文件引用，在 notes 链接对应 feature；不重跑 case-init，不展开未变授权和路由。规格/任务后续变更继续在原生 feature 机制留痕。

追溯表 MAY 使用以下结构，具体内容 MUST 来自实际材料：

| 原生 FR | 来源资格 | 原 Finding/Evidence/bundle 引用 | obligation 输出引用 | 测试及实际两侧输出 |
|---------|----------|-------------------------------|---------------------|--------------------|
| FR-001 | observed/inferred/unknown/designed | 项目内相对路径与原 ID | 原输出文件 + JSON pointer | 原生测试 ID/回执 |

## REA 生产接口与依据

已核对的文档基线为官方源码 `a1660bc016cfe9f0b5fa15ee4192876ee9e82da4`，这是接口研究依据，MUST NOT 冒充当前机器安装版或固定未来版本。实际调用前 MUST 核官方稳定安装版本、`binary_session` 中 catalog 身份与实际 `tools/list`；精确输入/输出以该安装版 schema 为准。缺接口/平台能力保持未验证，不降级到开发 evaluator。

官方 [README](https://github.com/morluto/rea/blob/a1660bc016cfe9f0b5fa15ee4192876ee9e82da4/README.md) 的 Documentation 指向 [MCP contracts](https://github.com/morluto/rea/blob/a1660bc016cfe9f0b5fa15ee4192876ee9e82da4/docs/mcp-contracts.md)、[CLI and Evidence](https://github.com/morluto/rea/blob/a1660bc016cfe9f0b5fa15ee4192876ee9e82da4/docs/cli.md)，并在目标表说明 process capture 需要 Linux/macOS native PTY。README 的 generated catalog 是生成入口，非仓库内已提交的完整 schema 快照；运行服务器才是可用性依据。

| 生产接口 | 原生用途 | 本 skill 的边界 |
|----------|----------|-----------------|
| `export_evidence_bundle` | 完整原生 Evidence 导出 | 只归档原件、SHA 与 E 引用，不重写 records |
| `inspect_evidence_bundle` / 安装版支持的读取接口 | 读回导出材料 | MUST 先核 schema；不能用旧进程会话 ID 代替 |
| `build_reconstruction_obligation_ledger` | 候选/reviewed obligation、绑定及有限 closure | 先建初始 ledger，再交真实 proof 重跑；本脚本不复算 |
| `capture_process_scenario` | 支持平台的真实进程观察 | 两侧分别运行且 source 不同；Windows 缺通道标 unsupported |
| `compare_process_captures`、`verify_reconstruction` | 原生比较与非零有限声明核对 | 保留 pass/fail/unknown、矛盾和适用范围 |
| `evaluate_reconstruction_coverage` | 选定 boundary 的 surface/claim/依赖及 package proof | 引用官方结果，不在本地另建 closure 引擎 |

生产 ledger 的确切契约见 [reconstruction obligation ledgers](https://github.com/morluto/rea/blob/a1660bc016cfe9f0b5fa15ee4192876ee9e82da4/docs/reconstruction-obligation-ledgers.md)，coverage 见 [reconstruction coverage](https://github.com/morluto/rea/blob/a1660bc016cfe9f0b5fa15ee4192876ee9e82da4/docs/reconstruction-coverage.md)，过程观察见 [process capture](https://github.com/morluto/rea/blob/a1660bc016cfe9f0b5fa15ee4192876ee9e82da4/docs/process-capture.md)。

Ledger MUST 由真实原 Evidence 和 reviewed 输入生成。其本身不读 module_path、不执行 verifier.command、不计算 owner_sha256。MUST 由真实测试生产者计算精确源码/依赖/规范化输入的 owner commitment，绑定唯一 module_path/symbol、obligation_version、fixture 与 verifier 身份；将真实输出形成安装版 schema 接受的原生 proof Evidence，再交官方 ledger。MUST NOT 手填通过字段或虚构 semantic ID。初始 open/unknown 不代表错误；最终 required_open=0、required obligations verified、ledger.status=ready 才可声明对应范围的 readiness。blocked/out-of-scope 不计 verified，范围变更 MUST 有明确决定。

MUST NOT 调用 `scripts/verify-reconstruction-readiness.mjs` 或测试目录 evaluator 冒充生产 API，也不得注册不存在的 readiness 工具。本 skill 的 Python 不导入 REA 库，不认证 Evidence，不验证 authority，不计算 closure。

## 必须保留的错引反例

合成例中原观察写“空输入返回 2”，错误 spec 写“空输入返回 0”。即使文件在、SHA 正确、E-id 与 FR/obligation 指针全部齐全，`check_handoff.py` 仍可能 PASS，并明确 `semantic_verification=not_performed`。这正是机械边界。独立审阅 MUST 对照原文或再次实跑原版拒绝该规格，将受影响 FR 退回分析并保留 unknown；不得调整规范化规则掩盖差异。对应 unittest 只证明本脚本不冒称检出了语义错引；它不是一次真实 REA 语义验收。
