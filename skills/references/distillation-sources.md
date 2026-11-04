# 首批全领域增补：单元、来源与核对状态

本批次新增 24 个独立知识单元、10 篇领域短文；方法评审为来源支持 21、交叉核对 3；本方状态为未复现 24。本批未运行样本、solver、设备或业务接口；阅读作者文档与测试向量不算本方复现，也不把来源 HTTP 成功计入技术成功。

公开原文使用 Python urllib 只读 GET 核对，未上传私有材料。最终引用 **26 个不同 URL**，均取得正文并核对相关段落；初次访问另有 **2 个旧地址返回 404**，已分别换用 Apple 官方源码和 ECMAScript 正确章节，失败记录保留。最终引用中来源未核 **0**；这一数字不涵盖原存量。动态文档及 main 分支未来可能变化，仓外核对日志保留当次时间、响应摘要与语义摘记。

## 文件与现有模块的关系

| 所属模块与新增文件 | 单元 | 相对原材料的增量 |
|---|---|---|
| [Windows 入口与导入](../reverse-engineering/references/distilled-windows-entry-imports.md) | DK-WIN-01—03 | 入口四项证据、查询双通道及导入失败止损 |
| [Android JNI/DEX](../apk-reverse/references/distilled-jni-dex-boundaries.md) | DK-AND-01—03 | 校正旧 ARM64 表偏移；线程身份与 041 容器 |
| [iOS 元数据与运行前提](../mobile-reverse/references/distilled-ios-metadata-runtime.md) | DK-IOS-01—02 | 父类/元类枚举边界；加密与可调试性分离 |
| [JS 环境与签名字节](../js-reverse/references/distilled-environment-signature-bytes.md) | DK-JS-01—02 | Proxy 不变量；JCS 排序和表单编码差异 |
| [HTTP 状态与重放](../protocol-reverse/references/distilled-http-state-replay.md) | DK-HTTP-01—02 | Cookie 作用域与方法/重试语义 |
| [验证码证据](../browser-automation/references/distilled-captcha-evidence.md) | DK-CAP-01—02 | 事件捕获/合并；令牌消费与业务结果分层 |
| [CTF/密码学验证](../reverse-engineering/references/distilled-ctf-crypto-validation.md) | DK-CTF-01—03 | 位宽模型、认证负例与 found 的资格 |
| [固件 rehosting](../firmware-pentest/references/distilled-rehosting-assumptions.md) | DK-FW-01—02 | 宿主内核边界与 NVRAM 替身的分支偏差 |
| [数字取证](../digital-forensics/references/distilled-symbols-timeline.md) | DK-DF-01—02 | 符号精确匹配与时间格式选项冲突 |
| [供应链与云身份](../supply-chain-security/references/distilled-provenance-cloud-trust.md) | DK-SC-01—03 | 产物摘要、签名身份和 OIDC 信任分别验证 |

## 逐单元核对

“原文已核”表示相关正文支持所列事实；实验设计与反例推导仍未本方运行。所有行的“未验证”均指本方技术状态。

