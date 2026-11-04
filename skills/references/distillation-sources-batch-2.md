# 第二批高难领域来源登记

本批新增 16 个独立知识单元，分布在 5 个 references 文件；方法评审为来源支持 6、交叉核对 10；本方状态为未复现 16。

| 文件 | 单元 | 本方状态 |
|---|---|---|
| browser-automation/distilled-challenge-session-state.md | DK2-CAP-01—03 | 未验证 3 |
| protocol-reverse/distilled-registration-protocol.md | DK2-PROTO-01—03 | 未验证 3 |
| js-reverse/distilled-jsvm-wasm-browser-observation.md | DK2-JS-VM-01—03 | 未验证 3 |
| apk-reverse/distilled-android-runtime-boundaries.md | DK2-AND-RT-01—03 | 未验证 3 |
| reverse-engineering/distilled-pe-protection-evidence.md | DK2-PE-01—04 | 未验证 4 |

## 来源与状态

本批来源正文已通过公开搜索结果核对；技术状态仍为未验证，因为本方没有在对应目标、设备、保护器版本或服务端上运行这些方法。

- Google reCAPTCHA verification: https://developers.google.com/recaptcha/docs/verify
- Google reCAPTCHA overview: https://developers.google.com/recaptcha
- W3C Pointer Events: https://www.w3.org/TR/pointerevents3/
- RFC 9110 HTTP Semantics: https://www.rfc-editor.org/rfc/rfc9110.html
- RFC 8785 JSON Canonicalization: https://www.rfc-editor.org/rfc/rfc8785.html
- WHATWG URL: https://url.spec.whatwg.org/
- WHATWG Fetch: https://fetch.spec.whatwg.org/
- Playwright Network: https://playwright.dev/docs/network
- Chrome DevTools Network Reference: https://developer.chrome.com/docs/devtools/network/reference
- OWASP MASTG Android Reverse Engineering: https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0013
- OWASP MASTG Frida Android: https://mas.owasp.org/MASTG/tools/android/MASTG-TOOL-0001
- OWASP MASTG Flutter: https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0156
- Android JNI: https://developer.android.com/training/articles/perf-jni
- AOSP APK Signing: https://source.android.com/docs/security/features/apksigning
- WebAssembly Core Specification: https://www.w3.org/TR/wasm-core-2/
- x64dbg Events: https://help.x64dbg.com/en/latest/gui/settings/Events.html
- Microsoft PE Format: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
- Check Point Anti-Debug DB: https://github.com/CheckPointSW/Anti-Debug-DB
- Check Point Evasions: https://github.com/CheckPointSW/Evasions
- ScyllaHide: https://github.com/x64dbg/ScyllaHide
- VMProtect public case: https://cyber.wtf/2023/02/09/defeating-vmprotects-latest-tricks
- Public unpacking method overview: https://inventivehq.com/blog/malware-unpacking-guide
- crackmes.one FAQ: https://crackmes.one/faq

公开资料只用于蒸馏现象、判定条件、边界和实验设计。没有复制原文，也没有把作者报告、HTTP 200、工具安装或公开 writeup 成功写成本方已验证。

## 未覆盖的高难空档

- 具体站点的验证码票据复算和风控通过率：需要授权测试站/本地 mock 与服务端结果。
- WASM/自定义 JS VM 的真实字节码还原：需要带版本和输入向量的样本。
- 注册/登录/设备绑定协议的业务接受：需要脱敏 HAR/PCAP 或自有服务端。
- Android 加固、Flutter snapshot、RN/Hermes 和 iOS 设备动态链：需要对应 APK/IPA、ABI、设备和运行时。
- VMProtect/Themida 具体版本的 OEP/IAT/独立运行闭环：需要公开 crackme 或自有测试 PE；本批只补方法边界。

原有第一批 24 个单元继续单独统计；原存量知识没有因为本批新增而自动升级验证状态。
