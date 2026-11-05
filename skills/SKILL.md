---
name: reverse-skill-router
description: Routes reverse engineering, exploitation, penetration testing, malware, mobile, firmware, browser automation, documentation, and security tasks to the appropriate specialist skill. Use when a task spans modules or the correct reverse-skill entrypoint is unclear.
---
# Reverse Engineering Skills Master Control

本目录收录了一系列逆向工程相关的技能模块，每个子目录是一个独立模块，内含 `SKILL.md` 描述其适用场景、工具链和工作流程。

## CRITICAL: 路由执行契约（必须立即执行）

读完本文件后，不允许只回复“已读/已理解”。必须按顺序执行：

1. `NOW`：跑平台原生 router（Windows `scripts/master-route.ps1`；Linux/macOS/Kali `scripts/master-route.sh`），从 `config/routing.json` 定 PRIMARY；疑难再读 `routing.md` 三轴附录。
2. `NOW`：平台原生 `case-init` 落地当前分析项目的 `work/<case>/scope.md`；**auth 未 granted 禁止对目标 ACT**。本地离线样本使用 `offline-sample` preset + explicit sample；Force 不得绕过硬门。
3. `ACT`：立即打开 PRIMARY `SKILL.md` 执行 ACTION REQUIRED。
4. `NEXT`：工具路径只认 `tool-index.md`；缺工具 → 平台原生 bootstrap（仅 manifest）。
5. 结论用 Evidence→Finding→Path。任务完成时按 `RULES.md` 的适用收尾清单处理报告、图表、journal 和索引；纯只读审查、范围未就绪或明确不适用的场景记录原因，不伪造完成。

**身份**：见 `ops/IDENTITY.md`（轻量路由包 + 工具自举 + journal；**不是** Z3r0 式平台）。

如果路由无法命中，必须先联网补充方法论并提议新增 skill，禁止硬塞到不匹配模块。

## REA 委派与进程生命周期

`reverse-skill` 是唯一的路由、case 和证据总控；REA 是 PRIMARY 选定后的受限分析执行器。两者的边界与返回格式见：

- `skills/ops/rea-delegation-contract.md`
- `skills/ops/process-lifecycle.md`
- `skills/ops/beginner-operator-guidance.md`

PRIMARY skill 负责提出一个具体的 Evidence 问题并创建 work item，然后调用官方 REA MCP。REA 返回 Evidence、Unknown、provider/session、资源状态和 cleanup 状态；REVERSE 再决定下一步。REA 不创建第二套路由、scope、case 或 Evidence 图。

重型 native provider 默认单实例运行。Ghidra、IDA、radare2、capa 等工具不能在同一个 work item 中并发或重复全量运行。REA 不可用时才使用 raw CLI fallback，并通过 `skills/scripts/process-lease.ps1` 管理 Windows 进程；禁止无 lease 的 `nohup ... &`、无限期全量扫描和超时后直接启动替代 provider。

## 零基础操作员交互规范

零基础引导只改变说明方式和用户交互，不创建第二个 router、PRIMARY、case 或 GOAL 引擎。每个 material stage/work item 完成后，按 `skills/ops/beginner-operator-guidance.md` 用白话报告“本轮做了什么、目前确认了什么、目前还不知道什么、下一步建议”。

下一步建议必须根据当前 Evidence 动态生成 2–5 个编号选项；每个选项包含白话动作、括号中的专业术语、目的、影响、推荐标记、预期结果和对应 bounded work item。用户输入编号即可选择，不能要求用户选择 REA/Ghidra/radare2 或编写技术参数。没有真实分叉时不制造菜单。

当当前 Evidence 足以评估长期结果时，输出多个动态生成的目标候选，并为每个候选提供可复制的 GOAL 文本。GOAL 引擎属于宿主；reverse-skill 只定义目标文本必须包含范围、约束、成功标准、unknown、停止条件和当前 case 复用要求。源码恢复、行为等价重实现、规格文档、UI 重建和版本适配等目标只能按本轮 Evidence 的可行性出现，不能把通用模板冒充成结论。

## 指令语义级别（RFC 2119）

- `MUST`：必须执行，违背即任务失败。
- `MUST NOT`：禁止执行，违背即安全违规。
- `SHOULD`：原则上要做，不做必须说明原因。
- `MAY`：可选动作。
## 当前模块

