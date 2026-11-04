# Windows PE 保护与脱壳证据（第二批）

## DK2-PE-01：TLS/入口事件先于普通入口断点

**现象**：程序可能在 OEP 或 main 之前通过 TLS callback、系统初始化或 DLL entry 执行反调试、解密或完整性检查。

**判定**：检查 PE TLS directory 的 AddressOfCallbacks、入口点、DLL entry 和系统断点事件；记录到达顺序、模块身份和是否在用户代码前退出。普通入口断点未命中不等于目标没有执行。

**方法**：用 PE 解析和调试器事件日志交叉确认。x64dbg 官方文档区分 System Breakpoint、TLS Callbacks 和 Entry Breakpoint；每次只把“已看到 callback”写成 observed，把“callback 是退出原因”绑定到实际路径证据。

**边界/反例**：TLS 目录存在不证明 callback 一定改变控制流；入口事件配置正确也不证明保护层已通过。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[x64dbg Events](https://help.x64dbg.com/en/latest/gui/settings/Events.html)、[Microsoft PE Format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)；官方正文已核。

## DK2-PE-02：反调试检测要记录触发与观察者副作用

**现象**：PEB、NtQueryInformationProcess、heap flags、debug registers、异常和时间检查可能互相叠加。调试器、插件、断点和进程启动方式也会改变被测状态。

**判定**：对每个检测点记录检测 API/字段、输入/输出、触发分支、观察者设置和前后状态。把“目标检测到调试器”和“工具改变了目标状态”分开。

**方法**：先静态定位候选，再用合成或公开 crackme 做对照：无调试、普通调试、不同事件暂停、反反调试插件。每个结果保留程序输出和调试器事件日志；不以插件存在证明检测已绕过。

**边界/反例**：Check Point Anti-Debug DB 和 ScyllaHide 能作为机制与工具参考，但具体保护器版本可能使用额外检查，不能把通用 PEB 处理写成完整绕过。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[Check Point Anti-Debug DB](https://github.com/CheckPointSW/Anti-Debug-DB)、[ScyllaHide](https://github.com/x64dbg/ScyllaHide)；来源已核，目标未执行。

## DK2-PE-03：OEP、dump 和 IAT 修复是三项不同结论

**现象**：内存中出现 `MZ` 或跳到一段新代码，可能只能证明出现了可疑映像；dump 后能被反汇编，也不等于导入表可运行。

**判定**：分别记录 OEP 候选的到达路径和语义、dump 的内存/文件布局覆盖、IAT slot/module/ordinal/forwarder 状态、修复后独立启动和关键 API 行为。

**方法**：先保留原始内存快照和地址映射，再做导入重建；对每项使用不同证据。修复失败时停止无限静态重试，转到动态 API 断点或保留未验证状态。

**边界/反例**：公开解包流程和 Scylla 文档能支持常见工作顺序，不能保证 Themida/VMProtect 虚拟化目标有单一干净 OEP。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[公开解包方法](https://inventivehq.com/blog/malware-unpacking-guide)、[x64dbg ScyllaHide](https://github.com/x64dbg/ScyllaHide)；方法来源已核，未执行目标。

## DK2-PE-04：商业壳要分档，不用“脱壳成功”统称

**现象**：UPX、压缩型保护、导入保护、代码虚拟化和完整性校验的可分析程度不同。VMProtect/Themida 可能只有局部语义能恢复，不能简单套用压缩壳流程。

**判定**：至少分为：识别保护、取得可分析镜像、修复导入、恢复局部函数语义、独立运行、去虚拟化。每档记录保护器版本、宿主位数、调试器和具体输出。

**方法**：先做静态体检和版本确认，再选择动态观察、控制流追踪或局部验证。遇到 Heaven’s Gate、直接系统调用、虚拟化 handler 或自校验时，记录新阻断并改变路线，不把公开 writeup 的成功条件扩展到未知版本。

**边界/反例**：公开 VMProtect 案例可说明跨位数、系统版本和 direct syscall 会改变路线，但只支持该案例条件；“能 dump”不等于“完整去虚拟化”。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[Defeating VMProtect’s Latest Tricks](https://cyber.wtf/2023/02/09/defeating-vmprotects-latest-tricks)、[Check Point Evasions](https://github.com/CheckPointSW/Evasions)；来源已核，目标未执行。
