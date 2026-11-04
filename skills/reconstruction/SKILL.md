---
name: reconstruction
description: >-
  证据驱动的独立功能复刻、复刻验收与已复刻项目跟随上游更新。
  在同一授权 case 内衔接原生分析、REA Evidence、Spec Kit 规格/实现及原版行为对照；
  支持保留我方界面的 O/C/N 三方追版，不承诺恢复原作者源码或任意程序全局等价。
---

# 独立复刻与追版 / Reconstruction

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: MUST 读取 [先例索引](../field-journal/_index.md) 与 [逆向先例](../field-journal/precedent-reverse.md)，确认任务属于独立复刻、验证或追版。先例 MUST NOT 替代授权；授权以原 case 的 `scope.md` 为准，检查 auth、资产、活动、网络与 readiness。超出原 scope 的新版本/新活动 MUST 先补范围决定。
2. `NOW`: MUST 从用户成果项目恢复唯一 case 与 Spec Kit feature，读取原 `scope.md`、`timeline.md`、`workitems.md`、Evidence 及原生 tasks。追版 MUST 按 [追版步骤](references/upstream-follow-update.md) 固定 O/C/N；多候选时只暂停依赖身份的工作。
3. `NEXT`: MUST 读取 `../tool-index.md` 确认真实路径、版本与工具资格；委派 REA 前核安装版 `binary_session`、`tools/list` 及实际 schema，读取官方随包方法。缺工具唯一恢复入口是已授权的平台 bootstrap；未登记能力则报告缺口，交独立 installer 处理，MUST NOT 猜路径或自行安装。
4. `NEXT`: MUST 按 [证据交接](references/evidence-to-spec.md) 复用原 case-review，再执行只读 `check_handoff.py` 检查指针。`PASS` 仅为 `machine_check_only`；关键 unknown、证据资格与语义支持 MUST 独立审查后才可放行受影响需求。
5. `ACT`: MUST 接续下述确定性工作流，写原 timeline 的 `decision_delta` 与 `carry_forward_refs`，更新原 workitems 与 Spec Kit tasks。MUST NOT 重做 case-init、重置 scope、创建第二状态账本，或停在仅打印命令的状态。

## 适用范围

本 skill 负责证据→规格→实现→收敛→原版对照的一个原生工作流，支持 `initial`、`validate`、`update` 三种工作方式（写在 timeline/notes，非新状态机）。默认交付范围是用户选定的功能与可观察行为。独立实现、原件补丁与重打包 MUST 明确区分；补丁复用不构成独立实现。

“先分析 APK/JS/PE 再复刻” MUST 先走原专业 PRIMARY，并将后续复刻记在同一 case 待办。纯反编译、源码恢复、符号迁移和普通 case 证据审查仍归各自模块。路由未命中 MUST 提议新增 skill 或向原路由维护者提交关键词/基准，MUST NOT 硬塞模块或实现第二路由器。

## 工具依赖

| 工具 | 是否必需 | 用途 | 可自动安装 |
|------|---------|------|-----------|
| Python 3.9+ 标准库 | 是，机械检查 | 原 case-review 与本 skill 的只读脚本/测试 | 仅已登记并获授权的平台能力 |
| REA 官方安装包与实际可用 provider | REA 声明验收必需 | 原生 Evidence 导出、有限 claim、obligation、coverage | 由独立 installer 协调官方发行；本 skill 不安装 |
| Spec Kit 官方 `specify` 与项目原生命令 | 规格/实现阶段必需 | constitution、spec、plan、tasks、analyze、converge | 同上；MUST NOT 改官方库 |
| 原专业分析工具 | 按目标需要 | APK、JS、PE 等分析及版本差分 | 只按 tool-index 与原 bootstrap 清单 |
| 成果项目构建/测试运行时与隔离环境 | 真实验收必需 | 两侧实跑、留出、干净构建/回滚 | 遵守原 scope 和批准的副作用范围 |

路径 MUST 来自工具索引/安装回执；上游文档能力不等于本机已具备。REA 不可用时 MAY 用原专业工具继续分析并保留其原始输出，但依赖 REA 的验收保持未验证；MUST NOT 伪造 REA ID、bundle 或通过回执。

## 工作流

### 1. 恢复与冻结输入

MUST 在工具源码外的用户成果项目工作。复用 `work/<case>/`；原 Evidence/Finding/Path 枚举不变，Path 仍仅 `attack | callflow | solve`。MUST 固定目标身份、选定功能、来源与摘要、我方 commit/包摘要、环境及 feature/spec/plan/tasks 的相对引用。首次交付 MUST 同时留存 UI/品牌/设计差异、构建/运行/回滚记录和下次恢复入口。缺材料 MUST 写未验证。

