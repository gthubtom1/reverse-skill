# R46 选定任务的执行后端 / Execution backend

工作流合同版本：**1**。本文件是 reverse 领域合同，不是新 PRIMARY、Craft 原生 schema、命令或安装回执。仅在 R46 的 implement runner 已选定任务后按需读取；`route → PRIMARY → case/scope → bounded work item → Evidence → lead` 仍是实际主线。`initial` 先接收行为 Evidence 并形成官方 Spec 意图/tasks；`validate` 可直接独立验证；`update` 先由 R15 固定 O/C/N 和后继 feature，不强制经过 Craft。

## 安装与接口资格

源码接口实现、发行 bundle、安装事务与当前宿主加载是四项不同事实，MUST 分别取证。先按实际 installer receipt 定位资源，核兼容的 reverse 合同/文件摘要、bundle reader 与 entry check，再由对应 owner/driver、Spec runner 和独立 verifier 的真实测试判定本批运行资格。缺真实 receipt、资源未安装或安装身份/摘要不兼容时记 `not-yet-installed`（不兼容须修复）；资源可读但不支持本批必需协议/能力时返回 `unsupported`。文档、源码文件或安装 hash 通过均不事先认证活动可用；可继续现有 implementation-worker 路径。

| 文件/资源 | 本合同可确认的状态与读取规则 |
|---|---|
| `skills/ops/role-map.md`、本 skill、`spec-kit-workflow.md`、本文件 | 本维护源已定义窄例外与领域合同；不表示活动安装已更新 |
| installer `adapters/craft-pi/` 或 `adapters/craft-codex/` 下的 execution Skill 与 reference | 按实际宿主及 receipt 定位；Pi 与 Codex 共享本领域流程，各自使用已安装的驱动与权限合同，不把源码路径当安装根 |
| installer 分发的 builder instructions、Craft 执行器、宿主 bridge 与 policy 工件 | 核真实版本、摘要、version 1 reader 与本批所需能力；是否已发包、安装、当前 host 加载分别记录，不从文件存在或包名推断 |
| 成果项目的 research/baseline/check/result/owner 工件 | 每次运行的真实输入输出；本仓库不提供假运行回执 |

本合同 version 1 与后端实际序列化版本必须分别核对。Craft 源码接口 `crates/engine/src/execution_policy.rs` 定义 `CONTRACT_VERSION = 1`，输入是 `AcceptedResearch.version = 1` 与 `ExternalBaseline.version = 1`，不是设计稿的 `proposed.accepted-research.v1` 名称，也不是一个通用 `contract_version` 字段。具体 wire schema 以实际 reader 为准；本文件不扩原 handoff schema。

| 源码接口依据（非安装回执） | version 1 语义与需按所选 bundle 核验的边界 |
|---|---|
| `AcceptedResearch` / `Identity` / `Original` | `identity` 持 case/scope/workitem/feature/acceptance 的 HashedRef 与 task_ids；`original` 持 target/target_identity、bundle 与行为引用；哈希验证不替代 lead 接收与授权审查 |
| `ExternalBaseline` / `PlannedCheck` | baseline 固定 bundle SHA 和带来源/损失的 artifacts；check_plan_ref 与 checks 对照。当前 check 类型有明确支持集合，不能从通用场景说明推断全部平台可执行 |
| `ModelPermission` / `ModelIdentity` | `model.expected` 为 provider/model/effort；Pi 使用 `pi-rpc-bounded-v1`，Codex 使用 `codex-dynamic-bounded-v1`。适配层明确映射各宿主的模型状态并拒绝未授权切换；不从 agent 名或启动参数推断实际消息来源 |
| `AcceptedResearch::preflight` / `revalidate_inputs` | 提供启动前与后续输入重核；source_base_sha256 是起始基准，执行后源码应记录 diff。task 语义、全部 Spec 前置与 proof 接收仍属原 runner/lead |
| `crates/ai/src/rebuild/policy.rs` 的 `PolicyRuntime` / `SourceLease` | 显式 runtime 注入与 cooperative lease 接缝；声明能力不等于 live 验证，锁文件不是 OS 权限或进程树清理证据。预算按下述能力门选择，退出接收仍须 owner 落实 |
| bridge `src/config.rs` 的 `Config` | 已有模型/目录、取消身份与 deadlines 输入；这是逐消息 driver 配置，不是完整 accepted research 或端到端执行 owner |

