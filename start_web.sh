#!/bin/bash

# 一键启动RTSP转HLS服务（包括转流和Web服务器）
# 使用方法: ./start_web.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

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
                sed -i 's|HLS_OUTPUT_DIR="./hls_output"|HLS_OUTPUT_DIR="/var/www/hls"|' "$PROJECT_ROOT/config/stream.conf"
                sed -i 's|HLS_OUTPUT_DIR="hls_output"|HLS_OUTPUT_DIR="/var/www/hls"|' "$PROJECT_ROOT/config/stream.conf"
                # 重新加载配置
                source "$PROJECT_ROOT/config/stream.conf"
                echo "✓ 已更新为: $HLS_OUTPUT_DIR"
            fi
        fi
    fi
fi

PORT=8080
WEB_DIR="$PROJECT_ROOT/web"

# 使用配置文件中的HLS输出目录（支持本地和Ubuntu部署）
# 如果配置文件中是相对路径，则基于项目根目录；如果是绝对路径，则直接使用
if [[ "$HLS_OUTPUT_DIR" == /* ]]; then
    # 绝对路径（Ubuntu部署: /var/www/hls）
    HLS_DIR="$HLS_OUTPUT_DIR"
else
    # 相对路径（本地测试: ./hls_output）
    HLS_DIR="$PROJECT_ROOT/$HLS_OUTPUT_DIR"
fi

echo "=========================================="
echo "  RTSP转HLS服务一键启动"
echo "=========================================="
echo ""

# 步骤0: 先停止可能存在的旧进程
echo "[0/5] 清理旧进程..."
if [ -f "$PROJECT_ROOT/scripts/stop_stream.sh" ]; then
    "$PROJECT_ROOT/scripts/stop_stream.sh" > /dev/null 2>&1 || true
    echo "✅ 已清理旧进程"
else
    # 如果停止脚本不存在，手动清理
    if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
        pkill -f "ffmpeg.*stream.m3u8" 2>/dev/null || true
        echo "✅ 已清理旧进程"
    fi
fi
echo ""

# 步骤1: 检查FFmpeg是否安装
echo "[1/5] 检查FFmpeg..."
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ FFmpeg未安装"
    echo "请先安装FFmpeg:"
    echo "  macOS: brew install ffmpeg"
    echo "  Ubuntu: sudo apt-get install ffmpeg"
    exit 1
fi
echo "✅ FFmpeg已安装"
echo ""

# 步骤2: 检查并启动转流服务
echo "[2/5] 检查转流服务..."

# 检查是否已有FFmpeg进程在运行
if pgrep -f "ffmpeg.*$HLS_PLAYLIST" > /dev/null; then
    echo "✅ 转流服务已在运行"
else
    echo "启动转流服务..."
    
    # 检查RTSP地址是否配置
    if [ -z "$RTSP_URL" ]; then
        echo "❌ 错误: RTSP_URL未配置"
        echo "请编辑: $PROJECT_ROOT/config/stream.conf"
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
                echo "✅ 目录已创建并设置权限"
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
    
    echo "RTSP源: $RTSP_URL"
    echo "HLS输出: $HLS_OUTPUT_DIR/$HLS_PLAYLIST"
    
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
    sleep 3
    if ps -p $FFMPEG_PID > /dev/null; then
        echo "$FFMPEG_PID" > "$PROJECT_ROOT/scripts/ffmpeg.pid"
        echo "✅ 转流服务已启动 (PID: $FFMPEG_PID)"
        echo "等待HLS文件生成..."
        # 等待HLS文件生成
        for i in {1..10}; do
            if [ -f "$HLS_OUTPUT_DIR/$HLS_PLAYLIST" ]; then
                echo "✅ HLS文件已生成"
                break
            fi
            sleep 1
        done
    else
        echo "❌ 转流服务启动失败，请检查日志: $FFMPEG_LOG"
        exit 1
    fi
fi
echo ""

# 步骤3: 检查并清理端口
echo "[3/5] 检查HTTP服务器端口..."
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  端口 $PORT 已被占用"
    echo "正在清理占用端口的进程..."
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
    sleep 1
    echo "✅ 端口已清理"
fi
echo ""

# 步骤4: 启动Web服务器
echo "[4/5] 启动Web服务器..."

# 检查HLS目录是否存在，如果不存在则尝试创建
if [ ! -d "$HLS_DIR" ]; then
    echo "⚠️  HLS输出目录不存在: $HLS_DIR"
    echo "尝试创建目录..."
    if [[ "$HLS_DIR" == /* ]]; then
        # 绝对路径需要sudo权限
        if sudo mkdir -p "$HLS_DIR" 2>/dev/null; then
            sudo chmod 755 "$HLS_DIR" 2>/dev/null || true
            echo "✅ 目录已创建: $HLS_DIR"
        else
            echo "❌ 无法创建目录（需要sudo权限）: $HLS_DIR"
            echo "请手动创建: sudo mkdir -p $HLS_DIR && sudo chmod 755 $HLS_DIR"
            exit 1
        fi
    else
        # 相对路径可以直接创建
        if mkdir -p "$HLS_DIR" 2>/dev/null; then
            echo "✅ 目录已创建: $HLS_DIR"
        else
            echo "❌ 无法创建目录: $HLS_DIR"
            exit 1
        fi
    fi
fi

# 获取本机IP地址
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo "localhost"
    else
        # Linux
        hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7; exit}' || echo "localhost"
    fi
}

LOCAL_IP=$(get_local_ip)

# 创建符号链接，让web目录可以访问hls文件
# 如果使用Python服务器，需要创建符号链接以便访问HLS文件
if [[ "$HLS_DIR" == "/var/www/hls" ]]; then
    # Ubuntu部署环境
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo "ℹ️  检测到Nginx服务运行，使用Nginx提供Web服务"
        # Nginx运行时，不需要符号链接
    else
        echo "ℹ️  检测到Ubuntu部署环境，但Nginx未运行"
        echo "创建符号链接以便Python服务器访问HLS文件..."
        # 即使HLS目录是/var/www/hls，如果使用Python服务器，也需要创建符号链接
        if [ -L "$WEB_DIR/hls" ] || [ -d "$WEB_DIR/hls" ]; then
            rm -rf "$WEB_DIR/hls" 2>/dev/null || true
        fi
        # 创建符号链接指向/var/www/hls
        if ln -s "$HLS_DIR" "$WEB_DIR/hls" 2>/dev/null; then
            echo "✅ 符号链接已创建: $WEB_DIR/hls -> $HLS_DIR"
        else
            echo "⚠️  无法创建符号链接，尝试使用sudo..."
            if sudo ln -s "$HLS_DIR" "$WEB_DIR/hls" 2>/dev/null; then
                sudo chown -h $USER:$USER "$WEB_DIR/hls" 2>/dev/null || true
                echo "✅ 符号链接已创建（使用sudo）"
            else
                echo "❌ 无法创建符号链接，HLS文件可能无法通过Python服务器访问"
                echo "建议: 启动Nginx服务或手动创建符号链接"
            fi
        fi
    fi
else
    # 本地测试环境，创建符号链接
    if [ -L "$WEB_DIR/hls" ] || [ -d "$WEB_DIR/hls" ]; then
        rm -rf "$WEB_DIR/hls" 2>/dev/null || true
    fi
    ln -s "$(cd "$HLS_DIR" && pwd)" "$WEB_DIR/hls" 2>/dev/null || {
        echo "⚠️  无法创建符号链接（不影响功能）"
    }
fi

# 检查是否在Ubuntu部署环境（使用Nginx）
# 只有在Nginx真正运行且配置正确时才使用Nginx
if [[ "$HLS_DIR" == "/var/www/hls" ]] && command -v nginx &> /dev/null && systemctl is-active --quiet nginx 2>/dev/null; then
    # 验证Nginx配置是否正确
    if [ -f /etc/nginx/sites-enabled/rtsp-stream ] || [ -f /etc/nginx/sites-available/rtsp-stream ]; then
    echo ""
    echo "=========================================="
    echo "  服务启动完成！"
    echo "=========================================="
        echo ""
        echo "ℹ️  检测到Nginx服务，使用Nginx提供Web服务"
        echo ""
        echo "📺 访问播放页面:"
        echo "   http://$LOCAL_IP/index.html"
        echo "   或"
        echo "   http://$LOCAL_IP:80/index.html"
        echo ""
        echo "📊 管理命令:"
        echo "   查看状态: ./scripts/check_status.sh"
        echo "   停止转流: ./scripts/stop_stream.sh"
        echo "   查看日志: tail -f $FFMPEG_LOG"
        echo ""
        echo "✅ 转流服务已在后台运行"
        echo "✅ Web服务由Nginx提供"
        echo ""
        exit 0
    else
        echo "⚠️  Nginx运行但配置未找到，使用Python服务器"
    fi
fi

# 本地测试环境：使用Python HTTP服务器
echo "ℹ️  使用Python HTTP服务器（本地测试模式）"
echo ""

# 检查Python版本
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ 错误: 未找到Python，请先安装Python"
    exit 1
fi

echo ""
echo "=========================================="
echo "  服务启动完成！"
echo "=========================================="
echo ""
echo "📺 访问播放页面:"
echo "   本地: http://localhost:$PORT/index.html"
echo "   局域网: http://$LOCAL_IP:$PORT/index.html"
echo ""
echo "📊 管理命令:"
echo "   查看状态: ./scripts/check_status.sh"
echo "   停止转流: ./scripts/stop_stream.sh"
echo "   查看日志: tail -f $FFMPEG_LOG"
echo ""
echo "按 Ctrl+C 停止Web服务器"
echo "（转流服务会继续在后台运行）"
echo ""

# 切换到web目录，启动HTTP服务器
cd "$WEB_DIR"

# 使用自定义HTTP服务器（正确设置MIME类型，解决手机浏览器问题）
if [ -f "$PROJECT_ROOT/web/http_server.py" ]; then
    $PYTHON_CMD "$PROJECT_ROOT/web/http_server.py" -p $PORT -d "$WEB_DIR"
else
    # 如果自定义服务器不存在，使用标准服务器
    $PYTHON_CMD -m http.server $PORT
fi