| 模块 | 目录 | 适用场景 |
|------|------|---------|
| **通用逆向** | `reverse-engineering/` | GDB / Frida / angr / Unicorn / Qiling / 反分析对抗 / 全语言平台逆向 / CTF 模式库 |
| **APK 逆向** | `apk-reverse/` | Android APK 解包、jadx 反编译、smali 修改、Frida Hook、重打包签名安装 |
| **.NET / C# 逆向** | `dotnet-reverse/` | 托管 PE 逆向、dnSpyEx + de4dot 脱混淆（ConfuserEx/SmartAssembly/Babel）、IL patch、Sharp* 红队工具分析、dnSpy MCP 联动 |
| **IDA Pro 逆向** | `ida-reverse/` | IDA Pro MCP HTTP 服务器（72 个工具）：反编译、反汇编、数据流追踪、交叉引用 |
| **前端 JS 逆向** | `js-reverse/` | 浏览器端签名定位、加密参数分析、运行时采样、Node 补环境复现；优先用现有 `js-reverse_*`，需要更强的浏览器/CDP/Hook 面时接入 jshookmcp，但前提是先把该 MCP server 下载/注册并启用 |
| **radare2 分析** | `radare2/` | CLI 二进制侦察、反汇编、patch：r2 / rabin2 / rasm2 / radiff2 |
| **CTF 入口** | `ctf-sandbox/` | 单 PRIMARY；下游仍在 sidecar `../CTF-Sandbox-Orchestrator/` |
| **技术文档编写** | `docs-generator/` | 任务完成后自动生成逆向报告、渗透报告、CTF writeup、签名逆向报告 |
| **Evidence 图审查** | `case-review/` | 校验 scope、Evidence→Finding→Path 可追溯性、workitems、timeline 与 artifact hash |
| **浏览器与桌面自动化** | `browser-automation/` | 浏览器操作（Playwright）+ Windows 桌面应用操作（OpenReverse UIA/CUA）+ 网络观察 |
| **证据驱动复刻与验证** | `reconstruction/` | 已确认行为→规格→独立实现→原版对照；复用官方 REA 和 Spec Kit，追版保留我方设计 |
| **跨版本符号迁移** | `binary-diff/` | 有旧版符号迁移到新版、缺 PDB 推导、程序更新后批量迁移函数名；旧上游/我方成果/新上游三方追版 |
| **N-day 补丁差分→利用** | `patch-diff-exploit/` | 从厂商补丁定位漏洞点、写 PoC、N-day 武器化（与 binary-diff 分工：本 skill 偏攻击侧） |
| **RE→利用链** | `pwn-chain/` | 从逆向走到可用 exploit：栈/堆/内核 pwn、pwntools、libc-database、CTF 到真实远程的稳定化 |
| **固件渗透链** | `firmware-pentest/` | OWASP FSTM 九阶段：提取→EMBA 自动化→Firmadyne/QEMU 仿真→AFL++ fuzz→实机利用 |
| **EDR 绕过逆向** | `edr-bypass-re/` | 红队场景：逆向 EDR 的 hook 表/ETW/AMSI → 直接 syscall / Hell's Gate / 硬件断点 / call stack spoof |
| **渗透测试工具链** | `pentest-tools/` | Nmap/Nuclei/SQLMap/FFUF/Hashcat/Pentest Swarm 等 20+ 渗透工具，通过 MCP 暴露给 AI |
| **图表生成** | `diagram-generator/` | 从自然语言生成 Mermaid/Graphviz/PlantUML 图表（攻击路径图、数据流图、架构图、状态机） |
| **攻击链编排** | `attack-chain/` | 多阶段攻击路径规划与执行的总指挥；完整渗透、HW 演练、从外网打到域控等跨阶段任务从这里开始 |
| **LLM/AI 安全测试** | `llm-security/` | OWASP LLM + ASI Top 10：Prompt 注入、工具滥用、记忆投毒、Agent 劫持、系统提示词提取、**Agent 服从性工程** |
| **API 安全测试** | `api-security/` | REST/GraphQL/WebSocket 全协议：BOLA/IDOR、JWT/OAuth 攻击、10 阶段方法论 |
| **供应链安全** | `supply-chain-security/` | SBOM/SCA/CI-CD 管道：依赖扫描、容器安全、构建完整性、漏洞可达性验证 |
| **移动逆向工程** | `mobile-reverse/` | Android + iOS：Frida/Objection 动态插桩、SSL Pinning/Root/越狱检测绕过、OWASP MASTG |
| **恶意软件分析** | `malware-analysis/` | 样本分析六阶段、YARA/Sigma、反分析检测、沙箱编排 |
| **DSL 虚拟机逆向** | `reverse-engineering/dsl-vm-reverse/` | JS 自定义指令集 VM（IIFE + switch-case opcode）；风控/验证码引擎等 |
| **作战契约 ops** | `ops/` | Scope / 证据链 / 角色 / 时间线 / 身份 / skill 供应链安全 |
| **社区 skill 对照** | `references/community-security-skills.md` | 外部安全 skill 索引与借鉴规则（禁止盲装） |
| **Skill 供应链** | `ops/skill-supply-chain.md` | 外部 skill/MCP 安装门闩（AST10 精简） |
| **RE 阶段门闩** | `reverse-engineering/references/re-agent-workflow.md` | triage→static→dynamic→synthesis |
| **授权侦察管线** | `pentest-tools/references/recon-pipeline.md` | scope 门 + 命中≠验证 |
| **协议逆向** | `protocol-reverse/` | 自定义二进制协议 / Protobuf / gRPC / PCAP 帧布局 |
| **Ghidra 逆向** | `ghidra-reverse/` | 开源反编译、headless、Ghidra MCP（无 IDA 时主入口） |
| **Binary Ninja 逆向** | `binary-ninja-reverse/` | HLIL/MLIL/LLIL、Python API，以及可选的社区 MCP/localhost HTTP 集成 |
| **云 / 容器 / K8s** | `cloud-k8s/` | IMDS/IAM、容器逃逸面、Kubernetes RBAC |
| **Windows / AD** | `windows-ad/` | Kerberos、AD CS、BloodHound、中继与域路径 |
| **数字取证** | `digital-forensics/` | 内存/磁盘时间线、PCAP 溯源、IR 保全 |
| **代码审计 / SAST** | `code-audit/` | Semgrep/CodeQL、白盒、危险 API 与鉴权审查 |
| **威胁情报 / OSINT** | `threat-intelligence/` | 公开来源 IOC 补充、活动关联、独立核验与情报交接 |
| **威胁狩猎** | `threat-hunting/` | 假说驱动狩猎、Sigma 检测工程、蓝队验证 |
| **OT / ICS 工控** | `ot-ics/` | Purdue 分区、PLC/SCADA、被动优先评估 |
| **Wi-Fi / 无线** | `wifi-wireless/` | 授权无线评估、握手/PMKID、实验室规则 |
| **浏览器扩展逆向** | `browser-extension-reverse/` | Chrome/Firefox 扩展、MV3 worker、权限面 |
| **macOS / Mach-O** | `macos-reverse/` | 签名、ObjC/Swift、LaunchAgent、macOS 样本 |
| **厚客户端** | `thick-client/` | 桌面 C/S、本地存储、IPC、更新通道 |
| **Go / Rust 逆向** | `go-rust-reverse/` | 剥离符号 Go/Rust、pclntab、panic 字符串 |
| **硬件调试接口** | `hardware-security/` | UART/JTAG/SWD、只读提取、交接固件 |
| **数据库安全** | `database-security/` | MySQL/PG/MSSQL/Mongo/Redis 暴露与配置 |
| **邮件安全** | `email-security/` | 钓鱼拆解、SPF/DKIM/DMARC、BEC |
| **联邦身份** | `identity-federation/` | SAML/OIDC/OAuth SSO 流与错配 |
| **RF / SDR** | `radio-sdr/` | 授权射频研究、默认只收 |

