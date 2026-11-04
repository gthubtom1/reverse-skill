# 三方追版：自有 CLI 练习夹具

这是一组本仓自行编写的教学源文件。它验证比较器、旧成果失效检出、更新后的业务回归和我方界面字段保留。它不代表商业壳脱壳、真实第三方程序复刻，亦不是 REA 或 Spec Kit 已运行的证明。

## 三方材料

- 旧上游：`original-v1.cjs`，支持整数列表求和。
- 我方旧成果：`replica-v1.cjs`，独立实现同一业务，额外保留 `ui.brand=My Lab`、`ui.theme=indigo`。
- 新上游：`original-v1.1.cjs`，新增折扣和计数，保留原求和与错误输入行为。
- 更新后我方成果：`replica-v1.1.cjs`，以独立循环实现新版合同，继续保留我方 UI 字段。

我方实现不导入或执行原版。`result` 是需要精确对照的业务对象，`ui` 是有意新增的我方设计，另作精确断言；这个边界在运行前固定，不临时过滤失败字段。

## 运行与判据

需要 Python 3.11+ 与 Node.js：

```sh
python examples/reconstruction-demo/run_demo.py --out work/follow-update-demo
```

可用 `--node <existing-node>` 选择已有运行时。程序只执行本目录公开、自有的源文件，将两侧原始 stdout/stderr、退出码、输入和比较结果写到输出目录。

通过条件同时包含：旧上游与我方旧成果的原用例一致；旧成果面对新上游产生至少一个真实不匹配；我方新版与新上游所有公开回归用例一致；我方 UI 字段保留；仅复制我方实现到干净目录后仍能执行。比较缺 JSON、非零退出或错误变体时不能按成功处理。

输出 `cases_are_public_regression_not_holdout=true`，因为这些样例全部公开，不能把它们宣传为独立留出集。干净目录复制仅证明无需项目相对位置的原版文件；`os_access_isolation_verified=false` 明确没有证明操作系统访问隔离。完整交付的独立环境验证见 [复刻技能](../../skills/reconstruction/SKILL.md)。

## 在真实项目中怎样使用

先恢复唯一旧 case 和原 Spec Kit feature，核对旧上游、我方实现/资产、构建与证据身份；比较新上游变化后修订受影响的规格和任务。旧需求版本、实现摘要或测试规则一变，旧 proof 就不再适用于本次交付。新版范围内新增功能漏做、我方界面丢失、候选旧项目有歧义或证据缺失，都应保留失败或未知。

本例没有创建第二套项目状态库，也没有生成 REA semantic ID。真实任务沿原 `scope.md`、`timeline.md`、`workitems.md`、Evidence 和 Spec Kit 产物记录，参考 [原生入口](../../skills/MASTER-ROUTING.md)。
