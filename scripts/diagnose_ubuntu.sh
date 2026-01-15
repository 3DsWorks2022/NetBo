#!/bin/bash

# Ubuntu部署问题诊断脚本
# 使用方法: ./scripts/diagnose_ubuntu.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Ubuntu部署问题诊断${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 检查系统类型
echo -e "${BLUE}[1] 检查系统类型...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}✓ 系统: $PRETTY_NAME${NC}"
else
    echo -e "${RED}✗ 无法检测系统类型${NC}"
fi
echo ""

# 2. 检查依赖
echo -e "${BLUE}[2] 检查依赖...${NC}"
if command -v ffmpeg &> /dev/null; then
    FFMPEG_VERSION=$(ffmpeg -version | head -1)
    echo -e "${GREEN}✓ FFmpeg已安装: $FFMPEG_VERSION${NC}"
else
    echo -e "${RED}✗ FFmpeg未安装${NC}"
    echo -e "${YELLOW}  安装命令: sudo apt-get install -y ffmpeg${NC}"
fi

if command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1)
    echo -e "${GREEN}✓ Nginx已安装: $NGINX_VERSION${NC}"
else
    echo -e "${RED}✗ Nginx未安装${NC}"
    echo -e "${YELLOW}  安装命令: sudo apt-get install -y nginx${NC}"
fi
echo ""

# 3. 检查配置文件
echo -e "${BLUE}[3] 检查配置文件...${NC}"
CONFIG_FILE="$PROJECT_ROOT/config/stream.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo -e "${GREEN}✓ 配置文件存在${NC}"
    
    # 检查RTSP地址
    if [ -z "$RTSP_URL" ]; then
        echo -e "${RED}✗ RTSP_URL未配置${NC}"
    elif [[ "$RTSP_URL" == *"192.168.1.100"* ]] || [[ "$RTSP_URL" == *"示例"* ]]; then
        echo -e "${YELLOW}⚠ RTSP_URL可能是示例地址: $RTSP_URL${NC}"
    else
        echo -e "${GREEN}✓ RTSP_URL已配置: $RTSP_URL${NC}"
    fi
    
    # 检查HLS输出目录
    echo "HLS输出目录: $HLS_OUTPUT_DIR"
    if [[ "$HLS_OUTPUT_DIR" == "./hls_output" ]] || [[ "$HLS_OUTPUT_DIR" == "hls_output" ]]; then
        echo -e "${YELLOW}⚠ HLS输出目录使用相对路径，Ubuntu建议使用: /var/www/hls${NC}"
    fi
else
    echo -e "${RED}✗ 配置文件不存在: $CONFIG_FILE${NC}"
fi
echo ""

# 4. 检查目录权限
echo -e "${BLUE}[4] 检查目录权限...${NC}"
if [ -n "$HLS_OUTPUT_DIR" ]; then
    if [ -d "$HLS_OUTPUT_DIR" ]; then
        echo -e "${GREEN}✓ HLS输出目录存在: $HLS_OUTPUT_DIR${NC}"
        if [ -w "$HLS_OUTPUT_DIR" ]; then
            echo -e "${GREEN}✓ 目录可写${NC}"
        else
            echo -e "${RED}✗ 目录不可写，需要权限修复${NC}"
            echo -e "${YELLOW}  修复命令: sudo chmod 755 $HLS_OUTPUT_DIR${NC}"
            if [[ "$HLS_OUTPUT_DIR" == "/var/www/hls" ]]; then
                echo -e "${YELLOW}  或: sudo chown -R $USER:$USER $HLS_OUTPUT_DIR${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ HLS输出目录不存在: $HLS_OUTPUT_DIR${NC}"
        if [[ "$HLS_OUTPUT_DIR" == "/var/www/hls" ]]; then
            echo -e "${YELLOW}  创建命令: sudo mkdir -p $HLS_OUTPUT_DIR && sudo chmod 755 $HLS_OUTPUT_DIR${NC}"
        else
            echo -e "${YELLOW}  创建命令: mkdir -p $HLS_OUTPUT_DIR${NC}"
        fi
    fi
fi

# 检查日志目录
LOG_DIR="$(dirname "$FFMPEG_LOG")"
if [ -d "$LOG_DIR" ]; then
    echo -e "${GREEN}✓ 日志目录存在: $LOG_DIR${NC}"
