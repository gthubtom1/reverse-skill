# 注册协议与 HTTP 重放（第二批）

这些单元服务于自有程序、授权测试站和训练协议。当前均为**未验证**，HTTP 规范不能替代目标服务的实际状态机。

## DK2-PROTO-01：注册流程要画状态图

**现象**：注册通常不是一个 POST，而是初始化、发送验证码、校验 challenge、提交账号、设备绑定、登录和刷新等多个阶段。相同请求在不同会话状态下可能返回不同错误。

**判定**：为每个端点记录前置状态、输入字段、响应状态、产生的状态变化和下一步。至少区分 anonymous、challenge-issued、verified、registered、authenticated、refresh-needed 和 rejected。

**方法**：从浏览器 initiator、请求时间线和响应字段建立端点图；使用脱敏 HAR 或本地 mock 做单变量差分。每次只改变一个字段或一个状态，记录 400、401、403、409、429 等错误分支，不把错误页面当作成功。

**边界/反例**：页面加载顺序不一定等于服务端状态依赖；一个响应中出现 user id 也不证明注册完成，必须观察后续会话或业务查询。

**方法评审：来源支持（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)；规范已核，目标协议未运行。

## DK2-PROTO-02：canonicalization 是字节契约

**现象**：签名输入可能涉及 URL、query、重复键、header 大小写、空值、Unicode、JSON 数字和 body 编码。人眼相同的请求不一定拥有相同签名字节。

**判定**：保存签名之前的原始字节或可重建的输入，记录编码、排序、重复键处理、空格、换行和压缩。独立实现必须能生成相同的 canonical bytes，再比较摘要或签名。

**方法**：构造测试向量：键顺序互换、重复键、空键、Unicode、`+`/`%20`、数字格式、数组顺序和 body 空白。每个向量同时记录原始请求、规范化结果、签名输入摘要和接受/拒绝结果。

**边界/反例**：RFC 8785 只规定 JSON Canonicalization Scheme，不等于目标使用 JCS；WHATWG URL/Fetch 的解析和编码也不能直接替代应用自定义规则。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html)、[WHATWG URL](https://url.spec.whatwg.org/)、[Fetch Standard](https://fetch.spec.whatwg.org/)；原文已核，目标规则未复现。

## DK2-PROTO-03：原样重放和构造新请求是两种验收

**现象**：一个捕获请求能重放，并不代表已经理解协议；它可能依赖 Cookie、nonce、时间、服务端状态或浏览器自动添加的头。

**判定**：分别验收：A. 原样请求在相同会话和时间窗口重放；B. 只改变一个字段后服务端响应变化；C. 独立客户端从空状态构造新请求并完成状态迁移。

**方法**：固定会话、环境、请求顺序和重试策略。记录 redirect、Cookie 作用域、缓存、WebSocket/iframe/Service Worker 影响。对重放失败，先区分票据过期、状态缺失、字节变化和业务拒绝。

**边界/反例**：Playwright 把请求重定向链作为一个请求单元处理，cookie 仍来自 cookie store；因此拦截日志不能直接等同于线上原始报文。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[Playwright Network](https://playwright.dev/docs/network)、[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html)；文档已核，未运行目标站点。
