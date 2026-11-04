# 验证记录 / Validation record

本记录仅覆盖 `skills/reconstruction/` 自身。源码文件限 Markdown/Python/JSON；样例完全合成脱敏，无真实目标、二进制、真实 REA 导出或伪造 semantic ID。未执行 git add/commit/push；共享路由、工具发现、原 tests/CI 和 installer 均由主流程集成。

## 已执行

运行环境：Windows，Python 3.12.0。命令相对技能包根：

```text
python -B -m unittest discover -s skills/reconstruction/tests -p "test_*.py" -v
```

实际结果：`Ran 31 tests`、`OK`，31 通过，0 失败，0 跳过。测试覆盖：

- bundle/原观察篡改、spec/obligation 文档过期 SHA、摘要格式；
- 绝对路径、盘符/UNC/URI、遍历、Evidence artifact 越 case、实际符号链接越项目；
- 缺原 E 文件、错误 heading、拿 notes 副本替代原 Evidence、空引用；
- FR 缺项/重复/错号、跨冻结 feature 混用、错 case context；
- 显式关键 unknown 阻断、unknown 字段/JSON pointer/对象完整性；
- obligation_ref 缺失、ID/version 缺件或非法类型、RFC 6901 转义；
- JSON 重复键/格式/类型错误、拒绝把 status 存入清单；
- 故意错误码错引的机械通过边界、遗漏 unknown/错误来源资格需独立审阅；
- CLI 退出 0/1/2、JSON/Markdown、help/参数错误；
- 真实 CLI 子进程不执行 repro_command 哨兵，并以全部文件字节快照确认项目未被改写。

样例命令：

```text
python -B skills/reconstruction/scripts/check_handoff.py skills/reconstruction/examples/synthetic-project case-fixture/demo/notes/handoff-manifest.json --format json
```

实际结果：退出 0；`status=PASS`、`assessment_scope=machine_check_only`、`semantic_verification=not_performed`、`target_execution=not_performed`、`authorization=not_assessed`；检查 10 个被引用文件，并列 FR-001 独立语义审查要求。

静态检查实际通过：所有本地 Markdown 链接可解析、JSON 可解析、Python 3.9 grammar 可解析、无外部工作区路径依赖、源文件只有 `.md/.py/.json`、样例源文件不被原 `work/` 忽略规则遮蔽。Python 3.9 runtime 未实测，语法检查不等于该运行时通过。

## 明确未验证

- REA 正式安装版 `binary_session` / `tools/list` / schema、官方 provider 与生产接口实际调用；这里只核对了官方 README 及其契约文档。
- 真实 REA bundle 认证、语义支持、authority、proof applicability、obligation/coverage closure；薄脚本有意不实现这些判据。
- Spec Kit 官方命令、analyze/converge 与宿主加载的实际任务执行。
- 自有程序 O/C/N 1.0→1.1 端到端、UI 保留、新功能覆盖、旧 proof 失效、错误变体/同源拒绝、干净隔离构建及回滚；参考文档已列执行步骤与反例，但不是实测回执。
- 原完整路由/原 tests/CI、索引生成及暂存区检查；本分工不修改这些文件，也未运行可能改写共享生成物的操作。

原 case-review 已只读核对实现；本脚本不调用或复制其图审查。合成 scope 为 document-only 且 readiness=false，机械样例 PASS 不改变此授权边界。

## 主流程集成点

1. 以原 `routing.json` 接入单一 reconstruction PRIMARY，保持旧路由顺序/期望；混合意图先原领域，再同 case 明确阶段 Hint。不要在此脚本加路由器。
2. 同步原 MASTER/导航/生成 INDEX；按官方能力登记实际 REA/Spec Kit 工具资格，不把宿主适配塞入技能目录。
3. 在原检查保留的基础上增量执行上述 unittest；暂存与生成器由主流程负责。
4. 采用 [handoff-manifest v1](references/handoff-manifest.md) 的一次性交接投影，与原 case-review、真实 Evidence 生产者、官方 REA schema 和原生 Spec Kit feature/tasks 对接。
5. 独立 installer 处理版本/安装/宿主配置；独立验证阶段执行真实行为对照与追版反例，逐项报告支持/未知/未执行。
