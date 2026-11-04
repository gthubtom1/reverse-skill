# JS VM/WASM 与浏览器爬虫观察（第二批）

## DK2-JS-VM-01：先定位执行边界，再还原指令集

**现象**：大型混淆 JS 可能包含普通业务代码、自定义 opcode VM、WASM 模块和服务端参数拼接。看到 `switch`、数组和位运算不能直接断言存在 VM。

**判定**：寻找加载路径、解释器入口、opcode dispatch、状态寄存器、常量表、WASM import/export、memory/table 使用和 JS↔WASM 调用点。对每个边界记录模块身份、加载时机、调用栈和输入输出。

**方法**：先用浏览器 Sources/Network/initiator 定位实际执行文件，再做静态 AST/字符串和运行时调用采样。把“发现解释器”“识别一个 opcode”“还原完整语义”分成三级结论，每级都有独立向量。

**边界/反例**：一个自定义 `switch` 可能只是状态机；一个 WASM export 被调用也不证明加密逻辑在 WASM 内。没有确定输入输出向量时保持未验证。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[WebAssembly Core Specification](https://www.w3.org/TR/wasm-core-2/)、[Chrome Network](https://developer.chrome.com/docs/devtools/network)；规范和工具文档已核，未对目标执行。

## DK2-JS-VM-02：JS 与 WASM 边界用确定性向量连接

**现象**：同一函数可能先在 JS 中编码，再把 ArrayBuffer 交给 WASM，最后把内存结果转成 token。只打印最终 token 无法知道差异发生在哪一层。

**判定**：分别记录 JS 输入、WASM import 参数、memory offset/length、export 返回值、读回字节和最终序列化。对每层使用固定输入向量和重复运行。

**方法**：在自有 fixture 中插入可观测边界，比较浏览器与独立实现的首个分歧；先复制字节与长度规则，再推导算法。若模块初始化依赖随机数或时间，显式固定或标记 residual unknown。

**边界/反例**：WASM 规范说明模块有独立 memory、table、imports 和 exports，但规范不告诉你具体应用如何编码参数。边界观察通过不等于算法复刻完成。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[WebAssembly Core Specification](https://www.w3.org/TR/wasm-core-2/)、[Playwright Network](https://playwright.dev/docs/network)；未运行具体目标。

## DK2-JS-VM-03：浏览器爬虫是动作—请求—状态图

**现象**：页面数据可能由 iframe、Service Worker、XHR/fetch、WebSocket、重定向和动态脚本共同产生。只抓一个 API URL，容易丢掉前置状态。

**判定**：每个页面动作关联 initiator、脚本/模块、请求、响应、storage 变化和下一动作。对 redirect 保留链，对 WebSocket 保留连接和消息方向，对 Service Worker 单独标记。

**方法**：用 Playwright route/response/request 观察和 HAR/trace 记录建立图；同一测试站点固定 viewport、浏览器版本、storage 初态和网络条件。用空状态、刷新、返回、重复点击验证图的可重现性。

**边界/反例**：Playwright 文档说明 Service Worker 可能影响网络事件观察，必要时需要显式控制；缺少事件不等于页面没有发出请求。

**方法评审：交叉核对（来源正文已核，已检查适用条件与反例；未做本方目标实测）。** **本方状态：未复现。**来源**：[Playwright Network](https://playwright.dev/docs/network)、[Chrome DevTools Network](https://developer.chrome.com/docs/devtools/network/reference)；方法已核，未运行目标站点。
