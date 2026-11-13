#!/usr/bin/env bash
# ida-start.sh — start or inspect the pinned IDA Pro MCP supervisor on Linux.
# The entry never kills an unknown process. Set IDA_MCP_SERVER and
# IDA_MCP_ARGS when the local package uses a non-default launcher.
set -euo pipefail

IDADIR="${IDADIR:-/opt/idapro}"
MCP_PORT="${IDA_MCP_PORT:-13337}"
if [[ ! "$MCP_PORT" =~ ^[0-9]+$ ]] || (( MCP_PORT < 1 || MCP_PORT > 65535 )); then
    echo "ERR: IDA_MCP_PORT 必须是 1-65535 的整数"
    exit 2
fi
STATE_ROOT="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/reverse-skill/ida-mcp"
LOG_PATH="$STATE_ROOT/supervisor.log"
PID_PATH="$STATE_ROOT/supervisor.pid"

if [[ ! -d "$IDADIR" ]]; then
    echo "ERR: IDADIR 不存在: $IDADIR"
    echo "请设置环境变量 IDADIR 指向 IDA Pro 安装目录"
    exit 1
fi

if ! command -v nc >/dev/null 2>&1; then
    echo "ERR: 需要 nc 检查本地 MCP 端口"
    exit 1
fi

# A port may belong to IDA GUI or another supervisor. Do not infer ownership
# from a process-name match and do not terminate it.
if nc -z 127.0.0.1 "$MCP_PORT" 2>/dev/null; then
    echo "ERR: 127.0.0.1:$MCP_PORT 已被占用；未停止未知进程。请先核对 MCP 身份或使用其他端口。"
    exit 2
fi

mkdir -p "$STATE_ROOT"
if [[ -n "${IDA_MCP_SERVER:-}" ]]; then
    MCP_SERVER_CMD="$IDA_MCP_SERVER"
    if ! command -v "$MCP_SERVER_CMD" >/dev/null 2>&1 && [[ ! -x "$MCP_SERVER_CMD" ]]; then
        echo "ERR: $MCP_SERVER_CMD 未找到"
        exit 1
    fi
    read -r -a MCP_ARGS <<< "${IDA_MCP_ARGS:-}"
else
    MCP_SERVER_CMD="${IDA_MCP_PYTHON:-}"
    if [[ -z "$MCP_SERVER_CMD" ]]; then
        if [[ -x "$IDADIR/Python314/python" ]]; then
            MCP_SERVER_CMD="$IDADIR/Python314/python"
        else
            MCP_SERVER_CMD="python3"
        fi
    fi
    if ! command -v "$MCP_SERVER_CMD" >/dev/null 2>&1 && [[ ! -x "$MCP_SERVER_CMD" ]]; then
        echo "ERR: 未找到可运行 ida_pro_mcp.idalib_supervisor 的 Python: $MCP_SERVER_CMD"
        echo "请安装固定版本 ida-pro-mcp，或显式设置 IDA_MCP_SERVER/IDA_MCP_ARGS。"
        exit 1
    fi
    MCP_ARGS=(-m ida_pro_mcp.idalib_supervisor --host 127.0.0.1 --port "$MCP_PORT")
fi

export IDADIR IDA_MCP_PORT
printf '==== start %s command=%q args=%q pid=pending ====\n' "$(date -Iseconds)" "$MCP_SERVER_CMD" "${MCP_ARGS[*]:-}" >> "$LOG_PATH"
nohup "$MCP_SERVER_CMD" "${MCP_ARGS[@]}" >> "$LOG_PATH" 2>&1 &
MCP_PID=$!
process_start_ticks() {
    [[ -r "/proc/$1/stat" ]] || return 1
    awk '{ sub(/^.*\) /, ""); print $20 }' "/proc/$1/stat"
}
MCP_START_TICKS="$(process_start_ticks "$MCP_PID" || true)"
MCP_EXE="$(readlink "/proc/$MCP_PID/exe" 2>/dev/null || true)"
owned_supervisor() {
    [[ -n "$MCP_START_TICKS" && -n "$MCP_EXE" ]] &&
        [[ "$(process_start_ticks "$MCP_PID" 2>/dev/null || true)" == "$MCP_START_TICKS" ]] &&
        [[ "$(readlink "/proc/$MCP_PID/exe" 2>/dev/null || true)" == "$MCP_EXE" ]]
}
printf 'pid=%s\nstart_ticks=%s\nexecutable=%s\n' "$MCP_PID" "$MCP_START_TICKS" "$MCP_EXE" > "$PID_PATH"
if ! owned_supervisor; then
    echo "ERR: 无法建立本次 supervisor 的启动身份；未按裸 PID 停止进程。保留日志和 PID 记录: $PID_PATH"
    exit 1
fi

TIMEOUT=45
ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
    if ! owned_supervisor; then
        echo "ERR: IDA MCP supervisor 已退出或身份变化；查看日志: $LOG_PATH"
        exit 1
    fi
    if nc -z 127.0.0.1 "$MCP_PORT" 2>/dev/null; then
        echo "OK: IDA MCP 端口已监听 (PID=$MCP_PID, port=$MCP_PORT)"
        echo "NOTE: 端口监听不等于 MCP tools/list 已通过；需由宿主单独完成 handshake。"
        exit 0
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if owned_supervisor; then
    kill "$MCP_PID" 2>/dev/null || true
    for attempt in 1 2 3 4 5; do
        kill -0 "$MCP_PID" 2>/dev/null || break
        sleep 1
    done
fi
if kill -0 "$MCP_PID" 2>/dev/null; then
    echo "ERR: 启动超时且本次 supervisor 尚未退出 (PID=$MCP_PID)；保留 PID/log，cleanup 未确认。"
else
    wait "$MCP_PID" 2>/dev/null || true
    echo "ERR: 超时 ${TIMEOUT}s，服务未就绪；本次 supervisor 已退出。"
fi
echo "查看日志: $LOG_PATH"
exit 1
