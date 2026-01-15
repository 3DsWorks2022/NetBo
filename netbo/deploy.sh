#!/bin/bash

# 远程部署脚本
# 使用方法: ./deploy.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 远程服务器配置
REMOTE_HOST="user@192.168.1.172"
REMOTE_PASSWORD="123456"
REMOTE_DIR="~/rtsp-stream"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RTSP转HLS服务远程部署${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "目标服务器: ${YELLOW}$REMOTE_HOST${NC}"
echo -e "部署目录: ${YELLOW}$REMOTE_DIR${NC}"
echo ""

# 检查sshpass是否安装（用于自动输入密码）
USE_SSHPASS=false
if command -v sshpass &> /dev/null; then
    USE_SSHPASS=true
    # 使用环境变量方式传递密码，避免shell解析问题
    export SSHPASS="$REMOTE_PASSWORD"
    SSH_CMD="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    SCP_CMD="sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    RSYNC_RSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    echo -e "${GREEN}✓ 检测到sshpass，将自动输入密码${NC}"
else
    echo -e "${YELLOW}提示: 未安装sshpass，将需要手动输入密码${NC}"
    echo -e "${YELLOW}安装sshpass: brew install hudochenkov/sshpass/sshpass (macOS)${NC}"
    echo -e "${YELLOW}或使用: brew install sshpass${NC}"
    echo ""
    SSH_CMD="ssh -o StrictHostKeyChecking=no"
    SCP_CMD="scp -o StrictHostKeyChecking=no"
    RSYNC_RSH="ssh -o StrictHostKeyChecking=no"
fi
echo ""

# 步骤1: 测试SSH连接
echo -e "${BLUE}[1/5] 测试SSH连接...${NC}"
if [ "$USE_SSHPASS" = true ]; then
    # 使用sshpass测试连接
    if sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=10 \
       $REMOTE_HOST "echo '连接成功'" 2>&1; then
        echo -e "${GREEN}✓ SSH连接成功${NC}"
    else
        echo -e "${RED}✗ SSH连接失败${NC}"
        echo -e "${YELLOW}尝试诊断问题...${NC}"
        # 测试网络连通性
        if ping -c 1 192.168.1.72 > /dev/null 2>&1; then
            echo "✓ 网络连通正常"
        else
            echo "✗ 无法ping通服务器，请检查网络"
        fi
        echo ""
        echo -e "${YELLOW}如果密码正确，请尝试手动连接:${NC}"
        echo "  ssh $REMOTE_HOST"
        exit 1
    fi
else
    echo -e "${YELLOW}请手动输入SSH密码进行连接测试...${NC}"
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
       $REMOTE_HOST "echo '连接成功'" 2>&1; then
        echo -e "${GREEN}✓ SSH连接成功${NC}"
    else
        echo -e "${RED}✗ SSH连接失败${NC}"
        exit 1
    fi
fi
echo ""

# 步骤2: 创建远程目录
echo -e "${BLUE}[2/5] 创建远程目录...${NC}"
if [ "$USE_SSHPASS" = true ]; then
    sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $REMOTE_HOST "mkdir -p $REMOTE_DIR" 2>&1
else
    ssh -o StrictHostKeyChecking=no $REMOTE_HOST "mkdir -p $REMOTE_DIR" 2>&1
fi
echo -e "${GREEN}✓ 远程目录已创建${NC}"
echo ""

# 步骤3: 传输项目文件
echo -e "${BLUE}[3/5] 传输项目文件...${NC}"

# 需要传输的文件和目录
FILES_TO_TRANSFER=(
    "config"
    "scripts"
    "web"
    "nginx"
    "systemd"
    "install.sh"
    "install_ubuntu.sh"
    "start_web.sh"
    "README.md"
    "README_UBUNTU.md"
    "README_MACOS.md"
)

# 排除的文件
EXCLUDE_PATTERNS=(
    "*.log"
    "*.pid"
    "hls_output"
    "logs"
    ".git"
    "__pycache__"
    "*.pyc"
)

# 使用rsync传输（如果可用）
if command -v rsync &> /dev/null; then
    echo "使用rsync传输文件..."
    if [ "$USE_SSHPASS" = true ]; then
        rsync -avz \
            --rsh="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
            "$PROJECT_ROOT/" "$REMOTE_HOST:$REMOTE_DIR/" \
            --exclude='.git' \
            --exclude='*.log' \
            --exclude='*.pid' \
            --exclude='hls_output' \
            --exclude='logs' \
            --exclude='.DS_Store' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --progress
    else
        rsync -avz \
            "$PROJECT_ROOT/" "$REMOTE_HOST:$REMOTE_DIR/" \
            --exclude='.git' \
            --exclude='*.log' \
            --exclude='*.pid' \
            --exclude='hls_output' \
            --exclude='logs' \
            --exclude='.DS_Store' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --progress
    fi
else
    # 使用scp传输
    echo "使用scp传输文件..."
    for item in "${FILES_TO_TRANSFER[@]}"; do
        if [ -e "$PROJECT_ROOT/$item" ]; then
            echo "  传输: $item"
            if [ "$USE_SSHPASS" = true ]; then
                sshpass -e scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                    "$PROJECT_ROOT/$item" "$REMOTE_HOST:$REMOTE_DIR/" 2>&1 || true
            else
                scp -r -o StrictHostKeyChecking=no \
                    "$PROJECT_ROOT/$item" "$REMOTE_HOST:$REMOTE_DIR/" 2>&1 || true
            fi
        fi
    done
fi

echo -e "${GREEN}✓ 文件传输完成${NC}"
echo ""

# 步骤4: 设置执行权限
echo -e "${BLUE}[4/5] 设置执行权限...${NC}"
if [ "$USE_SSHPASS" = true ]; then
    sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $REMOTE_HOST "cd $REMOTE_DIR && chmod +x scripts/*.sh *.sh 2>/dev/null || true" 2>&1
else
    ssh -o StrictHostKeyChecking=no $REMOTE_HOST "cd $REMOTE_DIR && chmod +x scripts/*.sh *.sh 2>/dev/null || true" 2>&1
fi
echo -e "${GREEN}✓ 权限设置完成${NC}"
echo ""

# 步骤5: 在远程服务器上安装和配置
echo -e "${BLUE}[5/5] 在远程服务器上安装和配置...${NC}"
echo -e "${YELLOW}正在执行远程安装...${NC}"

# 执行远程安装脚本
if [ "$USE_SSHPASS" = true ]; then
    sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

# 检查系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=$ID
else
    OS_TYPE="unknown"
fi

echo "检测到系统: $OS_TYPE"

# 如果是Ubuntu/Debian，使用Ubuntu安装脚本
if [ "$OS_TYPE" = "ubuntu" ] || [ "$OS_TYPE" = "debian" ]; then
    if [ -f "./install_ubuntu.sh" ]; then
        echo "执行Ubuntu安装脚本..."
        bash ./install_ubuntu.sh
    else
        echo "执行通用安装脚本..."
        bash ./install.sh
    fi
else
    echo "执行通用安装脚本..."
    bash ./install.sh
fi
ENDSSH
else
    ssh -o StrictHostKeyChecking=no $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

# 检查系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=$ID
else
    OS_TYPE="unknown"
fi

echo "检测到系统: $OS_TYPE"

# 如果是Ubuntu/Debian，使用Ubuntu安装脚本
if [ "$OS_TYPE" = "ubuntu" ] || [ "$OS_TYPE" = "debian" ]; then
    if [ -f "./install_ubuntu.sh" ]; then
        echo "执行Ubuntu安装脚本..."
        bash ./install_ubuntu.sh
    else
        echo "执行通用安装脚本..."
        bash ./install.sh
    fi
else
    echo "执行通用安装脚本..."
    bash ./install.sh
fi
ENDSSH
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}远程服务器信息:${NC}"
echo -e "  地址: ${YELLOW}$REMOTE_HOST${NC}"
echo -e "  目录: ${YELLOW}$REMOTE_DIR${NC}"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo -e "  1. SSH登录服务器: ${YELLOW}ssh $REMOTE_HOST${NC}"
echo -e "  2. 进入项目目录: ${YELLOW}cd $REMOTE_DIR${NC}"
echo -e "  3. 编辑配置: ${YELLOW}nano config/stream.conf${NC}"
echo -e "  4. 启动服务: ${YELLOW}./start_web.sh${NC}"
echo ""
echo -e "${BLUE}或直接执行:${NC}"
echo -e "  ${YELLOW}ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./start_web.sh'${NC}"
echo ""
