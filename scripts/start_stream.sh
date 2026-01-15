#!/bin/bash

# RTSP转HLS启动脚本
# 使用方法: ./start_stream.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载配置
source "$PROJECT_ROOT/config/stream.conf"

# 在Ubuntu环境下，自动修复HLS输出目录配置
if [[ "$OSTYPE" == "linux-gnu"* ]] || [ -f /etc/os-release ]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
            # Ubuntu/Debian环境，检查并修复配置
            if [[ "$HLS_OUTPUT_DIR" == "./hls_output" ]] || [[ "$HLS_OUTPUT_DIR" == "hls_output" ]]; then
                echo "检测到Ubuntu环境，自动更新HLS输出目录配置..."
                sed -i 's|HLS_OUTPUT_DIR="\./hls_output"|HLS_OUTPUT_DIR="/var/www/hls"|' "$PROJECT_ROOT/config/stream.conf"
                sed -i 's|HLS_OUTPUT_DIR="hls_output"|HLS_OUTPUT_DIR="/var/www/hls"|' "$PROJECT_ROOT/config/stream.conf"
                # 重新加载配置
                source "$PROJECT_ROOT/config/stream.conf"
                echo "✓ 已更新为: $HLS_OUTPUT_DIR"
            fi
        fi
    fi
fi

# 检查FFmpeg是否安装
if ! command -v ffmpeg &> /dev/null; then
    echo "错误: FFmpeg未安装，请先安装FFmpeg"
    echo "安装命令: sudo apt-get install -y ffmpeg"
    exit 1
fi

# 创建输出目录（如果是绝对路径需要sudo权限）
if [[ "$HLS_OUTPUT_DIR" == /* ]]; then
    # 绝对路径（Ubuntu部署: /var/www/hls），需要sudo权限
    if [ ! -d "$HLS_OUTPUT_DIR" ]; then
        echo "创建HLS输出目录: $HLS_OUTPUT_DIR"
        if sudo mkdir -p "$HLS_OUTPUT_DIR" 2>/dev/null; then
            sudo chmod 755 "$HLS_OUTPUT_DIR" 2>/dev/null || true
            # 设置所有者，允许当前用户写入
            CURRENT_USER=$(whoami)
            sudo chown -R $CURRENT_USER:$CURRENT_USER "$HLS_OUTPUT_DIR" 2>/dev/null || \
            sudo chown -R www-data:www-data "$HLS_OUTPUT_DIR" 2>/dev/null || true
            echo "✓ 目录已创建并设置权限"
        else
            echo "❌ 无法创建目录（需要sudo权限）: $HLS_OUTPUT_DIR"
            echo "请手动创建: sudo mkdir -p $HLS_OUTPUT_DIR && sudo chmod 755 $HLS_OUTPUT_DIR"
            exit 1
        fi
    else
        # 目录已存在，确保权限正确
        if [ ! -w "$HLS_OUTPUT_DIR" ]; then
            echo "修复目录权限: $HLS_OUTPUT_DIR"
            CURRENT_USER=$(whoami)
            sudo chmod 775 "$HLS_OUTPUT_DIR" 2>/dev/null || true
            sudo chown -R $CURRENT_USER:$CURRENT_USER "$HLS_OUTPUT_DIR" 2>/dev/null || \
            sudo chown -R www-data:www-data "$HLS_OUTPUT_DIR" 2>/dev/null || true
        fi
    fi
else
    # 相对路径，直接创建
    mkdir -p "$HLS_OUTPUT_DIR"
fi

# 创建日志目录
mkdir -p "$(dirname "$FFMPEG_LOG")"

# 检查是否已有FFmpeg进程在运行
if pgrep -f "ffmpeg.*$HLS_PLAYLIST" > /dev/null; then
    echo "警告: FFmpeg转流进程已在运行"
    echo "如需重启，请先运行: ./stop_stream.sh"
    exit 1
fi

# 检查RTSP地址是否配置
if [ -z "$RTSP_URL" ]; then
    echo "警告: RTSP_URL未配置"
    echo "编辑文件: $PROJECT_ROOT/config/stream.conf"
    echo "设置正确的RTSP_URL值"
    exit 1
fi

# 检查是否为示例地址（包含常见示例关键词）
if [[ "$RTSP_URL" == *"192.168.1.100"* ]] || [[ "$RTSP_URL" == *"示例"* ]] || [[ "$RTSP_URL" == *"example"* ]]; then
    echo "警告: RTSP地址可能未正确配置（检测到示例地址）"
    echo "当前RTSP_URL: $RTSP_URL"
    echo "编辑文件: $PROJECT_ROOT/config/stream.conf"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "启动RTSP转HLS服务..."
echo "RTSP源: $RTSP_URL"
echo "HLS输出: $HLS_OUTPUT_DIR/$HLS_PLAYLIST"
echo "日志文件: $FFMPEG_LOG"

# 使用配置的缓存时间（如果未配置则使用默认值）
HLS_SEGMENT_TIME=${HLS_SEGMENT_TIME:-2}
HLS_LIST_SIZE=${HLS_LIST_SIZE:-3}

# 启动FFmpeg转流（后台运行）
nohup ffmpeg -rtsp_transport tcp \
  -i "$RTSP_URL" \
  -c:v copy \
  -c:a aac -b:a 128k \
  -f hls \
  -hls_time $HLS_SEGMENT_TIME \
  -hls_list_size $HLS_LIST_SIZE \
  -hls_flags delete_segments+independent_segments \
  -hls_segment_filename "$HLS_OUTPUT_DIR/stream_%03d.ts" \
  "$HLS_OUTPUT_DIR/$HLS_PLAYLIST" \
  > "$FFMPEG_LOG" 2>&1 &

FFMPEG_PID=$!

# 等待一下，检查进程是否成功启动
sleep 2
if ps -p $FFMPEG_PID > /dev/null; then
    echo "FFmpeg转流已启动，进程ID: $FFMPEG_PID"
    echo "$FFMPEG_PID" > "$PROJECT_ROOT/scripts/ffmpeg.pid"
    echo "查看日志: tail -f $FFMPEG_LOG"
else
    echo "错误: FFmpeg启动失败，请检查日志: $FFMPEG_LOG"
    exit 1
fi