追版先执行 [upstream-follow-update](references/upstream-follow-update.md) 的唯一旧项目与 O/C/N 步骤，再进入步骤 2。不得按文件名、旧 RVA 或相似度直接应用改动。

### 2. 证据交接与需求冻结

MUST 归档 REA 官方 `export_evidence_bundle` 完整输出，原样保留 evidence_id、provider、environment、authority、limitations 与 unknowns，计算确切文件 SHA 并以原 E 条目引用；会话 ID 单独不足以交接。跨进程读回只用安装版支持的接口。

MUST 在原 notes 与原生 spec 维护 FR→F/E→bundle 原 ID→测试的轻量引用，注明 `observed / inferred / unknown / designed` 来源资格。推断和默认值 MUST NOT 冒充观察。每项 FR 必须映射到 REA 原生生成或 reviewed obligation；交接清单仅引用输出，不复制 ledger。初始 open/unknown 正常，MUST NOT 改称 ready。关键 unknown 只阻断依赖它的功能，其他独立 feature MAY 继续。

先运行原检查（下列路径相对技能包根，项目路径由调用方明确提供）：

```text
python -B skills/case-review/scripts/review_case.py <project>/work/<case> --verify-hashes --strict --format json
python -B skills/reconstruction/scripts/check_handoff.py <project> work/<case>/notes/handoff-manifest.json --format json
```

脚本只读取文件并向 stdout 输出；命令文本、repro_command、verifier 和目标 MUST NOT 由脚本执行。参数、清单格式及边界见 [handoff-manifest](references/handoff-manifest.md)。case-review 负责原图与 scope 字段审查，本脚本不复制它。两者通过仍 MUST 独立审查“引用原文是否支持这个错误码、默认值、状态迁移”，并回查原版/REA 有限 claim。缺证据回专业分析，不以 Spec Kit 默认猜测补齐。

### 3. 原生规格与实现

MUST 按 [spec-kit-workflow](references/spec-kit-workflow.md) 执行实际生成的官方项目命令：constitution→specify→clarify→plan→tasks→analyze→implement→converge。MUST 保留原模板主体、FR/SC/US/任务 ID 和 source-ref。项目 constitution 限定复刻事实必须有证据；用户新设计单列 designed。只打印斜杠命令不算执行；默认 workflow 未必含 analyze/converge，MUST 显式执行。

实现缺项回 tasks；规格偏差回原专业 PRIMARY/REA；MUST NOT 修改预期让错误规格测试变绿。追版 MUST 使用版本化 feature，保留冻结旧版，我方 UI/特色默认保留，只有 scope 内新增/变化进入实现。

### 4. 真实验证与失效回流

MUST 按 [differential-validation](references/differential-validation.md) 冻结比较器、环境、规则、容差和留出摘要，由独立验证会话分别采集原版与我方输出。覆盖正常/错误/边界/状态/副作用，并用故意错误变体证明比较器能失败。

MUST 由真实测试生产 proof，记录 owner 精确哈希输入、唯一 module_path/symbol、obligation 版本、fixture/verifier 身份。需求/依赖/源码/比较器/环境/测试改变后，旧 proof MUST 按适用性失效并重跑；保留旧证据不代表本轮通过。MUST NOT 手填 `passed` 字段或伪造 semantic ID。

REA 生产链仅委派官方接口：`build_reconstruction_obligation_ledger`、适用平台的 `capture_process_scenario` / `compare_process_captures` / `verify_reconstruction`、`evaluate_reconstruction_coverage`。输入与结果状态以安装版 schema 为准，MUST NOT 导入其库或复写 closure。交付范围内 required obligations verified、required_open=0、ledger ready，选定 boundary 必需 surface/claim 与依赖完整，且无失败/未知，才可报告相应有限声明通过。零声明和同源两侧不能算通过。平台不支持则标 unknown/unsupported；独立 harness 不能冒充原生声明关闭。

### 5. 交付与恢复

MUST 分别报告“规格符合”“声明范围原版行为对照”“独立运行”；任何一项不能替代另一项。隔离环境必须实际核可见路径/挂载/共享，禁止转调原件；仅新建目录不证明独立性。未执行、截断、超时、缺设备/环境保留未验证。