else
    echo -e "${YELLOW}⚠ 日志目录不存在，将自动创建${NC}"
fi
echo ""

# 5. 检查Nginx配置
echo -e "${BLUE}[5] 检查Nginx配置...${NC}"
if command -v nginx &> /dev/null; then
    # 检查Nginx是否运行
    if systemctl is-active --quiet nginx 2>/dev/null || pgrep nginx > /dev/null; then
        echo -e "${GREEN}✓ Nginx正在运行${NC}"
    else
        echo -e "${RED}✗ Nginx未运行${NC}"
        echo -e "${YELLOW}  启动命令: sudo systemctl start nginx${NC}"
    fi
    
    # 检查配置文件
    if [ -f /etc/nginx/sites-available/rtsp-stream ]; then
        echo -e "${GREEN}✓ Nginx配置文件存在${NC}"
        if [ -L /etc/nginx/sites-enabled/rtsp-stream ]; then
            echo -e "${GREEN}✓ Nginx配置已启用${NC}"
        else
            echo -e "${YELLOW}⚠ Nginx配置未启用${NC}"
            echo -e "${YELLOW}  启用命令: sudo ln -s /etc/nginx/sites-available/rtsp-stream /etc/nginx/sites-enabled/${NC}"
        fi
        
        # 测试配置
        if sudo nginx -t 2>/dev/null; then
            echo -e "${GREEN}✓ Nginx配置测试通过${NC}"
        else
            echo -e "${RED}✗ Nginx配置测试失败${NC}"
            echo -e "${YELLOW}  查看错误: sudo nginx -t${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Nginx配置文件不存在${NC}"
        echo -e "${YELLOW}  部署命令: sudo cp $PROJECT_ROOT/nginx/nginx.conf /etc/nginx/sites-available/rtsp-stream${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Nginx未安装，跳过检查${NC}"
fi
echo ""

# 6. 检查FFmpeg进程
echo -e "${BLUE}[6] 检查FFmpeg进程...${NC}"
PID_FILE="$PROJECT_ROOT/scripts/ffmpeg.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if ps -p $PID > /dev/null 2>&1; then
        echo -e "${GREEN}✓ FFmpeg进程运行中 (PID: $PID)${NC}"
    else
        echo -e "${RED}✗ FFmpeg进程不存在 (PID文件存在但进程已停止)${NC}"
        echo -e "${YELLOW}  建议删除PID文件: rm $PID_FILE${NC}"
    fi
elif pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
    echo -e "${GREEN}✓ FFmpeg进程运行中 (PID: $PID)${NC}"
else
    echo -e "${YELLOW}⚠ FFmpeg进程未运行${NC}"
    echo -e "${YELLOW}  启动命令: ./scripts/start_stream.sh${NC}"
fi
echo ""

