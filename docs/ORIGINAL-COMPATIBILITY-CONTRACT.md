# 原版兼容契约

本仓库是原 `reverse-skill` 的增量发行版。扩展必须继续使用原项目的行为链、路由事实源和阶段契约；新增能力通过参考资料、现有 skill 的增量章节、独立 fixture 或客户端适配完成。

## 不变量

- `skills/config/routing.json` 仍是唯一运行时路由事实源。
- 原有路由的相对优先级、fallback 和原始 benchmark 输入保持不变。
- 原有 PRIMARY 入口继续负责自己的领域；新阶段只能在原领域完成分析后交接。
- `RULES.md` 的 scope/auth 硬门、`field-journal`、timeline/workitems 和 Evidence→Finding→Path 契约继续有效。
- reverse-skill 可以单独使用；REA、Spec Kit 和任意宿主适配都不是本仓的硬运行时依赖。
- 官方 REA 和官方 Spec Kit 的源码、包和行为不在本仓修改范围内。
- 安装、宿主资源选择、MCP 注册、MCP 握手和组合验收属于独立 installer 仓库。

## 允许的增量

- 为困难目标增加 provider-neutral 的决策框架和参考资料。
- 在现有领域 skill 中补充样本分诊、静态/动态转场、失败证据和适用条件。
- 增加不改变旧期望的 benchmark 用例，或为新阶段增加独立测试。
- 通过原有 route/skill 入口调用可选分析 provider；provider 不可用时保留原有 fallback 和 unknown。
- 在 installer 中增加组件选择、适配、诊断和验收，不把这些逻辑复制到 reverse。

## 禁止的改变

- 为了新功能重排原有 PRIMARY 优先级。
- 把 REA MCP、Spec Kit CLI 或某个宿主注册命令写成 reverse 的必备前提。
- 在 reverse 内复制官方工具实现、安装器、宿主配置或 MCP 握手代码。
- 用目录数量、文件存在或安装回执替代目标任务的 Evidence 和真实验证。
- 把某个壳、反调试或混淆样本的成功路径描述成所有样本的固定流程。

每次变更后至少运行原路由回归、原版兼容契约检查和结构一致性检查；CI 中失败时不得通过删除断言或降低验证范围来让结果变绿。
