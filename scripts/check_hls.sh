#!/bin/bash

# HLS流诊断脚本
# 检查HLS文件是否存在、可访问，以及Nginx配置是否正确

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载配置
if [ -f "$PROJECT_ROOT/config/stream.conf" ]; then
    source "$PROJECT_ROOT/config/stream.conf"
else
    echo -e "${RED}错误: 配置文件不存在${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HLS流诊断工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查1: HLS输出目录是否存在
echo -e "${BLUE}[1/6] 检查HLS输出目录...${NC}"
if [ -d "$HLS_OUTPUT_DIR" ]; then
    echo -e "${GREEN}✓ 目录存在: $HLS_OUTPUT_DIR${NC}"
    ls -lh "$HLS_OUTPUT_DIR" | head -10
else
    echo -e "${RED}✗ 目录不存在: $HLS_OUTPUT_DIR${NC}"
    echo -e "${YELLOW}尝试创建目录...${NC}"
    if [[ "$HLS_OUTPUT_DIR" == /* ]]; then
        sudo mkdir -p "$HLS_OUTPUT_DIR" && sudo chmod 755 "$HLS_OUTPUT_DIR"
    else
        mkdir -p "$HLS_OUTPUT_DIR"
    fi
fi
echo ""

# 检查2: HLS播放列表文件是否存在
echo -e "${BLUE}[2/6] 检查HLS播放列表文件...${NC}"
PLAYLIST_FILE="$HLS_OUTPUT_DIR/$HLS_PLAYLIST"
if [ -f "$PLAYLIST_FILE" ]; then
    echo -e "${GREEN}✓ 播放列表文件存在: $PLAYLIST_FILE${NC}"
    echo "文件内容:"
    head -20 "$PLAYLIST_FILE"
    echo ""
    # 检查文件是否最近更新（5分钟内）
    if [ $(find "$PLAYLIST_FILE" -mmin -5 | wc -l) -gt 0 ]; then
        echo -e "${GREEN}✓ 文件最近更新（5分钟内）${NC}"
    else
        echo -e "${YELLOW}⚠ 文件未在5分钟内更新，可能转流服务未运行${NC}"
    fi
else
    echo -e "${RED}✗ 播放列表文件不存在: $PLAYLIST_FILE${NC}"
    echo -e "${YELLOW}请检查转流服务是否正在运行${NC}"
fi
echo ""

# 检查3: FFmpeg进程是否运行
echo -e "${BLUE}[3/6] 检查FFmpeg转流进程...${NC}"
if pgrep -f "ffmpeg.*$HLS_PLAYLIST" > /dev/null; then
    FFMPEG_PID=$(pgrep -f "ffmpeg.*$HLS_PLAYLIST" | head -1)
    echo -e "${GREEN}✓ FFmpeg进程正在运行 (PID: $FFMPEG_PID)${NC}"
    ps aux | grep "ffmpeg.*$HLS_PLAYLIST" | grep -v grep
else
    echo -e "${RED}✗ FFmpeg进程未运行${NC}"
    echo -e "${YELLOW}请运行: ./start_web.sh 或 ./scripts/start_stream.sh${NC}"
fi
echo ""

# 检查4: Nginx配置（如果使用Nginx）
echo -e "${BLUE}[4/6] 检查Nginx配置...${NC}"
if command -v nginx &> /dev/null; then
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx服务正在运行${NC}"
        # 检查配置
        if sudo nginx -t 2>/dev/null; then
            echo -e "${GREEN}✓ Nginx配置正确${NC}"
        else
            echo -e "${YELLOW}⚠ Nginx配置可能有问题${NC}"
        fi
        # 检查HLS路径配置
        if grep -q "/hls/" /etc/nginx/sites-enabled/* 2>/dev/null; then
            echo -e "${GREEN}✓ 找到HLS路径配置${NC}"
        else
            echo -e "${YELLOW}⚠ 未找到HLS路径配置${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Nginx服务未运行${NC}"
    fi
else
    echo -e "${YELLOW}ℹ Nginx未安装（使用Python HTTP服务器）${NC}"
fi
echo ""

# 检查5: 文件权限
echo -e "${BLUE}[5/6] 检查文件权限...${NC}"
if [ -d "$HLS_OUTPUT_DIR" ]; then
    PERM=$(stat -c "%a" "$HLS_OUTPUT_DIR" 2>/dev/null || stat -f "%OLp" "$HLS_OUTPUT_DIR" 2>/dev/null)
    echo "目录权限: $PERM"
    if [ -f "$PLAYLIST_FILE" ]; then
        FILE_PERM=$(stat -c "%a" "$PLAYLIST_FILE" 2>/dev/null || stat -f "%OLp" "$PLAYLIST_FILE" 2>/dev/null)
        echo "文件权限: $FILE_PERM"
        if [ ! -r "$PLAYLIST_FILE" ]; then
            echo -e "${RED}✗ 文件不可读${NC}"
        else
            echo -e "${GREEN}✓ 文件可读${NC}"
        fi
    fi
fi
echo ""

# 检查6: 网络访问测试
echo -e "${BLUE}[6/6] 测试网络访问...${NC}"
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
echo "本机IP: $LOCAL_IP"

# 测试HTTP访问
if command -v curl &> /dev/null; then
    echo "测试访问: http://$LOCAL_IP/hls/$HLS_PLAYLIST"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LOCAL_IP/hls/$HLS_PLAYLIST" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ HTTP访问正常 (状态码: $HTTP_CODE)${NC}"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo -e "${RED}✗ 文件未找到 (状态码: 404)${NC}"
        echo -e "${YELLOW}请检查Nginx配置或文件路径${NC}"
    elif [ "$HTTP_CODE" = "000" ]; then
        echo -e "${YELLOW}⚠ 无法访问（可能未使用Nginx）${NC}"
    else
        echo -e "${YELLOW}⚠ HTTP状态码: $HTTP_CODE${NC}"
    fi
else
    echo -e "${YELLOW}ℹ curl未安装，跳过网络测试${NC}"
fi
echo ""

# 总结
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  诊断完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}如果发现问题，请检查:${NC}"
echo "  1. 转流服务是否运行: ./scripts/check_status.sh"
echo "  2. 配置文件是否正确: cat config/stream.conf"
echo "  3. Nginx配置: sudo nginx -t"
echo "  4. 查看日志: tail -f logs/ffmpeg.log"
echo ""
