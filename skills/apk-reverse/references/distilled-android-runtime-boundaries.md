# Android 跨运行时边界（第二批）

## DK2-AND-RT-01：Android 逆向必须分 Java、native、运行时三层

**现象**：APK 的 Java/Kotlin、DEX、JNI native library、动态注册和运行时加载可能共同实现同一功能。只读 JADX 或只枚举 `.so` 都可能漏掉关键路径。

**判定**：先登记 APK 签名/版本/ABI、Manifest、DEX、native libraries、动态加载点和 JNI 注册；再把 Java 调用、JNI bridge、native 函数和结果回链。每层结论记录静态或运行时来源。

**方法**：按 Java API/Smali、native disassembly、JNI tracing 三路交叉。对动态注册记录 class、method、signature、library load 时机和地址映射，不把一个函数地址跨 ABI 直接复用。

**边界/反例**：OWASP MASTG 明确指出 Android 逆向需要同时处理 Java bytecode 和 native code，JNI 也可能被用来增加分析复杂度。文档覆盖不等于目标 APK 的壳已经拆开。

**状态**：未验证。**来源**：[OWASP MASTG Android Reverse Engineering](https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0013)、[Android JNI](https://developer.android.com/training/articles/perf-jni)；原文已核。

## DK2-AND-RT-02：Flutter/Dart AOT 是独立边界

**现象**：Flutter APK 主要逻辑可能位于 `libapp.so` 和 Dart AOT snapshot，Java 层只负责启动和平台桥。Java 入口存在不代表业务逻辑在 Java。

**判定**：登记 Flutter build/runtime、ABI、`libapp.so`、snapshot/符号信息、platform channel 和 native library。把 Dart AOT 静态恢复、平台通道观察和 Java 层行为分开。

**方法**：先解包并确认 native artifact 身份，再使用对应版本工具生成函数/字符串/调用线索；对关键行为用平台通道或运行时观察交叉验证。工具输出只作为候选，版本不匹配时保持 unknown。

**边界/反例**：OWASP MASTG 将 Flutter 逆向列为需要专门方法的场景；外部工具生成输出不等于完整源码恢复，也不等于重建包可运行。

**状态**：未验证。**来源**：[OWASP MASTG Flutter Reverse Engineering](https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0156)；来源已核，未运行具体 APK。

## DK2-AND-RT-03：签名、重打包与业务验证分开

**现象**：重打包后 APK 能安装，不能证明签名方案、资源、native ABI 或业务功能正确。Android 设备对 v1/v2/v3/v4 的支持和兼容条件不同。

**判定**：分别记录原包与输出包摘要、签名 scheme、证书摘要、ABI、安装结果、启动结果、关键行为和 logcat。任何一个环节失败都不能用安装成功覆盖。

**方法**：在测试 APK 上按官方流程生成签名，检查 v1/v2/v3/v4 适用范围，再做干净安装和功能对照。原证书私钥不进入知识库；公开知识只记录证书摘要/字段形状。

**边界/反例**：AOSP 文档说明不同 Android 版本对签名 scheme 的兼容不同；不能把“我在一个设备安装成功”推广成所有设备兼容。

**状态**：未验证。**来源**：[AOSP APK Signing](https://source.android.com/docs/security/features/apksigning)；来源已核，未运行设备。
