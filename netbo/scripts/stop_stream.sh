#!/bin/bash

# RTSP转HLS停止脚本
# 使用方法: ./stop_stream.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载配置
source "$PROJECT_ROOT/config/stream.conf"

PID_FILE="$PROJECT_ROOT/scripts/ffmpeg.pid"

# 方法1: 从PID文件读取进程ID
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        echo "停止FFmpeg进程 (PID: $PID)..."
        kill $PID
        sleep 1
        # 如果还在运行，强制杀死
        if ps -p $PID > /dev/null 2>&1; then
            echo "强制停止FFmpeg进程..."
            kill -9 $PID
        fi
        rm -f "$PID_FILE"
        echo "FFmpeg进程已停止"
        exit 0
    else
        echo "PID文件存在但进程已不存在，清理PID文件"
        rm -f "$PID_FILE"
    fi
fi

# 方法2: 通过进程名查找并停止
if pgrep -f "ffmpeg.*$HLS_PLAYLIST" > /dev/null; then
    echo "找到FFmpeg转流进程，正在停止..."
    pkill -f "ffmpeg.*$HLS_PLAYLIST"
    sleep 1
    # 如果还在运行，强制杀死
    if pgrep -f "ffmpeg.*$HLS_PLAYLIST" > /dev/null; then
        echo "强制停止FFmpeg进程..."
        pkill -9 -f "ffmpeg.*$HLS_PLAYLIST"
    fi
    echo "FFmpeg进程已停止"
else
    echo "未找到运行中的FFmpeg转流进程"
fi
