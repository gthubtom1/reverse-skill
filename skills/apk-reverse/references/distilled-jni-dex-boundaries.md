# Android：JNI 表、线程身份与 DEX 容器边界

本篇补足 [既有高级参考](android-advanced.md) 的 ABI 和文件格式前提，其中旧 ARM64 表偏移示例需按下文校正。引入批次：首批全领域增补；引入版本待独立 release PR 分配。本批只核公开原文，未连接设备或运行应用。

## DK-AND-01：RegisterNatives 用槽号和指针宽度定位

**现象→判定：** 按固定偏移定位后读出乱码方法表，应先怀疑 ABI 与间接层级。JNI 规范给出 `RegisterNatives` 的接口槽号为 215；函数表内字节偏移为 `215 × sizeof(void*)`，32 位为 `0x35C`，64 位为 `0x6B8`。

**方法：** 从 `JNIEnv*` 取得接口表，核对间接调用目标；按原型读取 `env, clazz, methods, nMethods`。包含 env 在内的第三个参数才是方法数组；AArch64 常规调用对应 x2，x3 为数量。随后把类、方法名、描述符、函数地址与模块加载基址关联，检查注册返回值。

**版本/边界/反例：** 依据 Java SE 24 JNI 规范；实际以目标 NDK 头文件与 ABI 复核。不能把 `0x35C` 标作 ARM64 偏移，也不能把“第三参数”误读成零起算的 `args[3]`。包装函数和自定义跳板须先还原原型。

**方法评审：来源支持（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。** 原文来源：[S04：RegisterNatives 原型、结构与槽号](https://docs.oracle.com/en/java/javase/24/docs/specs/jni/functions.html#registernatives)。

## DK-AND-02：类加载失败不等于类不存在

**现象→判定：** Java 层可调用的类，在原生线程 `FindClass` 却失败，可能是线程与类加载器上下文不同。Android 文档说明 `JNIEnv` 属于线程，不能跨线程共用；原生附加线程缺少应用 Java 调用栈时，类查找上下文可能不同。

**方法：** 记录当前线程、附加状态、异常和实际 ClassLoader；通过共享 JavaVM 为当前线程取得环境。需要跨调用保存类时，在正确加载上下文取得类并使用全局引用，按生命周期释放；逐次检查待处理异常后再解释结果。

**版本/边界/反例：** Android JNI 的线程与引用规则；不要把局部 `jclass` 或某线程的 env 缓存在全局反复使用。原生线程查找失败，不能反推 APK 没有该类；动态加载场景还需核加载时机。

**方法评审：来源支持（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。** 原文来源：[S05：Android JNI tips，Threads、引用与 FindClass](https://developer.android.com/training/articles/perf-jni)。

## DK-AND-03：DEX 魔数命中后仍要检查容器版本

**现象→判定：** 内存中发现 DEX 头但导出后解析失败，可能是边界或版本假设失效；魔数命中不能证明代码完整、可装载或未加固。

**方法：** 先记录魔数版本，按对应 header_size、file_size、容器字段解释边界，检查 map 与被引用区间。保留原始切片，再用支持该版本的解析器核结构；重新计算校验和只说明字节一致性，不能恢复未观测的方法体。

**版本/边界/反例：** 官方文档对 040 及更早版本规定头长 `0x70`，041 为 `0x78`，并引入 container_size/header_offset；041 在 Android 16 中标为实验用途、不用于生产。沿用旧头长并按 file_size 截断，可能漏掉共享数据；ODEX/VDEX 也不能直接套普通 DEX 规则。

**方法评审：来源支持（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。** 原文来源：[S06：DEX 文件与容器格式](https://source.android.com/docs/core/runtime/dex-format)。
