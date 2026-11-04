# 交接指针清单 / Handoff manifest

`check_handoff.py` 只做不执行的机械检查。它不运行目标、repro_command、verifier、REA、Spec Kit 或 case-review，不联网、不安装、不写文件；唯一输出为 stdout。原 case-review 必须单独运行，本清单不替代原图审查、scope 授权门禁或语义审查。

## 调用与退出码

在技能包根调用，`project_root` 为显式成果项目根；`manifest` 必须是相对该根的路径：

```text
python -B skills/reconstruction/scripts/check_handoff.py <project_root> work/<case>/notes/handoff-manifest.json
python -B skills/reconstruction/scripts/check_handoff.py <project_root> work/<case>/notes/handoff-manifest.json --format markdown
python -B -m unittest discover -s skills/reconstruction/tests -p "test_*.py" -v
```

- 退出 0：选定清单的机械检查 PASS，仍需语义评审；不表示可以 ACT 或实施。
- 退出 1：输入/引用/文件/SHA/完整性失败，或声明了关键未解决 unknown；JSON/Markdown 给首个确定错误。
- 退出 2：argparse 参数错误（缺参数、无效 format、未知参数）；`--help` 退出 0。

`assessment_scope` 始终为 `machine_check_only`，`semantic_verification` 与 `target_execution` 始终为 `not_performed`，`authorization` 始终为 `not_assessed`。输出未校验的语义 review 项与限制，MUST NOT 将 PASS 改写为 semantic verified。

## 清单格式 v1

完整可运行的脱敏合成例位于 [synthetic-project](../examples/synthetic-project/README.md)。该例的 bundle/obligation 仅为清单格式夹具，明确不是真实 REA 导出或语义 ID；不能输入官方验证工具冒充 Evidence。

所有文件指针均为 `{"path": "项目内相对路径", "sha256": "小写64位hex"}`。摘要固定原始文件字节（无规范化，无 `sha256:` 前缀）。文件变化必须按权威材料重建清单，MUST NOT 为掩盖篡改直接刷新摘要。脚本校验当前文件相对供应摘要的完整性，不能发现调用方选择了旧版本或同时重写文件和摘要；版本/来源真实性与适用性由独立审查负责。

| 顶层键 | 内容与检查 |
|--------|------------|
| `manifest_version` | 整数 1 |
| `case_root` | 项目内现有 case 目录相对路径 |
| `context_refs` | `scope`、`timeline`、`workitems` 三个文件指针，必须恰为所选 case 原文件 |
| `feature_refs` | `spec`、`plan`、`tasks` 文件指针，必须在同一 `specs/<feature>/`，文件名按原生约定 |
| `bundle_refs` | 至少一个原始完整 bundle 文件指针；只核文件 SHA，不认证/解析 REA schema |
| `requirements` | 所选 spec 中全部原生 FR 的唯一映射数组，不允许重复、漏项或未知 FR |

FR 检出按 `FR-` 加至少三位数字的文本 token；不理解文档语义或原模板 AST。选定 spec 中出现的 FR token 都必须映射，说明文字中的外部 FR 宜用文件路径/链接表达并审查 token 范围。SC/US/任务追溯由原生文档与 analyze 审查，首脚本只机械核 FR。

每项 requirement 必须且仅包含：

| 字段 | 内容 |
|------|------|
| `fr_id` | 原生 FR，如 `FR-001`，必须在所选 spec 中出现 |
| `source_kind` | `observed`、`inferred`、`unknown` 或 `designed`，是调用方来源分类，不由脚本升格 |
| `evidence_refs` | 至少一个 `{"evidence_id": "E-001", "record_ref": 文件指针}`；designed 引用用户设计决定的原 E 材料 |
| `obligation_ref` | `{"document_ref": 文件指针, "pointer": "/obligations/0"}`，指向原生输出中带非空 obligation_id 和正整数 obligation_version 的对象 |
| `unknown_refs` | 必填数组；元素为 `{"document_ref": 文件指针, "pointer": "/unknowns/0", "critical": 布尔值}`，指向权威原材料；无未解决依赖时为 `[]` |

`critical` 是此次交接对仍未解决 unknown 的影响判定，MUST 经审阅并在权威 notes 引用依据。任一 true 会阻断本清单；脚本不读取 unknown 内部状态、不解依赖、不接受本地 `resolved` 开关。已解决项必须先在原工具/原记录处理，再经审阅去除旧的未解决引用；不得把 critical 改 false 凑绿。非关键 unknown 保留引用与限制。

只有受影响功能受阻；其他独立 feature 可用各自清单继续，不得从同一所选 spec 中漏掉 FR 来通过。所有 source_kind 都仍需语义评审，inferred/unknown 通过机械检查不代表可实施。

## 路径、Evidence 与 JSON pointer

清单内路径统一项目根相对 `/`，禁止绝对路径、盘符/URI、反斜杠、空段、`.`、`..` 和控制字符。解析链接/junction 后也必须留在所选根内；Evidence 的 artifact_path 则相对原 case，并同样防越界。文件必须存在且摘要一致。

E 引用 MUST 指向 `work/<case>/evidence/<E-id>.md` 原文件，heading 必须一致且唯一。脚本核原文件 SHA，再核其 `artifact_path` 与 `content_hash`（允许原契约的 `sha256:`）；未固定 artifact 不满足交接。它不解析 Finding 状态/authority、不查原生 bundle membership，不认证 bundle 的 evidence_id；这些由 case-review、REA 正式读取与独立语义审查承担。脚本不会生成任何 native Evidence/semantic ID。

JSON pointer 遵 RFC 6901，必须非根 `/...`，支持 `~0`、`~1` 与数组索引，引用文档也须 SHA 固定。obligation_ref 仅核指针存在和 ID/version 字段完整性，不评 required_case_kinds、authority、owner、fixture、proof、closure，也不重算 ledger。unknown_ref 仅核指针选中非空来源对象与显式 critical 标志，不会推断遗漏未知。

顶层/指针/requirement 的未知字段、JSON 重复键或类型错误拒绝，防止将 status/passed 等字段塞进清单后误认权威。REA 原 bundle 内字段保持原样，脚本不改其内容。

## 机械边界与审查清单

| 情形 | 脚本结果 | 必须的后续 |
|------|----------|------------|
| 文件篡改、过期供应 SHA、越界、E/FR/指针缺失 | FAIL | 回原记录查明原因 |
| 显式关键 unknown | FAIL | 补证据，只阻断依赖功能 |
| 错误码/默认值/迁移错引但 SHA/引用齐全 | 可 PASS | 独立审阅及原版查询拒绝错误 spec |
| 未列出的 unknown、错误来源分类或旧版本完整材料 | 可 PASS | 独立检查完整性、身份与 freshness |
| 手填结果、过期 proof、同源比较、零声明 | 本脚本不评 | 真实测试生产者与 REA 生产接口审查 |

`requirements`、分类和 critical 标注是当次材料的引用投影，不是新的任务或证据状态。原材料更新后清单可废弃重建；恢复入口始终为原 case 与原生 feature/tasks。MUST NOT 在清单增加任务进度、授权开关、ready 状态、通过字段或第二 obligation 数据库。