以上是源码接口依据，不替代所选 bundle 的协议与能力回执。宿主具体启动/恢复/权限调用归 installer reference；接口不一致或本批必需能力缺失则阻断该后端，不能忽略字段、降级到 Plain 或改 schema 版本强读。

新项目到运行的准备入口、`executor --prepare` 参数及 typed `return_summary` 均 MUST 以实际 bundle entry-protocol、capability inspect 和 owner 已验收 schema/gate 为准；本文件不据开发进度宣称其已接受。缺 prepare 能力时返回 `unsupported`，沿现有 Worker；不能拿 NativeNotes 测试夹具当通用输入生成器，不能手填假引用跨过准备门。接通后 runner 仍须真实执行项目 Spec 前置、所选任务、返回接收、converge 和独立验证，不以某一步入口成功代替成品验收。

Craft 保持逐批由原 runner 选择。用户已为当前复刻任务选择 Craft 时，runner 可沿用该决定，为依赖已满足且通过能力门的任务批次选择已安装后端，无需重复询问。安装组件本身不授权业务任务；缺失的本批能力不得由默认许可补齐。收益比较、真实模型运行和业务验收分别保留实际证据，不把离线协议检查称为成品通过。

### Pi 与 Codex 接续同一实现流程

| 宿主 | 原 runner 选择的执行后端 | 权限与取消边界 |
|---|---|---|
| Pi | `craft-pi-rpc-v1` | `pi-rpc-bounded-v1`；受控 MCP、Pi RPC 状态与取消、owned 进程清理 |
| Codex | `craft-codex-app-server-v1` | `codex-dynamic-bounded-v1`；无原生环境访问的 Builder thread、只由受控工具代理行使权限、Codex 原生中断与 owned 进程清理 |

两者均执行 `accepted research → validate/prepare → 一个 Builder → build/check/refine → typed result → 原 runner/lead 接收 → converge/独立验证`。Codex 不启动 Pi 编码者，也不调用上游独立 `rebuild_start` 来覆盖当前任务。REA 及上游 Craft 的分析工具由原 PRIMARY 按问题使用；其工具目录与执行后端的权限目录分别验证。

原 implement runner 从活动 receipt 的 `craft` 定位 entry/resources，按对应 reference 完成 entry check、验证与准备后执行 prepared input。任务、lead 决定、源基准、driver、instructions、模型 profile 和 checks 全部绑定原始引用；没有 accepted decision 时不能运行。只读 `--validate`、零模型的 `--prepare` 与实际 Builder 执行必须分别记录；包安装后可调用真实执行入口，不预先宣称任意业务目标已验收。

Codex 的已选版本不支持强制单响应或总 token/费用硬上限时，能力声明必须明确这些限制。只有 lead 为本批明确接受具有已验 wall/refine 硬界及实际 usage 审计的 `budget-audit`，才可使用此 profile；本批另要求单响应或总量硬上限时返回 `unsupported`，不得伪造 `maxTokens` 或把事后统计称为硬上限。其他宿主不继承任一 profile 的资格。

## 静态能力声明 / Capability descriptor

Pi 包根固定路径为 `skills/reconstruction/references/execution-backend-contract.json`，见 [Pi 机读声明](execution-backend-contract.json)。Codex 使用 [Codex 机读声明](execution-backend-codex-contract.json)，固定 `contract_id` 为 `reverse.r46.codex-execution-backend`，将下表的 Pi Builder capability 替换为 `r46.bounded-codex-builder-v1`；其他字段和四个 required files 的检查规则相同。installer 按真实宿主选择并分别冻结声明身份，不把旧 Pi 声明当成 Codex 支持证明。它们只声明本维护源具有本节定义的 workflow 合同及指定文件的完整性，不是第二 router、任务授权、真实 Evidence、运行时接通或 OS policy 证明；不替代前述安装/运行资格门。

