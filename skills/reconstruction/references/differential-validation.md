# 原版对照与独立交付 / Differential validation

这是一组用户成果项目的相称测试步骤，MUST NOT 实现第四个常驻平台。机械清单、Spec Kit 收敛、REA 有限声明、实际原版对照与隔离独立运行的结果 MUST 分开报告。

## 固定验证边界

1. MUST 由独立于实现的验证会话固定目标版本与摘要、我方 commit、受测打包产物摘要、精确构建/运行环境、输入、命令/操作、超时与真实输出位置。测试生产者 MUST 记录这些身份，不以命令文本代替运行回执。
2. MUST 在调参前冻结比较器源码/依赖、规范化规则、容差和留出清单的摘要。时间/随机/路径/浮点等差异只按既定规则处理；失败后 MUST NOT 临时过滤字段凑绿。规则、依赖或环境改变必须重新验证，旧输出只保留历史用途。
3. MUST 按输入族、会话或状态路径区分开发输入与未参与调参的留出输入。留出失败参与修复后转开发资料，最终换新留出；不能用近似复制输入冒充独立留出。
4. MUST 分别运行原版与我方实现并保留两侧原始输出、退出、文件/协议副作用。不能用我方算法生成原版预期，不能让同一 source 占两侧。追版原版侧 MUST 是 N，不能以 O 的旧通过回执替代。

## 相称的验证矩阵

| 目标 | 至少观察 | 反例 |
|------|----------|------|
| CLI/文件 | stdout/stderr、退出、内容与文件副作用 | malformed、边界、错误码变化、超时 |
| 协议/API | 原始消息、鉴权范围、状态迁移、取消/teardown（适用时） | 错序、拒绝、截断、错误响应 |
| GUI | 已约定业务/交互/视觉维度、焦点/持久化等适用状态 | UI 仍能打开但业务失败、我方设计被覆盖 |
| 打包/分发 | 包摘要、干净安装/路由/实际业务输出与回滚 | 开发目录能跑而发布包缺资源 |

MUST 故意引入一个错误码、输出或状态迁移变体，要求比较器确实报告失败。若变体仍通过，则验证器无效，不能报告原范围通过。

## 委派官方 REA 有限声明

MUST 核安装版工具和 schema，再按下列顺序调用；本目录脚本不做这些执行：

1. 规格冻结前调用 `build_reconstruction_obligation_ledger`，保留生成或 reviewed obligation 的 ID/version、所需 case kinds、authority、依赖/unknown。初始 open/unknown 如实保留。
2. 实际测试生产者计算 owner_sha256，写明哈希覆盖的确切文件/依赖和规范化方法，绑定唯一 module_path/symbol。original_cases 与 fixtures 覆盖 required_case_kinds 的 positive/negative/malformed 及适用 cancellation/teardown。真实执行产出符合安装版 schema 的 proof Evidence，带 owner、obligation_version、fixture/verifier/claim 身份与真实结果。
3. 交原版 ledger 重跑。交付范围 required obligations 必须 verified、required_open=0、ledger.status=ready，无矛盾/未知/过期 proof。blocked/out-of-scope 不计已验；范围决定不能为了清零静默缩小。官方 ledger 不会执行命令或重算 owner，这些必须由测试生产者完成。
4. 对支持的进程行为，分别 `capture_process_scenario` → `compare_process_captures` → `verify_reconstruction`。必须不同 source、非零声明且相应结果 pass。README 的进程通道为 Linux/macOS native PTY；Windows/其他不支持情况保留 unknown/unsupported，独立 harness 的验证单列。
5. 分发、干净安装、运行路由和跨 surface 依赖带真实包摘要与 proof 交 `evaluate_reconstruction_coverage`。选定 boundary 的必需 surface/claim 及其依赖必须覆盖，无失败/未知；字段以安装版为准，本 skill 不重算传递 closure。
6. 实际端到端 MUST 用错误变体、摘要失配、过期 obligation 版本、缺原版 case、同源两侧作拒绝反例。不得把清单 unittest 当这些原生反例已跑。

官方契约及 README 入口见 [evidence-to-spec](evidence-to-spec.md)。MUST NOT 调用开发 readiness evaluator 代替生产接口，MUST NOT 自写通过字段或 semantic ID。

## 独立运行验收

MUST 先核用户机器实际可用 VM/容器环境、平台与身份；不自动启用系统虚拟化或安装宿主驱动。将独立源码、锁文件与规定资源复制到一次性环境，只开放这些成果与官方构建/运行依赖，原目标及分析/宿主工作目录不开放。

MUST 实际检查共享、挂载、可见路径与指回原件的链接，并运行干净构建、安装、业务与回滚测试。仅创建新目录、审查 import 或启动新进程只能作为辅助，不能证明原件不可访问。有环境缺口则本项保持未验证；不得声称已经独立交付。

## 失效和结果处理

| 变化/失败 | 必须动作 |
|-----------|----------|
| 需求或 spec 行为变更 | 更新原 obligation 版本，重做受影响 proof |
| 源码/依赖/产物改变 | 重算 owner/包摘要，重做受影响 proof |
| 测试/比较器/判据/环境改变 | 冻结新身份，重做适用两侧观察与验证 |
| 实现与 spec 不符 | 回原 tasks 修实现 |
| 实现符合 spec 但原版不符 | 回原专业分析重查 spec，保留新 unknown |
| 超时/截断/未运行/缺设备 | 标 unknown/未验证，保留原始失败 |

最终报告 MUST 分别给规格符合、声明范围行为对照、独立运行三项结果，并列边界、版本、排除、unknown 和真实产物引用。退出 0、HTTP 200、GUI 能打开、可反编译、Converged 或清单 PASS 都不能代替它们。