MUST 在同 case 的 timeline/workitems/notes 保存 feature、原 bundle、真实测试输出与报告指针，并沿原 docs-generator、diagram-generator、field-journal 和 RULES 的适用 Checklist 完成收尾。MUST 脱敏，知识/经验写回遵守用户允许的写入范围；被委派范围不含共享索引时交主流程集成，不越界修改。

## 按需自举（On-Demand Bootstrap）

### 自动化能力边界

| 能力 | 可自动安装 | 安装方式 | 说明 |
|------|-----------|---------|------|
| 已登记原专业工具 | 以当前平台 manifest 为准 | 原平台 bootstrap | MUST 先披露准确命令、写入/网络/服务效果并按已有授权执行 |
| Python、REA、Spec Kit 未登记能力 | 否 | 独立 installer 或维护者补正式能力 | MUST 报告具体缺口，MUST NOT 编造 capability 名称 |
| 宿主适配、MCP 注册、客户端全局配置 | 本 skill 不提供 | 独立 installer | 不在本目录实现 Pi/Codex 等宿主安装层 |

### 自举触发点与失败处理

本 skill 脚本 MUST NOT 自动 bootstrap、下载、启动服务或改配置。代理发现所需工具为 no 时，唯一恢复入口是原平台 bootstrap（Windows `../scripts/bootstrap-reverse.ps1`；Linux/macOS `../scripts/bootstrap-reverse.sh`；Kali 包根 `kali/scripts/bootstrap-reverse.sh`），仅调用已登记且获授权的能力。未登记/失败时 MUST 停止依赖该工具的步骤，报告实测版本、错误与缺口，交独立 installer/维护者；同工具失败两次不再自动重试。已有授权覆盖的确定性步骤直接继续。

## 语言行为契约

- 内部推理/工具选择/阶段控制：使用 English。
- 用户可见消息/章节标签/报告/下一步菜单：使用中文，除非用户要求其他语言。
- 默认双语标签：中文在前、英文在后，以 ` / ` 分隔，例如“关键证据 / Key evidence”。

## 路由上下文

**上游入口**：原 `master-route`（唯一规则源 `../config/routing.json`）选定的复刻阶段子任务；分析证据来自原 APK/JS/native 等 PRIMARY。多意图先分析，将复刻记为同 case 待办；到交接点用明确复刻子任务 Hint 调用同一 master-route，结果保存在原 notes，MUST NOT 反复提交带原 APK 关键词的长 Hint 或另建分类器。

**下游出口**：原专业 PRIMARY/REA 补证据；原 Spec Kit tasks 补实现；`case-review/` 审原图；`docs-generator/`、`diagram-generator/` 与 field-journal 收尾。阶段变化只追加 timeline，未变 scope/route/Evidence 用 `carry_forward_refs` 引用。

**同级关联模块**：`binary-diff/`（既有 R15，只调查 O→N 版本差异）、`reverse-engineering/`、`apk-reverse/`、`js-reverse/`、`case-review/`。REA provider 选择不改变 reverse-skill PRIMARY；Spec Kit 不竞争领域路由。共享路由/索引/工具发现由主流程集成，本目录不登记第二份路由表。

### 真正分岔时的菜单

仅当存在至少两条证据支持、选择会改变下一动作的分支时，MUST 提供 3–6 个可执行中文选项，例如：

1. 继续调查阻断新功能的原版状态迁移
2. 先实现已有充分证据的独立功能
3. 导出当前范围、缺件与证据报告
4. 暂停并确认新版本目标身份

确定性转移 MUST 直接继续，MUST NOT 每阶段机械询问。

## 任务完成自检（声称完成前 MUST 通过）

- [ ] 已实际执行适用步骤；原 scope 授权、工具路径和版本有据，未把先例当授权。
- [ ] 唯一成果项目与原 case/版本化 feature 可恢复；timeline 只追加 delta，未建第二状态库。
- [ ] FR→原 Evidence→官方 bundle/obligation→真实测试可追溯，来源资格和关键 unknown 独立审查完成。
- [ ] case-review 与 handoff 机械结果如实保存，未称 semantic verified，未篡改官方包/证据。
- [ ] 实际 analyze/converge、错误变体、原版对照与适用 REA 有限声明均有真实回执；缺失项逐项列出。
- [ ] 追版保留我方 UI/特色、冻结旧版与回滚，新 scope 内功能无遗漏，失效 proof 已重做。
- [ ] 规格符合/范围行为对照/隔离独立运行分别报告，未执行与 unsupported 未冒称通过。
- [ ] 已完成授权范围内 RULES 的报告、图、脱敏经验、来源及索引 Checklist；范围外集成项已移交。
