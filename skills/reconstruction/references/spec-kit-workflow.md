# Spec Kit 原生衔接 / Spec Kit workflow

Spec Kit MUST 使用官方包，本 skill 只指导用户成果项目的 constitution、原生规格与任务；MUST NOT 修改 Spec Kit 库、模板主体或另建 SDD 系统。宿主命令安装/注册、版本解析与配置归独立 installer。

## 项目与授权边界

成果项目 MUST 位于工具源码外。已有项目先恢复原 `.specify/` 与 `specs/<feature>/`，MUST NOT 对工具源码或既有配置盲跑 init。新项目只在已有授权涵盖写入且实际工具路径已核后，执行安装版官方 init；integration、script 等参数按当前官方帮助选择。本技能不硬编码宿主适配命令。

1. MUST 先修改项目 constitution：已有目标行为仅据 Evidence；无法查证的默认值、错误码、状态迁移标 unknown 并回分析。用户新设计单列 designed，不能冒充原版事实。授权、范围、保留我方 UI/品牌/特色与独立构建要求有原 scope/notes 引用。
2. MUST 实际执行项目生成的官方 `speckit.specify`，按安装版能力使用原模板与原生 FR/SC/US。MUST 提供 evidence-to-spec 追溯表及目标/环境/输入边界，不能让一般产品惯例补缺口。
3. MUST 执行 `speckit.clarify` 清理会影响实现/验收的歧义。未知事实回原专业 PRIMARY/REA；只有真正的产品/范围选择才交用户决策。
4. MUST 执行 `speckit.plan`，在实际生成的 plan/research/contracts 中引用原证据与边界。计划必须含两侧观察、冻结比较器、负例/状态、留出、错误变体及隔离独立运行；每项不支持的能力单列。
5. MUST 执行 `speckit.tasks`；沿原任务 ID/source-ref 将 FR、obligation、测试与实跑产物关联到原 case notes，不把任务进度复制进 JSON 清单。
6. MUST 显式执行 `speckit.analyze`，处理 spec/plan/tasks 的冲突、未覆盖需求及 constitution 违规后再 implement。官方默认 workflow 可能只含 specify/plan/tasks/implement/review，MUST NOT 假称它自动运行 analyze。
7. MUST 执行 `speckit.implement` 与成果项目真实构建/测试，保存输出与身份。规范符合但原版不符时回分析修 spec，不修改预期凑绿。
8. MUST 显式执行 `speckit.converge`；沿官方机制把遗漏以 source-ref 追加原 tasks，再实现、验证并重新收敛。Converged 只说明对规格的收敛，不能证明规格理解正确或与原版等价。
9. MUST 按 [差分验证](differential-validation.md) 实际跑原版/我方对照、REA 有限声明及隔离运行，分别给结果。将失败回原 tasks 或原分析，不另建待办库。

斜杠名称是官方工作内容的标识；宿主具体表现 MUST 以项目实际生成内容为准。代理 MUST 读取并执行其完整指令、产出文档/代码与真实回执，单纯输出 `/speckit.*` 文本不算执行。

## 追版与恢复

已冻结旧版 feature MUST 保留。追版用原 Spec Kit 机制生成后继 feature（例如 `specs/001-literal-v1/` → `specs/002-literal-v2/`），在新 spec/plan/tasks 与原 case notes/timeline 用项目相对路径互链。编号由项目机制选择，不建立独立版本注册表。FR 若跨 feature 同名 MUST 连同 feature 路径解释，不能只靠 FR-001 全局匹配。

MUST 将 O→N 证据变化和 C 的保留设计带入新 feature：范围内的新功能、原功能回归、UI 保留各有验收。需求语义变更必须提升原 reviewed obligation 版本；生成 obligation 按安装版机制更新，不能手改官方输出冒充 ready。源码/依赖、包、fixture、verifier 或环境变化后重做适用 proof。

恢复只读原 case authoritative 文件、feature 指针和 tasks 即可继续。原 timeline 每次只追加 `decision_delta` 与 `carry_forward_refs`；清单在本轮冻结时重建，不把旧清单当状态库、旧测试通过当新版通过。

## 可选的证据字段扩展

若安装版确需额外模板字段，MAY 用官方 preset 的 append 机制，在成果项目追加证据引用与 unknown 约束，保留原模板主体。MUST 先核官方版本实际支持的机制，不复制官方内部库或写宿主专属生成器。首版无需 preset 安装器即可把追溯写入原生文档。

## 来源与资格

文档/源码核对基线为官方 [Spec Kit v1.3.0](https://github.com/github/spec-kit/tree/v1.3.0)：[specify](https://github.com/github/spec-kit/blob/v1.3.0/templates/commands/specify.md)、[analyze](https://github.com/github/spec-kit/blob/v1.3.0/templates/commands/analyze.md)、[converge](https://github.com/github/spec-kit/blob/v1.3.0/templates/commands/converge.md)。这些是工作流依据；本目录测试不执行官方工具，也不证明安装版/宿主端到端可用。使用时 MUST 重新核安装版命令与模板。
