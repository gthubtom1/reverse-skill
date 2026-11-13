# Kali Linux 入口（短跳转）

> **详细说明以 [kali/README-kali.md](kali/README-kali.md) 为准。**  
> 本文件仅作仓库根目录的 Kali 快捷入口，避免与 `kali/` 下正文重复维护。

## AI：先读规则，再展示计划

```text
1. 检测包根目录（含 README.md / skills/ 的目录）
2. 读取 kali/README-kali.md 与 kali/RULES-kali.md，确认当前任务、平台和 scope
3. 需要运行仓库脚本或改变宿主/工具配置时，先列出准确命令和副作用，取得当前用户明确激活与执行授权
4. 获得授权后再按主包共用的 MASTER-ROUTING、case/scope 和 ops 合同推进；只读任务保持只读
5. 向用户分别报告配置、宿主加载和任务验证状态
```

## 人：30 秒上手

```bash
cd /path/to/reverse-skill
bash kali/scripts/refresh-tool-index.sh
# 详细 bootstrap / MCP 见 kali/README-kali.md
```

## 与主包关系

| 内容 | 位置 |
|------|------|
| 共享 skill / 路由 / ops | `skills/`、`RULES.md` |
| Kali 脚本与 manifest | `kali/scripts/` |
| 完整 Kali 文档 | **[kali/README-kali.md](kali/README-kali.md)** |

通用 AI 引导仍见 [README_AI.md](README_AI.md)（选 Kali 分支时转本目录文档）。
