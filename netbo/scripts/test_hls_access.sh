#!/bin/bash

# 测试HLS文件访问脚本
# 用于诊断Ubuntu部署中的HLS访问问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HLS访问测试工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 获取本机IP
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")

# 测试URL
TEST_URLS=(
    "http://localhost/hls/stream.m3u8"
    "http://$LOCAL_IP/hls/stream.m3u8"
    "http://127.0.0.1/hls/stream.m3u8"
)

echo -e "${BLUE}[1/4] 检查HLS文件是否存在...${NC}"
HLS_FILE="/var/www/hls/stream.m3u8"
if [ -f "$HLS_FILE" ]; then
    echo -e "${GREEN}✓ HLS文件存在: $HLS_FILE${NC}"
    echo "文件信息:"
    ls -lh "$HLS_FILE"
    echo ""
    echo "文件内容（前10行）:"
    head -10 "$HLS_FILE"
else
    echo -e "${RED}✗ HLS文件不存在: $HLS_FILE${NC}"
    echo -e "${YELLOW}请检查转流服务是否运行${NC}"
fi
echo ""

echo -e "${BLUE}[2/4] 检查文件权限...${NC}"
if [ -f "$HLS_FILE" ]; then
    PERM=$(stat -c "%a" "$HLS_FILE" 2>/dev/null || stat -f "%OLp" "$HLS_FILE" 2>/dev/null)
    OWNER=$(stat -c "%U:%G" "$HLS_FILE" 2>/dev/null || stat -f "%Su:%Sg" "$HLS_FILE" 2>/dev/null)
    echo "权限: $PERM"
    echo "所有者: $OWNER"
    
    if [ ! -r "$HLS_FILE" ]; then
        echo -e "${RED}✗ 文件不可读${NC}"
    else
        echo -e "${GREEN}✓ 文件可读${NC}"
    fi
fi
echo ""

echo -e "${BLUE}[3/4] 检查Nginx服务...${NC}"
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo -e "${GREEN}✓ Nginx服务正在运行${NC}"
    
    # 测试Nginx配置
    if sudo nginx -t 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx配置正确${NC}"
    else
        echo -e "${RED}✗ Nginx配置有错误${NC}"
        sudo nginx -t
    fi
else
    echo -e "${RED}✗ Nginx服务未运行${NC}"
    echo -e "${YELLOW}启动Nginx: sudo systemctl start nginx${NC}"
fi
echo ""

echo -e "${BLUE}[4/4] 测试HTTP访问...${NC}"
if command -v curl &> /dev/null; then
    for url in "${TEST_URLS[@]}"; do
        echo "测试: $url"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Accept: application/vnd.apple.mpegurl" "$url" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}  ✓ HTTP 200 OK${NC}"
            
            # 检查Content-Type
            CONTENT_TYPE=$(curl -s -I "$url" 2>/dev/null | grep -i "content-type" | cut -d: -f2 | tr -d '\r\n')
            echo "  Content-Type: $CONTENT_TYPE"
            
            # 检查CORS头
            CORS_ORIGIN=$(curl -s -I "$url" 2>/dev/null | grep -i "access-control-allow-origin" | cut -d: -f2 | tr -d '\r\n')
            if [ -n "$CORS_ORIGIN" ]; then
                echo -e "${GREEN}  ✓ CORS头存在: $CORS_ORIGIN${NC}"
            else
                echo -e "${YELLOW}  ⚠ CORS头缺失${NC}"
            fi
        elif [ "$HTTP_CODE" = "404" ]; then
            echo -e "${RED}  ✗ HTTP 404 Not Found${NC}"
            echo -e "${YELLOW}  请检查Nginx配置中的路径映射${NC}"
        elif [ "$HTTP_CODE" = "403" ]; then
            echo -e "${RED}  ✗ HTTP 403 Forbidden${NC}"
            echo -e "${YELLOW}  请检查文件权限${NC}"
        elif [ "$HTTP_CODE" = "000" ]; then
            echo -e "${RED}  ✗ 无法连接${NC}"
        else
            echo -e "${YELLOW}  ⚠ HTTP $HTTP_CODE${NC}"
        fi
        echo ""
    done
else
    echo -e "${YELLOW}curl未安装，跳过HTTP测试${NC}"
    echo "安装: sudo apt-get install curl"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  测试完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${CYAN}如果HTTP访问失败，请检查:${NC}"
echo "  1. Nginx配置: sudo nginx -t"
echo "  2. Nginx日志: sudo tail -f /var/log/nginx/error.log"
echo "  3. HLS文件: ls -lh /var/www/hls/"
echo "  4. 文件权限: sudo chmod 644 /var/www/hls/*"
echo "  5. 目录权限: sudo chmod 755 /var/www/hls"
echo ""