schema version 1 的顶层恰为 `schema_version`（整数 1）、`contract_id`（固定 `reverse.r46.execution-backend`）、`contract_version`（整数 1）、`min_reverse_version`（SemVer `1.9.0`）、`capabilities`（下列四个唯一字符串）、`required_files`（下列四条唯一文件引用）。`min_reverse_version` 是首次支持此受控执行合同的最低版本，不随未来每次发行改写；1.9.0 是该合同首次支持版本；源码版本、公开发布与活动安装分别核对真实 tag/receipt。installer MUST 同时核版本、固定 ID/version、必需能力与文件摘要，不能仅用组件名或 semver 放行。

| 固定 capability ID | 合同含义 |
|---|---|
| `r46.accepted-research-v1` | 原 case/scope/task、lead 已接收研究与冻结 baseline/check/model/budget 引用；不重新 Study 或猜测关闭 unknown |
| `r46.single-implementation-owner-v1` | 本批只选一个编码后端，完整 Spec implement/converge 与 tasks owner、writer lease 和停止/cleanup 门保留 |
| `r46.bounded-pi-builder-v1` | lead 明确选择的确定性 backend 内只持一个 Pi Builder，无额外控制 LLM；普通 Worker 禁递归不放宽 |
| `r46.candidate-independent-acceptance-v1` | Ready/TurnDone 只作 candidate；原 lead/runner 接收与独立验证、proof 失效边界不被替代 |

`required_files` 每项恰为 `path` 与 `sha256`，路径相对 reverse 包根，SHA-256 固定文件原始字节、小写 64 位 hex；四条路径为 `skills/reconstruction/references/execution-backend.md`、`skills/reconstruction/SKILL.md`、`skills/ops/role-map.md`、`skills/reconstruction/references/spec-kit-workflow.md`。不含声明自身或自 hash。文件修改后须先复核合同再生成摘要，不能自动刷新摘要掩盖漂移。

installer 的 plan/apply/verify/entry 各自消费该固定声明并严格检查版本/字段、能力唯一且完整、上述静态路径与真实根、文件存在和摘要；未知 schema/contract version、重复/缺失/畸形项、路径遍历/链接越根、缺 hash 或摘要不符均拒绝。该消费逻辑由 installer 实现，本 reverse 仓库不另建通用 checker CLI。声明本身的 SHA256 和完整本地 source identity 由外层冻结，文件自报摘要不能认证恶意替换或来源；本地验证用显式 `--reverse-root` 与冻结 local tree 身份，不虚构远端 tag 或提前改变公共 pin。

## 接收输入：引用原权威材料

lead 仅接收本批所需研究范围，MUST 有明确 acceptance 引用；handoff checker 的 `PASS/machine_check_only` 不是 acceptedResearch，也不授权 ACT。沿用 [原 handoff](handoff-manifest.md)，不扩它的状态 schema、不新建研究/任务数据库。所选后端的 version 1 输入必须能绑定并在启动前核验以下事实：

| 输入 | version 1 必须承诺的身份与边界 |
|---|---|
| 原链 | 当前 case、原 scope 与授权/摘要、workitem、carry-forward refs、lead 接收决定；只读维护不得伪造 case 来启后端 |
| 原目标与研究 | 原 target 路径/URL、版本/hash 或 capture 身份；原样 REA bundle/artifact 的引用与确切 SHA、原 Evidence/obligation IDs；FR/场景、环境、限制及 observed/inferred/unknown/designed 资格 |
| Spec 与任务 | 同一 feature 的 spec/plan/tasks 版本与摘要、selected task IDs、依赖已满足的依据、成功标准、原 runner/记录 owner；不能拿旧 feature 或自由文本替代 tasks |
| 源码与外部基线 | 成果根的起始源码 manifest/hash、只读 external baseline/index 及转换器/参数/输出 hash、字段映射/损失；原 target 与 baseline 根分别固定 |
| 检查 | check plan 的版本/摘要、required/optional IDs、实现/插件身份、参数、场景/baseline 版本、依赖与实际允许 build/test 命令及 cwd；所有轮次共享该计划 |
| 后端与模型 | 实际 backend/policy/driver 与对应宿主 pin/权限能力；明确 provider/model/effort，核原生状态与未授权切换；不默认继承、不静默 fallback，不把 agent 名当模型 |
| 预算与租约 | 一个 live execution owner、run 身份及取消控制引用；成果根/feature/task 单写 writer lease、写路径/工具/命令权限；统一总预算、deadline、重试/轮次与停止条件 |

