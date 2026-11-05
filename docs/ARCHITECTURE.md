# 系统架构图

## 原版兼容边界

本仓库在原版 `reverse-skill` 上做增量扩展。原路由事实源、相对优先级、scope/auth 门、Evidence 契约和原 benchmark 继续有效；困难目标参考资料不改变 PRIMARY，也不把 REA、Spec Kit 或某个宿主变成硬依赖。维护和审查规则见 [ORIGINAL-COMPATIBILITY-CONTRACT.md](ORIGINAL-COMPATIBILITY-CONTRACT.md)。


```mermaid
flowchart TD
    Start([用户提出安全/逆向任务]) --> Activation{任务已明确激活本包?}
    Activation -->|否| ReadOnly([只读说明/审查，不执行仓库脚本])
    Activation -->|是| Preflight[读取 RULES、MASTER-ROUTING 与平台入口]
    Preflight --> Consent{首次副作用计划已披露并获批?}
    Consent -->|否| ConsentPlan[列出命令、写入、下载、服务和配置影响]
    ConsentPlan --> WaitApproval([等待用户批准])
    WaitApproval --> Preflight
    Consent -->|是| Route[运行原生 master-route<br/>从 routing.json 选择 PRIMARY]
    Route --> Scope[case-init / scope.md<br/>设置 auth、in_scope、network_profile]
    Scope --> Guard{scope ready_for_act?}
    Guard -->|否| Stop([停止并补齐授权/范围])
    Guard -->|是| Journal[按需检查 field-journal]
    Journal --> Tools[读取 tool-index.md<br/>确认真实工具路径]
    Tools --> ToolOK{工具可用?}
    ToolOK -->|缺失| Bootstrap[披露并批准后调用受控 bootstrap<br/>或记录缺口]
    ToolOK -->|可用| Primary[打开 PRIMARY SKILL.md]
    Bootstrap --> Primary
    Primary --> WorkItem[创建一个 bounded work item]
    WorkItem --> Execute[调用 REA 或受控 fallback<br/>保留 Evidence、Unknown 和 cleanup]
    Execute --> Finding[Evidence → Finding → Path]
    Finding --> Decision{有真实方案分叉?}
    Decision -->|否| Next[按唯一 Evidence 路径继续]
    Decision -->|是| Grill[方案前读取 grilling<br/>逐轮审查 design tree]
    Grill --> Consensus{用户确认达成共识?}
    Consensus -->|否| Grill
    Consensus -->|是| Implement[按确认范围实施/复刻/验证]
    Next --> Implement
    Implement --> TaskDone{任务完成?}
    TaskDone -->|否| WorkItem
    TaskDone -->|是| ReviewCase[调用 case-review<br/>校验证据图]
    ReviewCase --> Completion[按 RULES 适用的收尾清单<br/>报告、图、journal、索引]
    Completion --> Output([输出最终结果和 Unknown])
```

图中的 `routing.json` 是唯一路由事实源；`routing.md` 只用于歧义解释，不直接修改。`grilling` 是 Pi 适配层的可选伴随技能，不属于本仓库的客户端中立核心。

## Skills 模块关系图

```mermaid
flowchart LR
    subgraph 路由层
        SKILL[SKILL.md<br/>总控入口]
        Routing[routing.md<br/>路由矩阵]
    end

    subgraph 逆向分析
        APK[apk-reverse<br/>APK 逆向]
        IDA[ida-reverse<br/>IDA Pro]
        R2[radare2<br/>CLI 分析]
        RE[reverse-engineering<br/>通用方法论]
        BinDiff[binary-diff<br/>符号迁移]
        PatchDiff[patch-diff-exploit<br/>N-day 武器化]
    end

    subgraph 漏洞利用
        Pwn[pwn-chain<br/>RE→exploit]
        Firmware[firmware-pentest<br/>固件全链路]
    end

    subgraph 渗透测试
        Pentest[pentest-tools<br/>工具链+循环框架]
        SrcHunter[src-hunter<br/>19 playbook]
        EDR[edr-bypass-re<br/>EDR 绕过]
    end

    subgraph Web/浏览器
        JS[js-reverse<br/>JS 签名逆向]
        Browser[browser-automation<br/>Playwright+OpenReverse]
    end

    subgraph 基础设施
        Bootstrap[bootstrap-reverse.ps1<br/>按需自举]
        Discovery[ToolDiscovery.ps1<br/>工具发现]
        ToolIndex[tool-index<br/>状态索引]
    end

    subgraph 输出层
        Docs[docs-generator<br/>报告生成]
        Diagram[diagram-generator<br/>图表生成]
        Review[case-review<br/>Evidence graph audit]
        Journal[field-journal<br/>自动进化]
    end

    subgraph 外部
        CTF[CTF-Sandbox-Orchestrator<br/>40+ 子技能]
    end

    SKILL --> Routing
    Routing --> APK & IDA & R2 & RE & BinDiff & PatchDiff
    Routing --> Pentest & JS & Browser & Pwn & Firmware & EDR
    Routing --> CTF

    Pentest --> SrcHunter
    APK -->|.so 分流| IDA
    APK -->|.so 分流| R2
    PatchDiff -->|写出 PoC| Pwn
    Firmware -->|找到 crash| Pwn
    Pwn -->|整合| Pentest
    EDR -->|投递阶段| Pentest
    JS -->|浏览器操作| Browser
    
    Bootstrap --> Discovery --> ToolIndex
    
    APK & IDA & R2 & Pentest & JS -->|任务完成| Review
    Review --> Docs
    Docs --> Diagram
    Docs --> Journal
```