## 统一入口

遇到逆向、CTF、抓包、前端签名、APK 改包、二进制分析类任务时，先按这个顺序进入：

1. 平台原生 router（Windows `scripts/master-route.ps1`；Linux/macOS/Kali `scripts/master-route.sh`）→ PRIMARY（`config/routing.json`）
2. 平台原生 `case-init` → `scope.md`
3. 打开 PRIMARY `SKILL.md`
4. 疑难时读 `routing.md`，需要本机路径时读 `tool-index.md`

## 工作思路

这些模块可以按需组合使用：

1. **拿到一个目标** → 先看文件类型，选对应的分析工具
2. **快速捡漏** → strings / rabin2 -z / ltrace 看看有没有直接线索
3. **深入分析** → 如果需要反编译→IDA；需要动态 Hook→Frida；需要符号执行→angr
4. **一条路走不通就换一条** → 静态分析不行就动态，Java 层不行就看 so，页面观察不够就断点

## 下一步菜单模式（Next-Step Menu Pattern）

只有在 **genuine decision boundary**（存在两个或以上 materially different、evidence-supported 分支，且用户选择会改变下一动作）时，子 skill 才 `MUST` 提供 3-6 个编号选项。若下一步由 gate / Evidence 唯一决定，`MUST` 直接继续，并按 `ops/timeline-workitem.md` 只记录 `decision_delta` + `carry_forward_refs`；`MUST NOT` 为制造菜单而重新输出 unchanged route/scope/auth/context。

格式要求：
- 每个选项以数字编号（1-6 范围）
- 每个选项描述一项具体可执行的动作（不是抽象方向）
- 至少包含一个"导出报告/写 writeup"选项
- 至少包含一个"继续深入分析"或"换一种方法"选项
- 必要时包含一个"停止/暂停/询问其他问题"出口

