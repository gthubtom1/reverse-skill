# 高难 Android / 加固应用分析

本参考补充 `apk-reverse` 和 `mobile-reverse` 的原生流程。它保持 Java/DEX、native、运行时三层模型，不把 JADX、Frida、REA 或任何单一 provider 当成必备答案。

## 三层身份

每个 APK 先建立：

- 包 hash、版本、签名 scheme、证书摘要和 ABI；
- Manifest、DEX、资源、native libraries、动态加载点；
- Java/Kotlin → JNI → native → 运行时结果的引用关系；
- 设备、Android 版本、ART、root/模拟器状态和观察方式。

同一个功能可能跨三层实现。Java 入口存在不能证明业务逻辑在 Java；`.so` 存在也不能证明关键路径已经进入 native。

## 高难分支

### 动态 dex / 动态加载

记录 class loader、dex 路径、加载时机、内存映射和来源 hash。静态导出的 classes 为空或不完整时，标记覆盖范围；运行时导出的 dex 必须保留来源、时间和映射关系。不能把动态导出结果当作原 APK 的完整 classes。

### JNI 动态注册

记录 `RegisterNatives` 的类、方法名、签名、函数地址、模块基址、ABI 和注册时机。不要跨 ABI 复用固定槽偏移；不要把同名 overload 当成同一方法。类加载器和线程 `JNIEnv` 上下文必须独立记录。

### Flutter / Dart AOT

分开记录 `libapp.so`、Dart snapshot、ABI、engine/build 线索、platform channel 和 native bridge。snapshot 字符串或 URI 是候选线索，不等于完整 Dart 源码；版本不匹配时保留 unknown。

### Unity / IL2CPP

分开记录 `global-metadata.dat`、native binary、版本/ABI、metadata 解析覆盖和 native 地址映射。metadata method index、共享函数体和 native address 不可互相直接替代；没有同构 binary 时，地址结论保持未知。

### 反 Frida / root / 模拟器 / pinning

先区分检测类型：进程/端口、文件/属性、调试状态、时间、异常、证书链、网络代理和设备完整性。每个检测记录输入、输出、触发分支和观察者副作用。绕过一个检测不等于应用已正常运行；必须重新验证启动、关键请求、错误分支和 native bridge。

## 重打包验收

重打包、对齐、签名、安装和业务行为分开验收：

1. 原包/输出包 hash 和签名 scheme；
2. Manifest、资源、DEX、native ABI；
3. 安装和启动；
4. 关键功能和网络请求；
5. 错误、升级、证书校验和反调试分支；
6. logcat、崩溃和恢复路径。

“能安装”不能覆盖“签名正确、业务正确或所有设备兼容”。

## Evidence 最小集合

- `E-apk-identity`
- `E-signature-posture`
- `E-abi-dex-native`
- `E-jni-registration`
- `E-dynamic-loader`
- `E-flutter-aot` / `E-il2cpp-metadata`
- `E-runtime-detection`
- `E-repack-validation`
- `E-device-boundary`

## 失败转场

| 现象 | 不要下的结论 | 转场 |
|---|---|---|
| JADX 无类/方法 | APK 没有业务逻辑 | 检查加固、动态 dex、native 和 provider |
| Frida 启动即退出 | 应用没有功能 | 记录反 Frida/root/完整性候选，换最小观察或静态 |
| 类在 Java 层找不到 | 类不存在 | 检查 class loader、线程和动态加载 |
| Flutter 只有 Java 启动器 | 业务在 Java | 转 AOT、platform channel 和 native |
| metadata 能解析 | IL2CPP 已完整恢复 | 核对版本、native pairing、地址和方法体覆盖 |
| 重包能安装 | 复刻完成 | 继续启动、行为、错误和升级验证 |

## 方法状态

**方法评审：来源支持/交叉核对，按具体条目维护。**
**本方状态：未复现。** 本参考不宣称任何厂商加固、Flutter、IL2CPP 或反 Frida 目标已经完成闭环。

参考：OWASP MASTG、Android JNI/DEX 官方文档、AOSP APK Signing。目标设备、版本和 provider 必须在 case 中重新记录。
