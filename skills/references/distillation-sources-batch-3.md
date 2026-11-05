# 高难逆向增量来源登记（Batch 3）

本批对应五个 provider-neutral 高难参考模块。来源登记不等于本方目标验证；每个模块仍保留“方法评审”和“本方状态”两条轴。

| 单元 | 目标 | 主要来源 | 方法评审 | 本方状态 |
|---|---|---|---|---|
| DK3-PE | PE 保护层、TLS/早期事件、OEP/dump/IAT、虚拟化和反调试证据 | Microsoft PE Format；x64dbg Events；ScyllaHide；Check Point Anti-Debug-DB；Cyber.wtf VMProtect 研究 | 交叉核对/来源支持 | 未复现 |
| DK3-ANDROID | 动态 dex、JNI、Flutter/IL2CPP、反观察、重打包验收 | OWASP MASTG；Android JNI；Android DEX Format；AOSP APK Signing | 交叉核对/来源支持 | 未复现 |
| DK3-JS | JS VM/WASM、浏览器状态图、Service Worker/WebSocket、canonical bytes | WebAssembly Core Specification；WHATWG URL/Fetch；Chrome DevTools Network；Playwright Network | 交叉核对/来源支持 | 未复现 |
| DK3-PROTO | 注册状态机、帧/序列化、nonce/重连、canonicalization、三层重放 | RFC 9110；RFC 8785；WHATWG URL/Fetch；Playwright Network；Protobuf 编码文档 | 交叉核对/来源支持 | 未复现 |
| DK3-FAILURE | provider-neutral 缺件、早退、观察副作用、部分输出和 schema 失败 | 原 reverse scope/Evidence 契约、REA/工具接口公开限制、现有失败证据规范 | 流程契约 | installer/目标任务分别验证 |

本批不改变 routing.json，不新增 PRIMARY，不复制官方 REA/Spec Kit 内容。来源正文、版本和具体适用条件在实际 case 中重新核对；公开文档中的成功案例不能升级本方验证等级。
