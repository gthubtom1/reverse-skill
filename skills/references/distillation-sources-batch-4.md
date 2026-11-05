# 外部蒸馏来源登记（Batch 4）

| 单元 | 外部来源 | 蒸馏内容 | 方法评审 | 本方状态 |
|---|---|---|---|---|
| DK4-PE-01~03 | [Seep-Reverse-Lab](https://github.com/angusdevgo/Seep-Reverse-Lab) `exe-reverse` references/evidence | 主机能力前置、AOB 四态裁决、等长 patch 和写入回读、PE 验证边界 | 来源支持/结构交叉核对 | 未复现 |
| DK4-ANTI-01 | [hack-skills anti-debugging-techniques](https://github.com/yaklang/hack-skills/tree/main/skills/anti-debugging-techniques) | 技术×平台×可靠性×误报矩阵、用户态/内核态边界、观察者副作用 | 交叉核对 | 未复现 |
| DK4-VM-01 | [hack-skills code-obfuscation-deobfuscation](https://github.com/yaklang/hack-skills/tree/main/skills/code-obfuscation-deobfuscation) 与 `vm-and-bytecode-reverse` | dispatcher、opcode、操作数、状态、trace/emulation/symbolic execution 选择 | 交叉核对 | 未复现 |
| DK4-OUTPUT-01 | Seep `exe-reverse` evidence/verification 结构与本仓 Evidence 契约对照 | 摘要/分页保留 identity、coverage、total 和 unknown | 流程契约 | 部分已有契约，目标未验证 |

许可证边界：Seep-Reverse-Lab 为 GPL-3.0，本批不复制其代码或大段文本；hack-skills 为 MIT，本批仍只写重新组织的概念和归属，不导入其代码/payload。外部仓库的安装器、宿主配置、反拒答逻辑和工作台状态不进入 reverse-skill。
