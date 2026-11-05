# reverse-skill 快速开始与安装边界

`reverse-skill` 是客户端中立的逆向工程、安全研究、CTF 和防御测试技能路由仓库。它提供规则、原生 router、PRIMARY 技能、工具发现、案例契约和知识资料，不是 Pi/Codex 安装器，也不复制 REA 或 Spec Kit。

## 先选择使用路径

### 通过三件套接入 Pi 或 Codex

如果需要同时使用 REA、reverse-skill 和 Spec Kit，请使用独立的 [reverse-workflow-installer](https://github.com/gthubtom1/reverse-workflow-installer)。安装器负责：

- 官方 REA 和 Spec Kit 的版本解析与安装；
- Pi/Codex 的宿主配置和入口适配；
- reverse-skill 工作副本的身份记录；
- receipt、更新、恢复和本机验收。

安装后阅读安装仓库的 [安装后快速开始](https://github.com/gthubtom1/reverse-workflow-installer/blob/main/docs/quick-start.md)，依次完成 `verify`、`accept`、宿主重启或 reload，再做一次显式 `/skill:reverse-workflow` 对话测试。Pi 用户如果要在方案或补丁实施前审查隐含假设，按安装仓库教程另外安装官方 `grilling` 伴随技能；它属于 Pi 适配层，不进入本仓库核心路由。

不要在本仓复制安装器脚本，也不要把 REA MCP 或 Spec Kit CLI 写成本仓的硬依赖。

### 单独使用 reverse-skill

只需要客户端中立路由和专业技能时，获取增强版仓库：

```text
git clone https://github.com/gthubtom1/reverse-skill.git
cd reverse-skill
```

先阅读：

1. `README_AI.md`：AI Agent bootstrap 和平台入口；
2. `RULES.md`：授权、scope 和行为链；
3. `skills/MASTER-ROUTING.md`：PRIMARY 快路径；
4. 当前任务对应的 `skills/*/SKILL.md`。

工具索引只在明确需要本机工具状态时刷新。刷新会生成机器相关文件，第一次运行前应先确认写入范围：

```text
Windows: powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/refresh-tool-index.ps1
Linux/macOS: bash skills/scripts/refresh-tool-index.sh
Kali: bash kali/scripts/refresh-tool-index.sh
```

## 新对话怎么开始

专业任务优先使用宿主提供的显式入口：

```text
/skill:reverse-workflow

这是一个逆向工程任务，请先读取 RULES.md 和本机安装回执（如果当前使用三件套安装），再读取 MASTER-ROUTING.md，并调用原生 router 选择 PRIMARY。

任务：
[填写目标和任务]

目标对象：
[文件、项目目录、离线样本或已授权目标]

范围：
[只读分析 / 复刻 / 原版对比 / 版本追踪 / 知识维护]

请先报告已观察、推断、未知、授权范围和下一步，不要绕过原生 router 直接开始普通命令。
```

如果只使用本仓且宿主没有 `/skill:reverse-workflow`，可以明确要求：

```text
请先读取本仓库的 RULES.md，运行原生 master-route 选择 PRIMARY，再读取对应 PRIMARY 的 SKILL.md。当前任务是：[填写任务]。在 scope 未就绪前不要对目标执行 ACT。
```

## 常见任务入口

| 任务 | 入口 |
|---|---|
| APK / Android | `skills/apk-reverse/` |
| 二进制 EXE/DLL/SO/ELF | `skills/ida-reverse/`、`skills/radare2/`、`skills/reverse-engineering/` |
| 前端 JS、签名、加密参数 | `skills/js-reverse/` |
| 协议、PCAP、Protobuf | `skills/protocol-reverse/` |
| 复刻和行为对比 | `skills/reconstruction/`，先完成原领域分析再进入复刻阶段 |
| 跨版本追踪 | `skills/binary-diff/`，恢复旧上游、我方成果和新上游三方材料 |
| CTF / AWD | `skills/ctf-sandbox/` 和 `CTF-Sandbox-Orchestrator/` |
| Evidence 审查 | `skills/case-review/` |
| 报告和图表 | `skills/docs-generator/`、`skills/diagram-generator/` |

## 目录与职责

- 本仓：规则、路由、专业技能、知识、测试和客户端中立的工作流；
- 安装仓库：REA、Spec Kit、宿主适配、版本、回执、更新和恢复；
- REA 官方：MCP 分析工具和官方证据能力；
- Spec Kit 官方：成果项目中的规格、计划、任务和模板。

安装成功、文件存在、退出码为 0 或路由选择成功，都不能替代真实任务验证。缺少 provider、设备、账号或隔离环境时，应保留 unknown。

## 问题排查

- 宿主没有加载入口：确认工作区、agent/config 根和安装计划一致，然后重启或 reload。
- Pi 新对话没有进入流程：显式使用 `/skill:reverse-workflow`，不要只依赖自然语言自动触发。
- REA MCP 不可用：回到安装仓库执行 `verify` 和 `accept`，不要在本仓复制 MCP 配置。
- Android/JADX provider 缺失：按 REA 官方版本要求准备 provider；普通 JADX JAR 不能直接冒充 REA provider。
- 路由不确定：读取 `skills/routing.md` 作为说明，最终仍以 `skills/config/routing.json` 和原生 router 为准。

授权边界、案例初始化、证据链和工具供应链要求以 `RULES.md`、`skills/ops/` 和对应 PRIMARY 技能为准。社区问题分类见 [COMMUNITY-ISSUE-TRIAGE.md](COMMUNITY-ISSUE-TRIAGE.md)。