示例：
```
## 建议下一步（选一个编号）

1. 对 sub_140001000 做深度反编译，还原算法
2. 用 Frida 动态 Hook 验证参数猜想
3. 导出当前已命名函数，生成符号迁移 YAML
4. 生成当前阶段的分析报告
5. 换 radare2 做轻量侦察对比
6. 暂停，我先确认前面的证据
```

## 目录是动态扩充的

本目录会持续增长。发现新的子目录时，读它的 `SKILL.md` 就能快速了解用途。

新增 skill 时，按 `CONTRIBUTING.md` 的标准流程操作，确保：
- 路由矩阵能正确分流
- bootstrap 系统能自动补齐依赖
- tool-index 能反映新工具状态

## 关联资源

- 本机还有 **anything-analyzer**（端口 23816）MCP 服务器，提供浏览器自动化、HTTP 捕获和 AI 分析能力
- `tool-index.md` 记录本机逆向工具是否可用、实际路径、版本和脚本引用
- 包根目录下的 `README.md` 提供面向 Claude Code、Codex CLI 与其他代码 AI 客户端的通用安装与接入说明

## 按需自举

当 workflow 发现缺少工具时，不要直接报错。统一调用平台原生 bootstrap：

Windows：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-root>\scripts\bootstrap-reverse.ps1" -Capability @('工具名') -StartServices
```

Linux / macOS：
```bash
bash <skill-root>/scripts/bootstrap-reverse.sh 工具名 --start-services
```

Kali：
```bash
bash <package-root>/kali/scripts/bootstrap-reverse.sh 工具名 --start-services
```

支持的能力（以 `scripts/bootstrap-manifest.json` 为准）：jadx、apktool、jeb-pro、binaryninja、frida、frida-ps、idalib-mcp、reqable-mcp、jshookmcp、xquik-mcp、anything-analyzer、idapro、r2、rabin2、adb、agent-browser、ghidra-mcp、seclists、proxycat、burpsuite-mcp、nmap、pentestswarm、binwalk、yara、pwntools、bkcrack

> JEB Pro 已登记为**手动许可安装**能力：bootstrap 只输出指引，绝不下载或规避商业许可。Reqable MCP 仅登记固定版本的官方运行时，仍需要用户自行安装 Reqable 桌面客户端。
>
> 清单中未登记的工具（如 unblob/EMBA 等）`MUST` 在 skill 文档中走手动安装步骤，禁止假装可 bootstrap。

自举完成后会自动刷新 `tool-index`。

## 操作先例库（Precedent Files）

在执行任何逆向/渗透操作之前，按顺序 MUST 读取：

| 读序 | 文件 | 何时读 |
|------|------|--------|
| **#1** | `ops/scope-contract.md` + `case-init.ps1` | 可执行授权门。`precedent-auth.md` 不写 granted |
| **#2** | `field-journal/precedent-reverse.md` 或 `precedent-pentest.md` | 按需 — AI 犹豫时才加载 |

**#1 前置，#2 懒加载。**

## 持续维护与组合使用

本增强版保留原生路由与扩展链。已有领域 PRIMARY 先完成分析，再用同一个 router 进入 [复刻技能](reconstruction/SKILL.md)；REA 只接受当前专业任务的具体分析委派。Pi/Codex 等安装与资源消歧统一由 [独立安装仓库](https://github.com/gthubtom1/reverse-workflow-installer) 维护，本核心不依赖某个宿主。

用户要求“到网上补充知识”时，先读 [知识可信等级](references/knowledge-confidence.md)、[领域覆盖基线](references/domain-coverage-baseline.md)、[第一批来源清单](references/distillation-sources.md) 与 [第二批高难领域来源登记](references/distillation-sources-batch-2.md)、[第三批高难逆向增量来源登记](references/distillation-sources-batch-3.md) 与 [外部蒸馏来源登记](references/distillation-sources-batch-4.md)，比较旧文再蒸馏到所属 references；实际研究经验沿原 field-journal 回写。来源核对、结构检查和技术复现分别记录。历史存量未复核，不以文件数量宣布全领域成功。

## 自动进化

每次完成逆向/渗透任务后，必须回写经验到 `field-journal/` 目录。详见 `RULES.md` 的"任务完成后的硬性 Checklist"。

- 模板：`field-journal/_template.md`
- 索引：`field-journal/_index.md`
- 先例：`field-journal/precedent-auth.md` → `precedent-reverse.md` → `precedent-pentest.md`
- 新任务开始前先查索引和先例，复用已有经验

## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否完成了路由三轴匹配（目标类型 + 用户意图 + 工具链）？
- [ ] 我是否在路由成功后读取了目标 skill 的 SKILL.md？
- [ ] 路由未命中时，我是否提议了新增 skill 而非强行匹配？
- [ ] 我是否基于 `tool-index` 使用了真实工具路径？
