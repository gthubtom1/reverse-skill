# 全领域基线覆盖表 / Domain Coverage Baseline

本表是 reverse-skill 的维护视图，不是第二套路由器。真实路由仍只读 `skills/config/routing.json`；本表只记录入口、参考资料库存和当前审查边界。统计基线：公开增强版 `c27b6cdc3ac35a8ea6e180313ebbf1d966cad0d2`，后续新增内容需更新本表或明确写入下一批。

## 状态定义

- **入口覆盖**：存在原生 PRIMARY/skill 入口，并由原 routing/coherence 检查。
- **方法覆盖**：入口下有 references 或内置流程，可作为来源支持/交叉核对的知识入口。
- **本方复现**：已有本方 fixture/练习题/目标输出；没有则保持未复现。
- **目标验证**：具体目标、版本和环境的闭环；本表不把公开文章或目录库存当作目标验证。

全库不能因“每个目录都存在”就称作所有方法都已验证。历史 references、seed 和公开 writeup 需要按上述可信等级逐条复核；本轮新增的 40 个单元已经分开标注方法评审和本方状态。

## 入口盘点

| 范围 | 当前基线 |
|---|---:|
| 原有领域路由 | 44 条，原相对优先级保持 |
| 新复刻阶段 | R46，旧 178 条 benchmark 期望不变 |
| 当前 benchmark | 192 条 |
| 核心 SKILL.md | 46 份（含总控） |
| 原有 references | 以仓库当前文件为准，数量不作为正确性证明 |
| 本批新增知识 | 40 单元：方法评审与本方状态分开记录 |

## 正式入口覆盖

| 路由 | 入口 | 当前判断 | 主要空档/边界 |
|---|---|---|---|
| R0 | reverse-engineering | 入口与通用反分析方法覆盖 | 具体目标仍需目标身份和版本证据 |
| R1 | apk-reverse | Android/APK流程覆盖 | 厂商加固、设备和业务验收按目标验证 |
| R2 | mobile-reverse | Android/iOS移动入口覆盖 | iOS设备动态链需单独环境 |
| R3 | js-reverse | JS/前端签名与运行时入口覆盖 | JS VM/WASM、风控站点需具体样本 |
| R4 | reverse-engineering/dsl-vm-reverse | 自定义VM入口覆盖 | 每种VM需独立字节码/向量证据 |
| R5 | dotnet-reverse | .NET入口覆盖 | 保护器版本与运行时dump边界 |
| R6 | ida-reverse | IDA静态入口覆盖 | 商业工具/provider状态按机器核对 |
| R7 | radare2 | CLI入口覆盖 | 交叉工具结果需绑定版本 |
| R8 | firmware-pentest | 固件/仿真入口覆盖 | 硬件/内核/业务等价仍需目标验证 |
| R9 | malware-analysis | 样本分析入口覆盖 | 恶意属性与普通逆向保持分开 |
| R10 | attack-chain | 多阶段安全任务入口覆盖 | 不替代领域PRIMARY |
| R11 | pentest-tools | 渗透工具入口覆盖 | 目标scope和真实服务结果分开 |
| R12 | api-security | API安全入口覆盖 | 注册/登录协议跨入protocol-reverse |
| R13 | supply-chain-security | 供应链入口覆盖 | 依赖可达和制品签名需项目证据 |
| R14 | llm-security | LLM/Agent安全入口覆盖 | 具体系统结果需实际任务 |
| R15 | binary-diff | 跨版本/追版入口覆盖 | O/C/N三方比较，旧proof不能直接沿用 |
| R16 | patch-diff-exploit | 补丁差分入口覆盖 | 版本与前后行为需样本证据 |
| R17 | pwn-chain | 利用链入口覆盖 | 题目/目标输出和利用稳定性分开 |
| R18 | edr-bypass-re | EDR研究入口覆盖 | 版本、环境和观察副作用需限定 |
| R19 | browser-automation | 浏览器/桌面入口覆盖 | 爬虫状态图、worker/WebSocket需样本 |
| R20 | docs-generator | 文档交付入口覆盖 | 报告不替代证据 |
| R21 | protocol-reverse | 协议入口覆盖 | 注册、重放、状态和canonicalization需闭环 |
| R22 | ghidra-reverse | Ghidra入口覆盖 | provider/版本按机器验证 |
| R23 | cloud-k8s | 云/容器入口覆盖 | 云身份与真实配置需项目证据 |
| R24 | windows-ad | Windows身份入口覆盖 | 域环境和协议链需目标条件 |
| R25 | digital-forensics | 取证入口覆盖 | 时间线、符号和镜像身份需原始材料 |
| R26 | code-audit | 源码审计入口覆盖 | 静态候选与实际可达分开 |
| R27 | threat-hunting | 威胁狩猎入口覆盖 | 假设与检测结果需环境数据 |
| R28 | ot-ics | 工控入口覆盖 | 设备/协议/被动范围单独确认 |
| R29 | wifi-wireless | 无线入口覆盖 | 硬件和射频环境需目标验证 |
| R30 | browser-extension-reverse | 扩展逆向入口覆盖 | MV3 worker与权限面需具体扩展 |
| R31 | macos-reverse | macOS入口覆盖 | Mach-O/签名/设备环境需单独验证 |
| R32 | thick-client | 厚客户端入口覆盖 | IPC/更新/本地存储需目标证据 |
| R33 | go-rust-reverse | Go/Rust入口覆盖 | 编译器/版本/符号恢复需样本 |
| R34 | hardware-security | 硬件调试入口覆盖 | 设备操作不是静态资料可替代 |
| R35 | database-security | 数据库入口覆盖 | 具体版本与配置需环境证据 |
| R36 | email-security | 邮件入口覆盖 | 邮件头/策略结论需原始样本 |
| R37 | identity-federation | SAML/OIDC入口覆盖 | 服务端配置与流程需实际响应 |
| R38 | radio-sdr | RF/SDR入口覆盖 | 硬件和信号采集需专用环境 |
| R39 | diagram-generator | 图表交付入口覆盖 | 图表是表达物，不是新证据 |
| R40 | case-review | 证据审查入口覆盖 | 机械审查不替代语义审阅 |
| R41 | ctf-sandbox | CTF入口覆盖 | 公开题/solver/输出需逐题绑定 |
| R45 | binary-ninja-reverse | Binary Ninja入口覆盖 | 商业工具与MCP状态按机器核对 |
| R46 | reconstruction | 证据驱动复刻与验证入口覆盖 | 本方spec/测试/行为对照仍按目标逐项完成 |

## 基线完成标准

本表达到“可维护全领域基线”的条件是：所有入口可路由、原始回归全绿、每个领域都有方法入口和明确边界、可靠方法与未复现方法分层、空档可定位、来源可追溯、更新/追版可恢复。它不要求把所有公开方法在本方真实目标上运行一遍，也不把来源支持升级为目标验证。

下一次大版本维护按空档和新来源增量推进；小版本只改来源、状态、兼容性、错误和局部方法，并重新运行适用检查。
