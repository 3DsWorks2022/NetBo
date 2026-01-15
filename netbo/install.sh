#!/bin/bash

# RTSP转HLS一键部署和启动脚本
# 使用方法: ./install.sh

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RTSP转HLS一键部署脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查是否为root用户（部分操作需要sudo）
if [ "$EUID" -eq 0 ]; then 
    SUDO=""
else
    SUDO="sudo"
    echo -e "${YELLOW}提示: 部分操作需要sudo权限${NC}"
    echo ""
fi

# 步骤1: 检查依赖
echo -e "${BLUE}[1/6] 检查系统依赖...${NC}"

# 检查FFmpeg
if command -v ffmpeg &> /dev/null; then
    FFMPEG_VERSION=$(ffmpeg -version | head -n1 | cut -d' ' -f3)
    echo -e "${GREEN}✓ FFmpeg已安装 (版本: $FFMPEG_VERSION)${NC}"
else
    echo -e "${RED}✗ FFmpeg未安装${NC}"
    echo -e "${YELLOW}正在安装FFmpeg...${NC}"
    $SUDO apt-get update
    $SUDO apt-get install -y ffmpeg
    echo -e "${GREEN}✓ FFmpeg安装完成${NC}"
fi

# 检查Nginx
if command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    echo -e "${GREEN}✓ Nginx已安装 (版本: $NGINX_VERSION)${NC}"
else
    echo -e "${RED}✗ Nginx未安装${NC}"
    echo -e "${YELLOW}正在安装Nginx...${NC}"
    $SUDO apt-get update
    $SUDO apt-get install -y nginx
    echo -e "${GREEN}✓ Nginx安装完成${NC}"
fi

echo ""

# 步骤2: 加载配置
echo -e "${BLUE}[2/6] 加载配置...${NC}"
if [ -f "$PROJECT_ROOT/config/stream.conf" ]; then
    source "$PROJECT_ROOT/config/stream.conf"
    echo -e "${GREEN}✓ 配置文件加载成功${NC}"
    echo -e "  RTSP源: $RTSP_URL"
    echo -e "  HLS输出: $HLS_OUTPUT_DIR"
else
    echo -e "${RED}✗ 配置文件不存在: $PROJECT_ROOT/config/stream.conf${NC}"
    exit 1
fi

