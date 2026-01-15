#!/bin/bash

# 检查HLS文件是否存在和可访问
# 使用方法: ./scripts/check_hls_file.sh

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
source "$PROJECT_ROOT/config/stream.conf" 2>/dev/null || true

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HLS文件检查${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 确定HLS输出目录
if [ -z "$HLS_OUTPUT_DIR" ]; then
    HLS_OUTPUT_DIR="/var/www/hls"
    echo -e "${YELLOW}⚠ HLS_OUTPUT_DIR未配置，使用默认值: $HLS_OUTPUT_DIR${NC}"
fi

# 如果是相对路径，转换为绝对路径
if [[ "$HLS_OUTPUT_DIR" != /* ]]; then
    HLS_DIR="$PROJECT_ROOT/$HLS_OUTPUT_DIR"
else
    HLS_DIR="$HLS_OUTPUT_DIR"
fi

echo -e "${BLUE}配置信息:${NC}"
echo "  HLS_OUTPUT_DIR: $HLS_OUTPUT_DIR"
echo "  实际目录: $HLS_DIR"
echo "  HLS播放列表: $HLS_PLAYLIST"
echo ""

# 检查目录是否存在
echo -e "${BLUE}[1] 检查目录...${NC}"
if [ -d "$HLS_DIR" ]; then
    echo -e "${GREEN}✓ 目录存在: $HLS_DIR${NC}"
    
    # 检查权限
    if [ -r "$HLS_DIR" ]; then
        echo -e "${GREEN}✓ 目录可读${NC}"
    else
        echo -e "${RED}✗ 目录不可读${NC}"
    fi
    
    if [ -w "$HLS_DIR" ]; then
        echo -e "${GREEN}✓ 目录可写${NC}"
    else
        echo -e "${RED}✗ 目录不可写${NC}"
        echo -e "${YELLOW}修复命令: sudo chmod 755 $HLS_DIR${NC}"
    fi
else
    echo -e "${RED}✗ 目录不存在: $HLS_DIR${NC}"
    if [[ "$HLS_DIR" == /* ]]; then
        echo -e "${YELLOW}创建命令: sudo mkdir -p $HLS_DIR && sudo chmod 755 $HLS_DIR${NC}"
    else
        echo -e "${YELLOW}创建命令: mkdir -p $HLS_DIR${NC}"
    fi
fi
echo ""

# 检查HLS播放列表文件
echo -e "${BLUE}[2] 检查HLS播放列表...${NC}"
PLAYLIST_FILE="$HLS_DIR/$HLS_PLAYLIST"
if [ -f "$PLAYLIST_FILE" ]; then
    echo -e "${GREEN}✓ 播放列表存在: $PLAYLIST_FILE${NC}"
    
    # 检查文件大小
    FILE_SIZE=$(stat -f%z "$PLAYLIST_FILE" 2>/dev/null || stat -c%s "$PLAYLIST_FILE" 2>/dev/null || echo "0")
    echo "  文件大小: $FILE_SIZE 字节"
    
    # 检查文件是否最近更新（1分钟内）
    if [ $(find "$PLAYLIST_FILE" -mmin -1 2>/dev/null | wc -l) -gt 0 ]; then
        echo -e "${GREEN}✓ 文件最近有更新（正常）${NC}"
    else
        echo -e "${YELLOW}⚠ 文件超过1分钟未更新${NC}"
    fi
    
    # 显示文件内容（前20行）
    echo ""
    echo "播放列表内容（前20行）:"
    head -20 "$PLAYLIST_FILE" | sed 's/^/  /'
else
    echo -e "${RED}✗ 播放列表不存在: $PLAYLIST_FILE${NC}"
    echo -e "${YELLOW}可能原因:${NC}"
    echo "  1. FFmpeg未启动"
    echo "  2. FFmpeg启动失败"
    echo "  3. RTSP连接失败"
    echo "  4. 输出目录配置错误"
fi
echo ""

# 检查TS切片文件
echo -e "${BLUE}[3] 检查TS切片文件...${NC}"
TS_FILES=$(ls -1 "$HLS_DIR"/*.ts 2>/dev/null | wc -l)
if [ $TS_FILES -gt 0 ]; then
    echo -e "${GREEN}✓ 找到 $TS_FILES 个TS切片文件${NC}"
    
    # 显示最新的几个文件
    echo "最新的TS文件:"
    ls -lt "$HLS_DIR"/*.ts 2>/dev/null | head -5 | awk '{print "  " $9 " (" $5 " 字节, " $6 " " $7 " " $8 ")"}'
    
    # 检查文件是否最近更新
    RECENT_TS=$(find "$HLS_DIR" -name "*.ts" -mmin -1 2>/dev/null | wc -l)
    if [ $RECENT_TS -gt 0 ]; then
        echo -e "${GREEN}✓ 有 $RECENT_TS 个TS文件最近更新（正常）${NC}"
    else
        echo -e "${YELLOW}⚠ 没有TS文件最近更新${NC}"
    fi
else
    echo -e "${RED}✗ 未找到TS切片文件${NC}"
fi
echo ""

# 检查FFmpeg进程
echo -e "${BLUE}[4] 检查FFmpeg进程...${NC}"
if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
    echo -e "${GREEN}✓ FFmpeg进程运行中 (PID: $PID)${NC}"
    
    # 显示进程信息
    ps -p $PID -o pid,user,cmd --no-headers 2>/dev/null | sed 's/^/  /'
else
    echo -e "${RED}✗ FFmpeg进程未运行${NC}"
    echo -e "${YELLOW}启动命令: ./scripts/start_stream.sh${NC}"
fi
echo ""

# 检查Nginx配置（如果使用Nginx）
echo -e "${BLUE}[5] 检查Nginx配置...${NC}"
if command -v nginx &> /dev/null; then
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx服务正在运行${NC}"
        
        # 检查Nginx配置
        if [ -f /etc/nginx/sites-enabled/rtsp-stream ]; then
            echo -e "${GREEN}✓ Nginx配置文件已启用${NC}"
            
            # 检查路径映射
            if grep -q "location /hls/" /etc/nginx/sites-enabled/rtsp-stream; then
                ALIAS_PATH=$(grep -A 1 "location /hls/" /etc/nginx/sites-enabled/rtsp-stream | grep "alias" | awk '{print $2}' | tr -d ';')
                echo "  HLS路径映射: /hls/ -> $ALIAS_PATH"
                
                if [ "$ALIAS_PATH" = "/var/www/hls/" ] || [ "$ALIAS_PATH" = "/var/www/hls" ]; then
                    if [ "$HLS_DIR" = "/var/www/hls" ]; then
                        echo -e "${GREEN}✓ 路径配置匹配${NC}"
                    else
                        echo -e "${YELLOW}⚠ 路径不匹配:${NC}"
                        echo "  Nginx配置: $ALIAS_PATH"
                        echo "  FFmpeg输出: $HLS_DIR"
                        echo -e "${YELLOW}需要修改配置文件中的 HLS_OUTPUT_DIR 为 /var/www/hls${NC}"
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Nginx配置文件未启用${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Nginx服务未运行${NC}"
    fi
else
    echo -e "${YELLOW}ℹ Nginx未安装（使用Python HTTP服务器）${NC}"
fi
echo ""

# 测试HTTP访问
echo -e "${BLUE}[6] 测试HTTP访问...${NC}"
if command -v curl &> /dev/null; then
    # 测试Nginx路径
    if systemctl is-active --quiet nginx 2>/dev/null; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/hls/stream.m3u8 2>/dev/null)
        if [ "$HTTP_STATUS" = "200" ]; then
            echo -e "${GREEN}✓ HTTP访问正常: http://localhost/hls/stream.m3u8${NC}"
        else
            echo -e "${RED}✗ HTTP访问失败: http://localhost/hls/stream.m3u8 (状态码: $HTTP_STATUS)${NC}"
        fi
    fi
    
    # 测试Python服务器路径
    if lsof -Pi :8080 -sTCP:LISTEN > /dev/null 2>&1; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/hls/stream.m3u8 2>/dev/null)
        if [ "$HTTP_STATUS" = "200" ]; then
            echo -e "${GREEN}✓ HTTP访问正常: http://localhost:8080/hls/stream.m3u8${NC}"
        else
            echo -e "${RED}✗ HTTP访问失败: http://localhost:8080/hls/stream.m3u8 (状态码: $HTTP_STATUS)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}ℹ curl未安装，跳过HTTP测试${NC}"
fi
echo ""

# 总结和建议
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  检查完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 提供修复建议
if [ ! -f "$PLAYLIST_FILE" ]; then
    echo -e "${YELLOW}修复建议:${NC}"
    echo "  1. 检查FFmpeg是否运行: ps aux | grep ffmpeg"
    echo "  2. 查看FFmpeg日志: tail -f $FFMPEG_LOG"
    echo "  3. 检查RTSP连接: ffmpeg -rtsp_transport tcp -i \"$RTSP_URL\" -t 5 -f null -"
    echo "  4. 确保配置文件中的 HLS_OUTPUT_DIR 设置为 /var/www/hls"
    echo "  5. 重启转流服务: ./scripts/restart_stream.sh"
fi
