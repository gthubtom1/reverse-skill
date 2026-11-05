# 高难 JS / WASM / 浏览器分析

本参考补充 `js-reverse` 的 Observe → Capture → Rebuild → Patch → DeepDive。它不绑定某个浏览器 MCP 或 provider，工具名称和实际能力以当前客户端资源清单为准。

## 先找执行边界

大型混淆脚本可能同时包含普通业务、JS VM、WASM、Web Worker、Service Worker、iframe、native addon 和远程状态。`switch`、数组和位运算只能产生假设，不能直接证明存在 VM。

必须分别定位：

- 脚本和模块来源、动态 import、SourceMap 状态；
- XHR/Fetch/WebSocket、redirect、cookie/storage 和 initiator；
- Worker/Service Worker/iframe 的加载与消息边界；
- JS → WASM import、memory/table、export 和读回字节；
- 设备、时间、随机数、crypto、canvas 或 storage 依赖。

## JS VM / WASM 分级结论

把结论拆成三层：

1. 找到解释器/模块边界；
2. 用固定输入识别一个 opcode、handler 或 memory 变化；
3. 用多个向量还原完整语义并与浏览器结果一致。

只有第 3 层完成，才可以称为算法链路复现。单个 `switch`、一个 WASM export 或最终 token 都不足以证明 VM/算法已还原。

## 浏览器状态图

每个动作关联：

```text
动作 → 页面/iframe/worker → initiator → 请求/响应 → redirect
     → cookie/storage/WebSocket → 下一状态
```

固定浏览器版本、viewport、storage 初态、权限、网络条件和时间/随机数策略。Service Worker 可能改变网络观察；没有看到某个请求不证明页面没有发出该请求。

## 签名和本地重建

对每层保存确定性向量：

- 原始 URL、query、header/body 字节；
- canonicalization 后字节摘要；
- JS 函数输入输出；
- WASM offset/length、memory bytes、export 返回值；
- cookie、nonce、时间和随机数来源；
- 浏览器结果与 Node/独立实现的 first divergence。

对 query 排序、重复键、空值、Unicode、`+`/`%20`、JSON 数字、数组顺序、压缩和 header 大小写做单变量差分。原样请求重放、单字段修改和空状态独立构造是三个不同验收级别。

## Evidence 最小集合

- `E-web-artifact`
- `E-script-source-map`
- `E-request-initiator`
- `E-browser-state`
- `E-js-vm-boundary`
- `E-wasm-boundary`
- `E-canonical-bytes`
- `E-signature-vector`
- `E-first-divergence`
- `E-replay-variant`

## 失败转场

| 现象 | 不能下的结论 | 转场 |
|---|---|---|
| 找到混淆 switch | 已找到 VM | 追 interpreter、state、opcode 和向量 |
| 最终签名能打印 | 已理解算法 | 分层采样并找 first divergence |
| 浏览器抓不到请求 | 没有网络请求 | 检查 worker、Service Worker、iframe、缓存和连接类型 |
| Node 补环境反复失败 | 算法不可复现 | 回浏览器采集真实依赖，最小补一个缺口 |
| WASM export 可调用 | JS 算法全在 WASM | 记录 import、memory、读回和序列化边界 |
| 一次请求重放成功 | 已理解协议 | 做字段变更、空状态和错误变体 |

## 方法状态

**方法评审：交叉核对/来源支持。**
**本方状态：未复现。** JS VM、WASM、Service Worker 和真实风控站点需要具体 fixture/目标验证。

参考：WebAssembly Core Specification、WHATWG URL/Fetch、Chrome DevTools Network、Playwright Network。目标工具名和 MCP 能力不由本参考固定。
