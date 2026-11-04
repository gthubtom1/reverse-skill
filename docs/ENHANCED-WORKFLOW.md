# 增强版：分析、复刻、验证与跟随更新

本仓是公开的 reverse-skill 增量增强版，保留原作者的 Git 历史、MIT 许可、原生路由、工具发现、scope、证据契约及原测试。CTF-Sandbox-Orchestrator 继续保留其独立许可。原项目：[zhaoxuya520/reverse-skill](https://github.com/zhaoxuya520/reverse-skill)；本方上游基线为 `cab634bd855fc287f6e420c1f36fd1a6b9245960`。

## 三件工具与一个安装仓库

- **本仓**：专业任务路由、方法、知识、经验、客户端中立的复刻和追版流程。
- **[REA 官方](https://github.com/morluto/rea)**：分析执行、反编译或运行观察、原生 Evidence 与适用的有限声明核对，保持原版。
- **[GitHub Spec Kit 官方](https://github.com/github/spec-kit)**：规格、计划、任务、实现指导、analyze 和 converge，保持原版。
- **[独立安装仓库](https://github.com/gthubtom1/reverse-workflow-installer)**：统一安装说明、官方稳定版本解析、Pi/Codex 等宿主适配、资源消歧与升级验证。

本仓不提供另一套宿主安装器。官方组件的安装/升级由安装仓处理，知识和专业流程更新在本仓。安装时核当时官方最新稳定发行，单次操作固定确切版本并记录；文档中的已验版本不是永久冻结官方更新。

## 原路由保全

原 `skills/config/routing.json` 仍是唯一事实源；原44条领域路由的相互优先顺序、fallback以及原178条benchmark输入与期望受回归指纹保护。R15仅追加追版相关词，原表达式保留。新增R46负责已取证的复刻阶段，不替代APK、JS、CTF等原专业入口。

“分析APK后复刻”先进入APK；有足够证据后，在同一case中用明确阶段任务调用原router，进入 [reconstruction](../skills/reconstruction/SKILL.md)。REA是当前专业流程的可选执行工具，不根据它是否安装改变PRIMARY。REA不可用时保留原领域的其他工具路径和准确局限。

## 从理解到独立实现

分析保留目标身份、原始观察、解释及unknown。REA的会话内ID需连同官方Evidence bundle导出，不能只在聊天里留下短摘要。复刻规格使用Spec Kit原生FR/SC/US与任务ID，逐项引用已审查的依据；缺口保留为未知，用户新增设计单列。

进入实现前核身份、引用和关键unknown；原始证据能否支持需求仍须语义审阅与实测。`converge`检查实现是否满足spec/plan/tasks，不能证明规格本身符合原版。因此还要分别运行原版与我方实现，比较已约定的输出、错误处理、状态迁移及副作用，并检验独立交付能力。

官方REA中适用的ledger/coverage/verification结果继续按其schema使用；本仓交接检查只校验引用和完整性，不复制其closure算法，不伪造proof或semantic ID。改变需求版本、实现摘要或测试判据后，旧proof不可用于本次通过。

## 上游1.0到1.1：找回而非重做一切

追版固定三个对象：旧上游O、我方独立实现C、新上游N。先识别唯一旧项目，再比较O→N的上游变化、我方实现与设计差异，以及这些差异对N的适用性。不同语言或布局以规格、接口和行为对齐，不能把字节相似度当作等价。

我方UI和特色默认保留；本轮范围内的新功能进入新规格和测试。只重做失效部分，复用仍适用的实现与测试。旧地址/AOB命中仅是候选，不能跳过语义与新版回归。新记录沿原timeline/workitems/notes和Spec Kit feature关联旧记录；不创建Seep式新账本、不覆盖旧成品。

参见 [binary-diff](../skills/binary-diff/SKILL.md) 和 [自有追版练习](../examples/reconstruction-demo/README.md)。自有练习证明的范围仅为其中定义的CLI合同；不代表任意商业壳、真实APP或GUI已验证。

## 怎样继续补知识

直接要求“到网上补充完善知识库，优先复核过期方法和新经验”。按 [原生维护说明](../skills/references/knowledge-maintenance.md) 先读旧条目、找新来源、比较重复和反例，再小批蒸馏到所属references。真实研究经验沿field-journal回写，原索引和校验继续运行。

Windows实战优先，但Android/iOS、JS/HTTP/协议、签名/验证码、CTF/密码学、固件、取证、供应链、身份及其他原生领域持续保留。来源核对、结构检查、机制复现和真实目标成功分别记录；“已验证/未验证”附着到具体条目与适用条件。原有历史材料尚未逐条复核，不宣称全库都已验证。

## 使用话术

- “分析这个目标，把X功能复刻为独立项目，完成后与原版对比。”
- “继续上次项目，列出还没有依据的行为。”
- “上游更新到1.1了，保留我们的界面和特色，跟随更新并回归。”
- “只验证这次实现与原版的差异。”
- “把这次有用的经验整理进知识库。”

软件只能在明确材料、运行环境和声明范围内验收；缺件、未执行和未知在报告中保留，不用文件数量、退出码0或技能加载成功替代功能结果。原授权与scope声明继续生效。
