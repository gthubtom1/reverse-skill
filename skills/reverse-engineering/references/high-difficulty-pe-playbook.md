# 高难 PE / 保护器分析

本参考补充原 `reverse-engineering` 的 Triage → Static → Dynamic → Synthesis，不替代原阶段门闩，也不承诺万能脱壳器。适用范围是授权离线样本、实验室目标和明确授权设备。

## 保护层分档

| 分档 | 可观察现象 | 目标结论必须分开记录 |
|---|---|---|
| 结构异常 | 熵、overlay、节表、入口、导入异常 | 保护/加载器候选，不等于已识别壳 |
| 压缩/加载器 | 入口跳转、解密循环、运行时模块映射 | 已观察加载阶段和可分析映像候选 |
| 导入保护 | 导入很少、API hash、延迟解析 | 动态解析证据；不能由静态导入否定能力 |
| 自校验/反篡改 | 文件 hash、大小、签名、校验失败早退 | 校验点、输入、分支和失败时机 |
| 控制流混淆 | dispatcher、状态变量、opaque predicate、CFF | 局部语义、状态转移或未恢复 |
| 虚拟化 | handler table、VM context、opcode、解释循环 | VM 边界、局部 opcode 语义、是否完成去虚拟化 |

壳名称只是候选线索。版本、架构、编译器、宿主 Windows 和观察方式必须绑定到每个结论。

## Evidence 最小集合

- `E-pe-identity`：SHA-256、格式、位数、入口、节/段、overlay、TLS、异常目录。
- `E-protection-hypothesis`：保护层候选、依据、反例和置信度。
- `E-import-quality`：导入/导出、API hash/动态解析嫌疑、解析质量。
- `E-early-events`：system breakpoint、TLS、入口、DLL entry 的到达顺序。
- `E-runtime-map`：模块、内存区段、权限、映射时间和来源。
- `E-oep-candidate`：候选到达路径和语义；不能只凭地址命名 OEP。
- `E-dump-layout`：来源内存区间、文件偏移映射、节边界和 hash。
- `E-iat-repair`：slot、模块、ordinal/forwarder、修复工具和独立启动结果。
- `E-anti-analysis`：检测 API/字段、输入输出、触发分支、观察者设置。
- `E-self-check`：校验输入、算法/调用链、失败时机和副本状态。
- `E-vm-boundary`：dispatcher、handler、VM context、opcode 候选和向量。

## 分支规则

1. 原始文件只读；所有 dump、patch、修复和解密结果写入 case 副本。
2. 入口和导入正常时先静态；静态深挖有时间盒，超时进入动态验证。
3. 导入异常时先记录质量，不得写成“无网络/无文件能力”。
4. 观察到 TLS、loader 或早退时，先建立事件顺序，再选择断点。
5. OEP、dump、IAT 修复、可运行副本和局部语义是五个不同结论。
6. IAT 修复工具报错、修复后闪退或怀疑自校验时，停止静态文件反复修补，记录失败并转运行时 API/内存路径。
7. VM 目标先恢复目标函数的局部状态转移；完整去虚拟化只有在 opcode、handler、状态和回归向量都足够时才可宣称。
8. 反调试处理必须比较无观察、最小观察和当前观察三种状态；工具触发早退不能被写成样本无功能。

## 失败转场

| 失败 | 必须保留 | 下一步 |
|---|---|---|
| 导入表为空/乱码 | 原始输出和 `quality=packed/unreadable` | 动态 API/解析器观察 |
| OEP 候选不稳定 | 入口跳转路径和运行时映射 | 多次受控运行或模块加载观察 |
| dump 能反汇编但不能运行 | 文件映射、IAT、TLS、异常目录、校验失败 | 局部内存分析，不继续盲修 |
| 调试器触发早退 | 退出点、检测输入、观察者差异 | 降低扰动或更换隔离环境 |
| VM handler 无法完整命名 | handler trace、opcode 向量、局部结果 | 只做目标函数语义，不宣称全量还原 |

## 方法状态

**方法评审：交叉核对/来源支持，按条目来源核对。**
**本方状态：未复现。** 本参考提供决策、证据和失败转场；不代表任意 VMProtect、Themida、商业加固或自定义保护器已在本方完成脱壳。

参考：Microsoft PE Format、x64dbg Events、ScyllaHide、Check Point Anti-Debug-DB、公开 VMProtect 研究。具体来源和版本要在 case 中重新登记。