预算覆盖协调、Builder、checks/refine、工具/资产与重试，记录同一批次的墙钟、token/费用、进程与工件消费。当前总 token/费用硬上限未落实，不能据 wall/refine/per-response 边界宣称已具备该能力；请求 `strict-aggregate-cap` 时，MUST 有真实总 token/费用硬上限能力及拒绝/耗尽测试，无此强制能力则 `unsupported`，不得接受该请求或声明整体合格。仅当 lead 明确为本批选择 `budget-audit` 模式，才 MAY 使用对应宿主已验证的 wall/refine 硬界与 usage audit；Pi 的已验单响应限制与 Codex 的不支持项分别记录，不能互相借用资格。记录各实际限制、汇总消费和未强制的总量，不把审计称为 aggregate hard cap。预算模式名称表达要求，具体 wire 字段由实际 owner schema 定义。

路径 MUST 规范化并检查 symlink/junction 的实际根与权限，不能只比较字符串前缀。原始输入只读；baseline 缺值保留缺失，不用空数组或 placeholder 通过检查。REA export 原字节/ID 保留，external sidecar 记录来源、operation/provider/environment/authority/limitations 和派生损失，不伪装 Craft capture、native Evidence 或 controlled replay。

预检 MUST 早于模型 session、Extractor、Study、transcript/notes 清理；入队和实际出队启动均重核摘要、租约、任务与权限。无法核验输入或 required check 缺资料，返回具体受影响 task/check 与 `needs-evidence`（缺研究）或结构化输入/权限错误，不能创建空 capture/session。任务租约丢失、源基准漂移或旧 owner 无法确认退出时不抢占写权。

## 加壳目标与派生材料

原始加壳 binary 的 identity/hash 永久保留。脱壳 dump、脱混淆/伪代码及运行时 UI/协议观察作为 derived refs，记录原对象、operation、environment、hash 和 limitations。先由原链接收明确的 behavior contract，再准备实现；静态壳内不可见的 unknown 不猜成 observed，也不要求 Craft 亲自脱壳。缺事实以 needs-evidence 回原 PRIMARY/REA，在 scope 内补证、冻结新 baseline，确认旧写者退出后串行 prepare/run。validate 可直接独立验证；update 仍先 R15 固定 O/C/N，不默认所有目标都能 1:1 复刻。

## 一个编码写者与完整 Spec owner

lead MAY 为本批明确选择确定性 Craft backend，持有一个指定宿主 Builder 编码 session，替代本应派发的 implementation-worker。该窄例外不允许普通 Worker 递归：Builder 不派 Agent/crew/其他编码者；bridge/driver 是程序，不新增 LLM controller/profile，也不同时运行宿主编码 Worker。同一 feature/task/成果根只有一个写者。会话失败或模型变化后可串行新建，但须先确认旧写者退出、重核合同与基准；不得双开活 session 历史。

- Builder 只写授权成果代码与运行冻结命令。后端受限工具代表同一 writer lease 行使写权，不产生第二个写者。
- Spec implement runner 按 [完整官方流程](spec-kit-workflow.md) 负责 prerequisites/checklists/hooks、依赖、同文件串行、测试/阶段验证、任务更新与最终完成检查。后端不改 spec/plan/tasks、验收预期，不勾任务；失败/未验证任务不得勾 `[X]`。
- bridge/owner 只管理授权运行工件、队列、租约、预算、进程与结果转换。lead 保留 route/scope/case/Evidence 接收和晋级权；指定记录者按 lead 接收 delta 写原 timeline/workitems，不能由 Craft 双写原账本。
- 批次结束后 runner 继续剩余任务，单独执行官方 converge，只追加 source-ref 缺项再回 implement；独立 verifier 留在原链，分别验证规格、有限原版行为与隔离独立运行。