| 单元 | 原文来源 | 已核事实/章节 | 来源状态 | 本方状态 |
|---|---|---|---|---|
| DK-WIN-01 | [S01][S01] | 入口 RVA、TLS 回调目录 | 原文已核 | 未验证 |
| DK-WIN-02 | [S02][S02]、[S03][S03] | BOOL 返回与查询状态/输出 | 原文已核 | 未验证 |
| DK-WIN-03 | [S01][S01] | RVA/文件偏移、普通及延迟导入 | 原文已核 | 未验证 |
| DK-AND-01 | [S04][S04] | RegisterNatives 槽 215、原型和结构 | 原文已核 | 未验证 |
| DK-AND-02 | [S05][S05] | 线程环境、引用与类加载上下文 | 原文已核 | 未验证 |
| DK-AND-03 | [S06][S06] | 040/041 头长及容器字段 | 原文已核 | 未验证 |
| DK-IOS-01 | [S07][S07] | 本类枚举、父类查找与元类 | 原文已核 | 未验证 |
| DK-IOS-02 | [S08][S08]、[S09][S09] | 免越狱条件、加密命令字段 | 原文已核 | 未验证 |
| DK-JS-01 | [S10][S10] | Proxy Get 的不可配置属性限制 | 原文已核 | 未验证 |
| DK-JS-02 | [S11][S11]、[S12][S12] | UTF-16 排序、保留数组与空格编码 | 原文已核 | 未验证 |
| DK-HTTP-01 | [S14][S14] | Cookie 存储、选择与路径边界 | 原文已核 | 未验证 |
| DK-HTTP-02 | [S13][S13] | 幂等重试、303/307/308 | 原文已核 | 未验证 |
| DK-CAP-01 | [S15][S15] | 指针捕获、取消和合并事件 | 原文已核 | 未验证 |
| DK-CAP-02 | [S16][S16] | 两分钟、单次使用与合并错误码 | 原文已核 | 未验证 |
| DK-CTF-01 | [S17][S17] | 固定位宽及有/无符号运算 | 原文已核 | 未验证 |
| DK-CTF-02 | [S18][S18] | AEAD 完整向量与标签认证 | 原文已核 | 未验证 |
| DK-CTF-03 | [S19][S19] | found、deadended 与 unconstrained | 原文已核 | 未验证 |
| DK-FW-01 | [S20][S20] | 系统调用翻译、线程限制及 -L | 原文已核 | 未验证 |
| DK-FW-02 | [S21][S21] | 替代内核/NVRAM、网络推断副作用 | 原文已核 | 未验证 |
| DK-DF-01 | [S22][S22] | Windows PDB 身份、Linux banner | 原文已核 | 未验证 |
| DK-DF-02 | [S23][S23] | body 输入及 -y/-z 不兼容 | 原文已核 | 未验证 |
| DK-SC-01 | [S24][S24] | subject 摘要、builder 与参数策略 | 原文已核 | 未验证 |
| DK-SC-02 | [S25][S25] | bundle、identity 与 issuer 约束 | 原文已核 | 未验证 |
| DK-SC-03 | [S26][S26] | AWS aud/sub 与环境保护规则 | 原文已核 | 未验证 |

本批仅对相关原材料做增量比较，**原存量未逐单元复核、未重新统计技术验证状态**。旧错误示例因本批写集限制仍留在原文件，新增纠错不能理解为旧文已修订。原 SKILL、总导航、路由、版本、CI 与 journal 未改；本清单只作批次来源登记，不接管任务路由。后续集成导航点见维护说明，发布前仍需原完整 CI、索引与独立版本 PR。

[S01]: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
[S02]: https://learn.microsoft.com/en-us/windows/win32/api/debugapi/nf-debugapi-isdebuggerpresent
[S03]: https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationprocess
[S04]: https://docs.oracle.com/en/java/javase/24/docs/specs/jni/functions.html
[S05]: https://developer.android.com/training/articles/perf-jni
[S06]: https://source.android.com/docs/core/runtime/dex-format
[S07]: https://raw.githubusercontent.com/apple-oss-distributions/objc4/main/runtime/runtime.h
[S08]: https://frida.re/docs/ios/
[S09]: https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/EXTERNAL_HEADERS/mach-o/loader.h
[S10]: https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-proxy-object-internal-methods-and-internal-slots-get-p-receiver
[S11]: https://www.rfc-editor.org/rfc/rfc8785.html
[S12]: https://url.spec.whatwg.org/
[S13]: https://www.rfc-editor.org/rfc/rfc9110.html
[S14]: https://www.rfc-editor.org/rfc/rfc6265.html
[S15]: https://www.w3.org/TR/pointerevents3/
[S16]: https://developers.google.com/recaptcha/docs/verify
[S17]: https://microsoft.github.io/z3guide/docs/theories/Bitvectors/
[S18]: https://www.rfc-editor.org/rfc/rfc8439.html
[S19]: https://docs.angr.io/en/latest/core-concepts/pathgroups.html
[S20]: https://www.qemu.org/docs/master/user/main.html
[S21]: https://raw.githubusercontent.com/firmadyne/firmadyne/master/README.md
[S22]: https://volatility3.readthedocs.io/en/latest/symbol-tables.html
[S23]: https://www.sleuthkit.org/sleuthkit/man/mactime.html
[S24]: https://slsa.dev/spec/v1.2/verifying-artifacts
[S25]: https://docs.sigstore.dev/cosign/verifying/verify/
[S26]: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
