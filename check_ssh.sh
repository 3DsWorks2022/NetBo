#!/bin/bash

# SSH连接诊断脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SSH连接诊断工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 正确的服务器配置
CORRECT_HOST="user@192.168.1.172"
CORRECT_IP="192.168.1.72"

# 错误的服务器（从终端看到的）
WRONG_HOST="user@192.168.1.172"
WRONG_IP="192.168.1.172"

echo -e "${YELLOW}检测到的连接信息:${NC}"
echo "  终端显示: $WRONG_HOST"
echo "  脚本配置: $CORRECT_HOST"
echo ""

# 步骤1: 测试网络连通性
echo -e "${BLUE}[1/4] 测试网络连通性...${NC}"

echo "测试正确的IP: $CORRECT_IP"
if ping -c 2 -W 2 $CORRECT_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ $CORRECT_IP 可达${NC}"
else
    echo -e "${RED}✗ $CORRECT_IP 不可达${NC}"
fi

echo "测试错误的IP: $WRONG_IP"
if ping -c 2 -W 2 $WRONG_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ $WRONG_IP 可达${NC}"
else
    echo -e "${RED}✗ $WRONG_IP 不可达${NC}"
fi
echo ""

# 步骤2: 测试SSH端口
echo -e "${BLUE}[2/4] 测试SSH端口...${NC}"

test_ssh_port() {
    local host=$1
    local ip=$(echo $host | cut -d'@' -f2)
    if timeout 3 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null; then
        echo -e "${GREEN}✓ $ip:22 SSH端口开放${NC}"
        return 0
    else
        echo -e "${RED}✗ $ip:22 SSH端口不可访问${NC}"
        return 1
    fi
}

test_ssh_port "$CORRECT_HOST"
test_ssh_port "$WRONG_HOST"
echo ""

# 步骤3: 测试SSH连接
echo -e "${BLUE}[3/4] 测试SSH连接...${NC}"

test_ssh_connection() {
    local host=$1
    echo "测试连接: $host"
    
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes $host "echo '连接成功'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $host 连接成功（使用密钥认证）${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ $host 需要密码认证或连接失败${NC}"
        return 1
    fi
}

test_ssh_connection "$CORRECT_HOST"
test_ssh_connection "$WRONG_HOST"
echo ""

# 步骤4: 提供解决方案
echo -e "${BLUE}[4/4] 诊断结果和建议${NC}"
echo ""

echo -e "${CYAN}问题分析:${NC}"
echo "  1. 您尝试连接的是: $WRONG_HOST"
echo "  2. 脚本配置的是: $CORRECT_HOST"
echo "  3. 这两个地址不同，请确认正确的服务器地址"
echo ""

echo -e "${CYAN}解决方案:${NC}"
echo ""
echo -e "${YELLOW}方案1: 使用正确的服务器地址${NC}"
echo "  正确的地址: $CORRECT_HOST"
echo "  密码: 123456"
echo ""
echo "  手动测试连接:"
echo "    ssh $CORRECT_HOST"
echo ""
echo "  或使用部署脚本:"
echo "    ./install_to_ubuntu.sh"
echo ""

echo -e "${YELLOW}方案2: 如果 $WRONG_HOST 是正确的服务器${NC}"
echo "  需要修改脚本配置:"
echo "    REMOTE_HOST=\"$WRONG_HOST\""
echo "    REMOTE_PASSWORD=\"正确的密码\""
echo ""

echo -e "${YELLOW}方案3: 检查SSH配置${NC}"
echo "  查看 ~/.ssh/config 文件，检查是否有别名配置"
echo "  查看 ~/.ssh/known_hosts，可能需要删除旧的主机密钥"
echo ""

echo -e "${CYAN}常见问题排查:${NC}"
echo "  1. 密码错误 → 检查密码是否正确"
echo "  2. 服务器地址错误 → 确认正确的IP和用户名"
echo "  3. SSH服务未运行 → 在服务器上检查: sudo systemctl status ssh"
echo "  4. 防火墙阻止 → 检查防火墙设置"
echo "  5. 连接被拒绝 → 检查SSH配置和用户权限"
echo ""
