# Provider-neutral 失败矩阵

本矩阵属于 reverse 的操作契约，不绑定 REA、IDA、Ghidra、JADX、Frida 或某个 AI 宿主。它规定工具/分析 provider 不可用时如何保持证据链和换路，而不是规定如何安装 provider。

## 状态分类

| 状态 | 含义 | 可继续动作 | 不可宣称 |
|---|---|---|---|
| `missing_tool` | 命令或 MCP tool 不存在 | 读 tool-index，选择已安装替代路径 | 已执行该工具 |
| `missing_provider` | 工具存在，但分析引擎/许可证/JAR/设备缺失 | 目标无 provider 的静态路径、记录补件 | 目标分析已完成 |
| `stale_registration` | 配置存在但宿主资源未加载/工具清单过期 | 重连或由 installer 诊断 | 当前会话已接通 |
| `schema_mismatch` | 工具返回结构与契约不一致 | 读取当前 schema、停止重复调用、换已支持入口 | 结果可信 |
| `target_unsupported` | 格式/版本/架构不支持 | 保存身份和 unsupported 证据，找对应入口 | 目标没有该能力 |
| `target_early_exit` | 目标启动即退出/反调试触发 | 保存退出路径、静态观察、降低扰动或换环境 | 目标无功能/无行为 |
| `observer_side_effect` | 调试器、DBI、代理或 hook 改变目标状态 | 对照无观察/最小观察/当前观察 | 观察结果等于原始行为 |
| `license_or_engine_boundary` | 商业工具或外部 engine 不能使用 | 选择开源/静态/离线替代，明确覆盖差异 | 替代路径等价 |
| `output_partial` | 工具只返回分页、截断或部分覆盖 | 保存 coverage、分页和 unknown，继续或换工具 | 已穷尽目标 |

## 统一记录字段

每次失败写入原 case 的 Evidence/timeline/workitems：

- 目标身份、输入 hash、格式/架构/版本；
- tool/provider 名称和版本（若可得）；
- 请求/命令摘要，不写凭据；
- 原始错误分类和 remediation；
- 已覆盖与未覆盖范围；
- 观察者副作用；
- 下一候选路径和停止条件；
- `confidence`、`quality`、`unknowns`。

## 转场规则

1. 同一命令和相同参数失败两次后，不再原样重试。
2. provider 缺失时先完成可用的目标身份、文件布局、字符串、签名、资源或协议静态观察。
3. native provider 缺失时可以交给另一已确认 provider，但必须标记输出差异和覆盖范围。
4. JADX/Frida/浏览器/PCAP 等专用 provider 缺失时，不能用普通文件存在或安装包版本冒充能力已接通。
5. MCP catalog 通过只证明工具可见；代表任务仍需要独立 Evidence。
6. 目标早退时保存退出路径和观察条件；不把“没有看到行为”写成“没有行为”。
7. 观察扰动无法排除时，优先静态证据、最小 hook 和状态对照；无法分离时保持 unknown。

## 与安装器的边界

安装、版本、宿主资源、MCP initialize/tools/list 和 provider doctor 属于独立 installer；本矩阵只规定 reverse 在收到结果后如何判断和转场。reverse 可以单独使用，没有 REA/Spec Kit/installer 也不应失效。

## 方法状态

**方法评审：流程契约。**
**本方状态：本机已验证的安装/MCP结果只登记在 installer 验收中；本矩阵不把任何 provider 的安装状态复制为领域目标验证。**
