# 高难协议与重放分析

本参考补充 `protocol-reverse` 的帧、序列化、加密和状态机流程。它只描述本地样本、脱敏 capture 和授权目标，不把重放成功当作协议理解完成。

## 先画状态机

注册、登录和业务协议通常不是一个 POST。至少区分：

```text
anonymous → initialized → challenge-issued → verified
          → registered → authenticated → refresh-needed
          → rejected / rate-limited / expired
```

每个端点或消息记录前置状态、输入、响应、状态变化、下一步、重试和错误分支。页面加载顺序不等于服务端状态依赖。

## 帧和编码层

按层保存：

1. 方向、连接、stream、序号和时间；
2. 魔数、版本、长度、flags、opcode、checksum/CRC；
3. 压缩、分片、重组和加密边界；
4. Protobuf/gRPC/MessagePack/自定义字段；
5. nonce、密钥派生、canonicalization 和签名输入；
6. 业务状态和错误语义。

同一字段的显示值、原始字节、解码结果和推断标签要分开。未知长度、截断、丢包和未解密字段保持 unknown。

## 三种验收

- **A 原样重放**：同会话、同时间窗、同请求序列能否重现结果；
- **B 单变量差分**：只改变一个字段、状态、nonce 或编码，观察响应变化；
- **C 独立构造**：从空状态建立新连接/会话，独立生成消息并完成状态迁移。

A 通过不代表已经理解协议；C 通过才接近独立实现。重连、心跳、乱序、429、401、403、409、过期和服务端拒绝必须单独记录。

## Protobuf / WebSocket / HTTP 交叉

- Protobuf：保存字段号、wire type、长度、未知字段和 schema 置信度；`decode_raw` 输出不是业务 schema。
- WebSocket：记录握手、方向、message boundary、压缩扩展、ping/pong、重连和共享 cookie/storage。
- HTTP：记录 redirect、cookie scope、cache、header/body 原始字节和编码；不要把工具生成的请求等同于浏览器原始请求。
- canonicalization：对键顺序、重复键、空值、Unicode、数字、空白、压缩和 header 大小写建立向量。

## Evidence 最小集合

- `E-transport-identity`
- `E-frame-layout`
- `E-message-dictionary`
- `E-state-machine`
- `E-serialization`
- `E-crypto-boundary`
- `E-canonical-bytes`
- `E-replay-original`
- `E-replay-variant`
- `E-independent-construction`

## 失败转场

| 现象 | 不能下的结论 | 转场 |
|---|---|---|
| 原样请求重放失败 | 协议不可理解 | 区分票据过期、状态缺失、字节变化和业务拒绝 |
| `decode_raw` 有字段 | 已恢复 schema | 对齐多条消息、类型、状态和未知字段 |
| 注册 POST 返回 200 | 注册完成 | 观察后续会话/业务查询和状态变化 |
| WebSocket 没有消息 | 没有业务通道 | 检查连接时间、压缩、worker、重连和 capture 覆盖 |
| 签名相同但服务拒绝 | 算法错误 | 检查 nonce、会话、时间、权限、canonicalization 和状态 |

## 方法状态

**方法评审：来源支持/交叉核对。**
**本方状态：未复现。** 具体协议、版本、capture 和服务端状态必须在 case 中绑定。

参考：RFC 9110、RFC 8785、WHATWG URL/Fetch、Playwright Network、Protobuf 官方编码文档。