## 无补研究、候选与失败回流

Craft 在所选任务内只 build/run/check/有限 refine。专用 policy MUST 禁止框架 Study、Extractor、Deep 强制补查及恢复/notes/round-0 暗中重研究；实际 call gate 还须拒绝研究/设置/安装、原 target 读取/执行、unknown 修改、嵌套 rebuild 和未授权工具/命令。提示、工具 gate 与 OS 隔离分别验证；允许工程脚本不等于抗恶意代码的沙箱。

原 target 身份保留，不能改 None、造 capture/session、伪造 decompiled 位或重命名 REA IDs 来避 Study。缺原版事实输出 `needs-evidence` 给原 PRIMARY/REA，保留原 unknown 引用；Builder 的估计、笔记、Ready 或本地 `resolved` 不关闭原未知。原链接收新证据后才能修订研究，且只暂停依赖缺项的任务。构建/测试失败才可在预算内 refine；`needs-spec` 回 Spec runner/lead 修正规格与任务，`needs-scope` 回 lead 处理真实授权/影响边界，权限不支持返回 unsupported；这些标签不自动扩权，不能混成无限重试。

结果是原 case notes 下的运行工件，引用原 task，MUST 保留原 Craft Ready/Finished/error/TurnDone、逐检查与逐场景执行输出、失败/skipped/unsupported/needs-evidence、unknown、实际 diff/产物 hash、模型与预算、进程和 cleanup 证据。`applies=false` 要有 not-applicable 依据，不能静默删除 required check；全 skipped、零 claims、旧轮结果、exit 0 或 TurnDone 不算通过。required unknown 或 required check 未执行/失败/unsupported 时，该受影响任务不得成为合格 candidate，MUST 返回具体阻断/needs-evidence；保存候选残片不等于 candidate 资格。外层 candidate 不是 Craft manifest 的新状态，更不是 accepted。

原 runner 核任务、源码基准、diff、实际 checks 和清理后才接收候选结果并更新 tasks；lead 与独立验证者保留原接收职责。Ready 可带 open questions，不能提升 Evidence/ledger 或关闭 case；REA 有限声明仍须真实原生生产链与官方 schema，独立 harness 不能冒充其 closure。

## 变更、停止与 proof 失效

运行中 task/feature、scope、accepted research、baseline、source base、policy/backend、check plan 或模型/provider/thinking 身份变化，MUST 停止接单与新动作，通知当前 owner 取消并等待退出，保留半改源码/历史/失败事实，再由原 owner 接收新版交接、重核基准和租约后串行重启。预期任务内的代码修改记录为候选 diff；未授权外部改动属于基准漂移，不可刷新 hash 掩盖。新增 note 不得代替版本化 baseline 或扩大 scope。

取消、超时与预算耗尽同样走原 owner：停派生动作 → 经专用控制通道清队列/协作 abort → 有界 drain/idle/退出 → 必要时仅硬停可证明归属的进程树 → 核 owned Builder/helper/build/preview、端口与写入确实停止。具体 driver 协议归 installer reference；Craft stop/Drop、Stopping 或根 PID 退出都不是完整 cleanup 回执。无法确认时记 `blocked-cleanup`，阻止该成果根的替代写者/provider，不影响无关任务，不按进程名盲杀。

相关需求/obligation、源码/依赖、fixture/verifier、环境、基线或 check plan 变化后，旧 proof/checks MUST 按适用性失效并重跑，保留原证据用于追溯。重新接收不能沿用过期通过，也不改预期凑绿；清理成功不代表业务副作用已回滚，业务恢复需独立验证。

回退同样先停接单、取消并确认所有 writer/preview 退出，锁成果根并保留当前材料，再分别核三层：①代码/包层选择已验兼容旧组件，不 reset 用户成果；②运行数据与用户业务数据层按 reader 相容性或迁移前完整副本恢复，保留候选后改，业务补偿另验；③安装层仅按 journal 条件恢复受管资源/注册，用户后改冲突保留，receipt 最后恢复。三层一致后 reload/新会话核实际加载及业务恢复再接单；卸载/恢复注册不回滚已接受代码或用户数据。