## Bootstrap 自举流程

```mermaid
flowchart TD
    Need[检测到缺少工具] --> ReadManifest[读取 bootstrap-manifest.json]
    ReadManifest --> Kind{安装类型?}
    
    Kind -->|github-release-zip| GH[从 GitHub Release<br/>下载 ZIP 解压]
    Kind -->|pip-package| Pip[pip install]
    Kind -->|npm-mcp| NPM[npx 启动 + 注册 MCP]
    Kind -->|npm-global| Global[npm install -g<br/>+ postInstall]
    Kind -->|winget-package| Winget[winget install]
    Kind -->|local-http-mcp| HTTP[注册 URL + 启动服务]
    
    GH & Pip & NPM & Global & Winget & HTTP --> Verify{验证可用?}
    Verify -->|成功| AddPath[加入 PATH<br/>刷新 tool-index]
    Verify -->|失败| Manual[输出手动安装引导]
    
    AddPath --> Continue([继续执行任务])
    Manual --> Wait([等待用户确认])
```

## 渗透测试循环

```mermaid
flowchart TD
    Init[初始化：确定目标/范围/工具] --> Loop

    subgraph Loop[核心循环]
        Align[1. 重新对齐目标] --> Review[2. 审查已知发现]
        Review --> Decide[3. 决定下一步操作]
        Decide --> Risk{4. 风险门控}
        Risk -->|低/中/高| Exec[5. 执行操作]
        Risk -->|严重| Ask[请求用户批准]
        Ask -->|批准| Exec
        Exec --> Record[6. 记录结果]
        Record --> Check{7. 自我检查}
        Check -->|继续| Align
        Check -->|完成| Done
    end

    Done[8. 完成检查] --> Report([生成最终报告])
```

## 自动进化机制

```mermaid
flowchart LR
    Task([完成任务]) --> WriteLog[写入 field-journal<br/>踩坑+解决方案+代码]
    WriteLog --> UpdateIdx[更新 _index.md<br/>按场景分类]
    UpdateIdx --> CheckUpdate{需要更新系统?}
    
    CheckUpdate -->|路由缺失| FixRoute[更新 routing.md]
    CheckUpdate -->|工具变化| FixTool[刷新 tool-index]
    CheckUpdate -->|新工具| FixManifest[更新 bootstrap-manifest]
    CheckUpdate -->|无需更新| Done([完成])
    
    FixRoute & FixTool & FixManifest --> Done

    NewTask([下次同类任务]) --> ReadIdx[读取 _index.md]
    ReadIdx --> Reuse[复用已有经验<br/>避免重复踩坑]
```

## 多平台支持架构

```mermaid
flowchart TD
    subgraph 共享层["共享层（平台无关）"]
        Skills[skills/<br/>SKILL.md + routing.md + references]
        CTF[CTF-Sandbox-Orchestrator/<br/>40+ 子技能]
        Journal[field-journal/<br/>经验沉淀]
        Docs[docs-generator + diagram-generator]
    end

    subgraph Windows["Windows 平台层"]
        WinScripts[skills/scripts/*.ps1<br/>PowerShell 脚本]
        WinManifest[bootstrap-manifest.json<br/>winget + GitHub ZIP]
        WinRules[RULES.md<br/>Windows 版规则]
    end

    subgraph Kali["Kali Linux 平台层"]
        KaliScripts[kali/scripts/*.sh<br/>Bash 脚本]
        KaliManifest[kali/scripts/bootstrap-manifest.json<br/>apt + pip + GitHub tar]
        KaliRules[kali/RULES-kali.md<br/>Kali 版规则]
    end

    Skills --> WinScripts & KaliScripts
    CTF --> WinScripts & KaliScripts
    Journal --> WinScripts & KaliScripts

    WinScripts --> WinManifest
    KaliScripts --> KaliManifest

    WinRules --> Skills
    KaliRules --> Skills
```

### 平台选择逻辑

| 环境 | 使用的规则文件 | 使用的脚本 | 包管理 |
|------|--------------|-----------|--------|
| Windows | `RULES.md` | `skills/scripts/*.ps1` | winget / GitHub Release ZIP |
| Kali Linux | `kali/RULES-kali.md` | `kali/scripts/*.sh` | apt / pip / npm / GitHub tar.gz |

### Kali 版特点

- **大量工具预装**：nmap、sqlmap、hashcat、hydra、metasploit、radare2、binwalk、burpsuite 等无需 bootstrap
- **apt 统一管理**：不需要 winget、不需要手动解压 ZIP
- **bash 原生**：脚本更简洁，无 PowerShell 依赖
- **路径规范**：`/usr/bin/`、`/opt/`、`~/tools/`，无盘符和空格问题

## 文件读取时序图

```mermaid
sequenceDiagram
    participant U as 用户
    participant AI as AI客户端
    participant R as RULES.md / RULES-kali.md
    participant SK as SKILL.md
    participant RT as routing.md
    participant TI as tool-index.md
    participant FJ as field-journal
    participant SUB as 子skill
    participant BS as bootstrap
    participant DOC as docs-generator

    U->>AI: 提出安全任务
    AI->>R: 读取路由规则
    AI->>SK: 读取总控入口
    AI->>RT: 路由匹配
    AI->>FJ: 查同类经验
    AI->>TI: 确认工具状态
    alt 工具缺失
        AI->>BS: 自动安装（.ps1 或 .sh）
        BS-->>AI: 结果
    end
    AI->>SUB: 进入工作流
    AI-->>U: 任务结果
    AI->>DOC: 生成报告
    AI->>FJ: 回写经验
    AI-->>U: 完成
```
