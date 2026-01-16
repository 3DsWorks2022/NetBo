#!/bin/bash

# 检查 systemd 服务状态和配置
# 用于诊断开机自启动问题

echo "=========================================="
echo "  systemd 服务诊断工具"
echo "=========================================="
echo ""

# 检查服务文件是否存在
echo "[1] 检查服务文件..."
if [ -f /etc/systemd/system/rtsp-web.service ]; then
    echo "  ✓ rtsp-web.service 文件存在"
    echo ""
    echo "  服务文件内容:"
    cat /etc/systemd/system/rtsp-web.service | sed 's/^/    /'
    echo ""
else
    echo "  ✗ rtsp-web.service 文件不存在"
    exit 1
fi

# 检查服务是否已启用
echo "[2] 检查服务是否已启用..."
if systemctl is-enabled rtsp-web.service >/dev/null 2>&1; then
    echo "  ✓ 服务已启用（开机自启动）"
    systemctl is-enabled rtsp-web.service
else
    echo "  ✗ 服务未启用"
    echo "  执行以下命令启用: sudo systemctl enable rtsp-web.service"
fi
echo ""

# 检查服务状态
echo "[3] 检查服务当前状态..."
systemctl status rtsp-web.service --no-pager -l | head -20
echo ""

# 检查服务日志
echo "[4] 检查服务日志（最近20行）..."
if [ -f "$(grep StandardOutput /etc/systemd/system/rtsp-web.service | cut -d: -f2 | tr -d ' ')" ]; then
    LOG_FILE=$(grep StandardOutput /etc/systemd/system/rtsp-web.service | cut -d: -f2 | tr -d ' ')
    echo "  日志文件: $LOG_FILE"
    if [ -f "$LOG_FILE" ]; then
        tail -20 "$LOG_FILE" | sed 's/^/    /'
    else
        echo "  日志文件不存在"
    fi
else
    echo "  使用 journalctl 查看日志:"
    sudo journalctl -u rtsp-web.service -n 20 --no-pager | sed 's/^/    /'
fi
echo ""

# 检查脚本文件
echo "[5] 检查 start_web.sh 脚本..."
EXEC_START=$(grep "^ExecStart=" /etc/systemd/system/rtsp-web.service | cut -d= -f2- | sed 's|%WORKDIR%|'"$(grep WorkingDirectory /etc/systemd/system/rtsp-web.service | cut -d= -f2 | tr -d ' ')"'|g')
SCRIPT_PATH=$(echo "$EXEC_START" | awk '{print $NF}')

echo "  脚本路径: $SCRIPT_PATH"
if [ -f "$SCRIPT_PATH" ]; then
    echo "  ✓ 脚本文件存在"
    if [ -x "$SCRIPT_PATH" ]; then
        echo "  ✓ 脚本有执行权限"
    else
        echo "  ✗ 脚本没有执行权限"
        echo "  执行: chmod +x $SCRIPT_PATH"
    fi
else
    echo "  ✗ 脚本文件不存在"
fi
echo ""

# 检查配置文件
echo "[6] 检查配置文件..."
WORK_DIR=$(grep "^WorkingDirectory=" /etc/systemd/system/rtsp-web.service | cut -d= -f2 | tr -d ' ')
if [ -f "$WORK_DIR/config/stream.conf" ]; then
    echo "  ✓ 配置文件存在: $WORK_DIR/config/stream.conf"
    RTSP_URL=$(grep "^RTSP_URL=" "$WORK_DIR/config/stream.conf" | cut -d'"' -f2)
    if [ -n "$RTSP_URL" ] && [[ ! "$RTSP_URL" == *"192.168.1.100"* ]] && [[ ! "$RTSP_URL" == *"示例"* ]]; then
        echo "  ✓ RTSP地址已配置: $RTSP_URL"
    else
        echo "  ⚠ RTSP地址未配置或使用默认值"
    fi
else
    echo "  ✗ 配置文件不存在"
fi
echo ""

# 检查进程
echo "[7] 检查相关进程..."
if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    echo "  ✓ FFmpeg 转流进程运行中"
    pgrep -f "ffmpeg.*stream.m3u8" | xargs ps -p | sed 's/^/    /'
else
    echo "  ✗ FFmpeg 转流进程未运行"
fi
echo ""

if pgrep -f "python.*http_server" > /dev/null || lsof -Pi :8080 -sTCP:LISTEN > /dev/null 2>&1; then
    echo "  ✓ Web 服务器运行中"
    if pgrep -f "python.*http_server" > /dev/null; then
        pgrep -f "python.*http_server" | xargs ps -p | sed 's/^/    /'
    fi
else
    echo "  ✗ Web 服务器未运行"
fi
echo ""

# 建议
echo "[8] 诊断建议..."
echo ""
if ! systemctl is-enabled rtsp-web.service >/dev/null 2>&1; then
    echo "  ⚠ 服务未启用，执行: sudo systemctl enable rtsp-web.service"
fi

if ! systemctl is-active --quiet rtsp-web.service 2>/dev/null; then
    echo "  ⚠ 服务未运行，执行: sudo systemctl start rtsp-web.service"
    echo "  然后查看日志: sudo journalctl -u rtsp-web.service -f"
fi

echo ""
echo "=========================================="
echo "  诊断完成"
echo "=========================================="
