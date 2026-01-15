#!/bin/bash

# RTSP转HLS状态检查脚本
# 使用方法: ./check_status.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载配置
source "$PROJECT_ROOT/config/stream.conf"

PID_FILE="$PROJECT_ROOT/scripts/ffmpeg.pid"

echo "=== RTSP转HLS服务状态 ==="
echo ""

# 检查FFmpeg进程
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        echo "✅ FFmpeg进程运行中 (PID: $PID)"
    else
        echo "❌ FFmpeg进程不存在 (PID文件存在但进程已停止)"
    fi
elif pgrep -f "ffmpeg.*$HLS_PLAYLIST" > /dev/null; then
    PID=$(pgrep -f "ffmpeg.*$HLS_PLAYLIST" | head -1)
    echo "✅ FFmpeg进程运行中 (PID: $PID)"
else
    echo "❌ FFmpeg进程未运行"
fi

echo ""

# 检查HLS文件
if [ -f "$HLS_OUTPUT_DIR/$HLS_PLAYLIST" ]; then
    echo "✅ HLS播放列表存在: $HLS_OUTPUT_DIR/$HLS_PLAYLIST"
    # 检查文件是否最近更新（30秒内）
    if [ $(find "$HLS_OUTPUT_DIR/$HLS_PLAYLIST" -mmin -0.5 | wc -l) -gt 0 ]; then
        echo "✅ HLS文件最近有更新（正常）"
    else
        echo "⚠️ 警告: HLS文件超过30秒未更新"
    fi
    
    # 统计TS切片数量
    TS_COUNT=$(ls -1 "$HLS_OUTPUT_DIR"/*.ts 2>/dev/null | wc -l)
    echo "📊 TS切片数量: $TS_COUNT"
else
    echo "❌ HLS播放列表不存在: $HLS_OUTPUT_DIR/$HLS_PLAYLIST"
fi

echo ""

# 检查配置
echo "=== 配置信息 ==="
echo "RTSP源: $RTSP_URL"
echo "HLS输出目录: $HLS_OUTPUT_DIR"
echo "HLS播放列表: $HLS_PLAYLIST"
echo ""

# 检查日志
if [ -f "$FFMPEG_LOG" ]; then
    echo "=== 最近日志 (最后10行) ==="
    tail -10 "$FFMPEG_LOG"
else
    echo "⚠️ 日志文件不存在: $FFMPEG_LOG"
fi