# 检查RTSP地址是否已配置
if [ -z "$RTSP_URL" ] || [[ "$RTSP_URL" == rtsp://*示例* ]] || [[ "$RTSP_URL" == rtsp://192.168.1.100* ]]; then
    echo -e "${YELLOW}⚠ 警告: RTSP地址可能未正确配置${NC}"
    echo -e "${YELLOW}请编辑: $PROJECT_ROOT/config/stream.conf${NC}"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

# 步骤3: 创建目录
echo -e "${BLUE}[3/6] 创建必要目录...${NC}"

# 创建HLS输出目录
if [ ! -d "$HLS_OUTPUT_DIR" ]; then
    $SUDO mkdir -p "$HLS_OUTPUT_DIR"
    echo -e "${GREEN}✓ 创建HLS输出目录: $HLS_OUTPUT_DIR${NC}"
else
    echo -e "${GREEN}✓ HLS输出目录已存在: $HLS_OUTPUT_DIR${NC}"
fi

# 设置目录权限
$SUDO chmod 755 "$HLS_OUTPUT_DIR"

# 创建Web静态文件目录
WEB_DIR="/var/www/html"
if [ ! -d "$WEB_DIR" ]; then
    $SUDO mkdir -p "$WEB_DIR"
    echo -e "${GREEN}✓ 创建Web目录: $WEB_DIR${NC}"
else
    echo -e "${GREEN}✓ Web目录已存在: $WEB_DIR${NC}"
fi

# 创建日志目录
LOG_DIR="$(dirname "$FFMPEG_LOG")"
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    echo -e "${GREEN}✓ 创建日志目录: $LOG_DIR${NC}"
fi

echo ""

# 步骤4: 部署Web文件
echo -e "${BLUE}[4/6] 部署Web播放页面...${NC}"
if [ -f "$PROJECT_ROOT/web/index.html" ]; then
    $SUDO cp "$PROJECT_ROOT/web/index.html" "$WEB_DIR/"
    echo -e "${GREEN}✓ Web播放页面已部署${NC}"
else
    echo -e "${RED}✗ Web播放页面不存在: $PROJECT_ROOT/web/index.html${NC}"
    exit 1
fi

echo ""

# 步骤5: 配置Nginx
echo -e "${BLUE}[5/6] 配置Nginx...${NC}"

NGINX_CONF_SOURCE="$PROJECT_ROOT/nginx/nginx.conf"
NGINX_CONF_DEST="/etc/nginx/sites-available/rtsp-stream"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled/rtsp-stream"

if [ -f "$NGINX_CONF_SOURCE" ]; then
    # 复制配置文件
    $SUDO cp "$NGINX_CONF_SOURCE" "$NGINX_CONF_DEST"
    echo -e "${GREEN}✓ Nginx配置文件已复制${NC}"
    
    # 创建软链接（如果不存在）
    if [ ! -L "$NGINX_CONF_ENABLED" ]; then
        $SUDO ln -s "$NGINX_CONF_DEST" "$NGINX_CONF_ENABLED"
        echo -e "${GREEN}✓ Nginx配置已启用${NC}"
    else
        echo -e "${GREEN}✓ Nginx配置已存在${NC}"
    fi
    
    # 测试Nginx配置
    if $SUDO nginx -t 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx配置测试通过${NC}"
        # 重启Nginx
        $SUDO systemctl restart nginx
        echo -e "${GREEN}✓ Nginx已重启${NC}"
    else
        echo -e "${RED}✗ Nginx配置测试失败${NC}"
        echo -e "${YELLOW}请检查配置文件: $NGINX_CONF_DEST${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Nginx配置文件不存在: $NGINX_CONF_SOURCE${NC}"
    exit 1
fi

echo ""

# 步骤6: 启动转流服务
echo -e "${BLUE}[6/6] 启动转流服务...${NC}"

# 先停止可能存在的旧进程
if [ -f "$PROJECT_ROOT/scripts/ffmpeg.pid" ]; then
    OLD_PID=$(cat "$PROJECT_ROOT/scripts/ffmpeg.pid" 2>/dev/null || echo "")
    if [ ! -z "$OLD_PID" ] && ps -p $OLD_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}发现运行中的转流进程，正在停止...${NC}"
        "$PROJECT_ROOT/scripts/stop_stream.sh" > /dev/null 2>&1 || true
        sleep 2
    fi
fi

# 启动转流
if "$PROJECT_ROOT/scripts/start_stream.sh"; then
    echo -e "${GREEN}✓ 转流服务启动成功${NC}"
else
    echo -e "${RED}✗ 转流服务启动失败${NC}"
    echo -e "${YELLOW}请检查日志: $FFMPEG_LOG${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}服务信息:${NC}"
echo -e "  RTSP源: ${YELLOW}$RTSP_URL${NC}"
echo -e "  HLS输出: ${YELLOW}$HLS_OUTPUT_DIR/$HLS_PLAYLIST${NC}"
echo -e "  播放页面: ${YELLOW}http://$(hostname -I | awk '{print $1}')/${NC}"
echo ""
echo -e "${BLUE}管理命令:${NC}"
echo -e "  启动: ${YELLOW}./scripts/start_stream.sh${NC}"
echo -e "  停止: ${YELLOW}./scripts/stop_stream.sh${NC}"
echo -e "  重启: ${YELLOW}./scripts/restart_stream.sh${NC}"
echo -e "  状态: ${YELLOW}./scripts/check_status.sh${NC}"
echo ""
echo -e "${BLUE}查看日志:${NC}"
echo -e "  ${YELLOW}tail -f $FFMPEG_LOG${NC}"
echo ""
