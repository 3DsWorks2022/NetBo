#!/bin/bash

# RTSP转HLS重启脚本
# 使用方法: ./restart_stream.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "重启RTSP转HLS服务..."

# 先停止
"$SCRIPT_DIR/stop_stream.sh"

# 等待2秒
sleep 2

# 再启动
"$SCRIPT_DIR/start_stream.sh"