# 7. 检查HLS文件
echo -e "${BLUE}[7] 检查HLS文件...${NC}"
if [ -n "$HLS_OUTPUT_DIR" ] && [ -d "$HLS_OUTPUT_DIR" ]; then
    if [ -f "$HLS_OUTPUT_DIR/stream.m3u8" ]; then
        echo -e "${GREEN}✓ HLS播放列表存在${NC}"
        # 检查文件是否最近更新（1分钟内）
        if [ $(find "$HLS_OUTPUT_DIR/stream.m3u8" -mmin -1 2>/dev/null | wc -l) -gt 0 ]; then
            echo -e "${GREEN}✓ HLS文件最近有更新（正常）${NC}"
        else
            echo -e "${YELLOW}⚠ HLS文件超过1分钟未更新（可能转流失败）${NC}"
        fi
        
        # 统计TS切片
        TS_COUNT=$(ls -1 "$HLS_OUTPUT_DIR"/*.ts 2>/dev/null | wc -l)
        echo "TS切片数量: $TS_COUNT"
    else
        echo -e "${RED}✗ HLS播放列表不存在${NC}"
        echo -e "${YELLOW}  可能原因: FFmpeg未启动或启动失败${NC}"
    fi
else
    echo -e "${YELLOW}⚠ HLS输出目录不存在，无法检查${NC}"
fi
echo ""

# 8. 检查日志
echo -e "${BLUE}[8] 检查日志...${NC}"
if [ -f "$FFMPEG_LOG" ]; then
    echo -e "${GREEN}✓ 日志文件存在: $FFMPEG_LOG${NC}"
    echo -e "${BLUE}最近日志 (最后20行):${NC}"
    tail -20 "$FFMPEG_LOG" 2>/dev/null || echo "无法读取日志"
    
    # 检查常见错误
    if grep -i "error\|failed\|cannot" "$FFMPEG_LOG" | tail -5 > /dev/null 2>&1; then
        echo ""
        echo -e "${RED}发现错误信息:${NC}"
        grep -i "error\|failed\|cannot" "$FFMPEG_LOG" | tail -5
    fi
else
    echo -e "${YELLOW}⚠ 日志文件不存在${NC}"
fi
echo ""

# 9. 检查网络连接（RTSP）
echo -e "${BLUE}[9] 检查RTSP连接...${NC}"
if [ -n "$RTSP_URL" ] && [[ "$RTSP_URL" =~ ^rtsp:// ]]; then
    RTSP_HOST=$(echo "$RTSP_URL" | sed -E 's|rtsp://[^@]*@([^:/]+).*|\1|')
    RTSP_PORT=$(echo "$RTSP_URL" | sed -E 's|rtsp://[^:]+:([0-9]+).*|\1|' || echo "554")
    
    echo "RTSP地址: $RTSP_URL"
    echo "RTSP主机: $RTSP_HOST"
    echo "RTSP端口: $RTSP_PORT"
    
    # 测试端口连通性
    if command -v nc &> /dev/null; then
        if timeout 3 nc -z "$RTSP_HOST" "$RTSP_PORT" 2>/dev/null; then
            echo -e "${GREEN}✓ RTSP端口可访问${NC}"
        else
            echo -e "${RED}✗ RTSP端口不可访问${NC}"
            echo -e "${YELLOW}  可能原因: 网络不通、防火墙阻止、RTSP服务未运行${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ netcat未安装，无法测试端口${NC}"
    fi
else
    echo -e "${YELLOW}⚠ RTSP地址未配置或格式不正确${NC}"
fi
echo ""

# 10. 检查systemd服务
echo -e "${BLUE}[10] 检查systemd服务...${NC}"
if [ -f /etc/systemd/system/rtsp-stream.service ]; then
    echo -e "${GREEN}✓ systemd服务文件存在${NC}"
    
    # 检查服务状态
    if systemctl is-active --quiet rtsp-stream.service 2>/dev/null; then
        echo -e "${GREEN}✓ systemd服务正在运行${NC}"
    elif systemctl is-enabled --quiet rtsp-stream.service 2>/dev/null; then
        echo -e "${YELLOW}⚠ systemd服务已启用但未运行${NC}"
        echo -e "${YELLOW}  启动命令: sudo systemctl start rtsp-stream${NC}"
    else
        echo -e "${YELLOW}⚠ systemd服务未启用${NC}"
    fi
    
    # 检查服务日志
    if systemctl list-units | grep -q rtsp-stream; then
        echo ""
        echo -e "${BLUE}最近服务日志:${NC}"
        sudo journalctl -u rtsp-stream.service -n 10 --no-pager 2>/dev/null || echo "无法读取服务日志"
    fi
else
    echo -e "${YELLOW}⚠ systemd服务未配置${NC}"
fi
echo ""

# 总结
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  诊断完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}常见问题修复:${NC}"
echo -e "  1. 修复HLS目录权限: ${YELLOW}sudo chmod 755 /var/www/hls && sudo chown -R www-data:www-data /var/www/hls${NC}"
echo -e "  2. 更新配置文件路径: ${YELLOW}编辑 config/stream.conf，设置 HLS_OUTPUT_DIR=\"/var/www/hls\"${NC}"
echo -e "  3. 启动Nginx: ${YELLOW}sudo systemctl start nginx${NC}"
echo -e "  4. 启动转流: ${YELLOW}./scripts/start_stream.sh${NC}"
echo -e "  5. 查看详细日志: ${YELLOW}tail -f logs/ffmpeg.log${NC}"
echo ""
