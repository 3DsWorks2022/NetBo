#!/bin/bash

# 一键部署到Ubuntu服务器
# 使用方法: ./install_to_ubuntu.sh
# 功能: 自动传输文件、安装依赖、配置服务、启动服务

# 不使用 set -e，改为手动错误处理，避免非关键步骤失败导致退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 远程服务器配置
REMOTE_HOST="user@192.168.1.172"
REMOTE_PASSWORD="123456"    

REMOTE_DIR="~/rtsp-stream"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  一键部署到Ubuntu服务器              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "目标服务器: ${YELLOW}$REMOTE_HOST${NC}"
echo -e "部署目录: ${YELLOW}$REMOTE_DIR${NC}"
echo -e "项目路径: ${YELLOW}$PROJECT_ROOT${NC}"
echo ""

# 检查sshpass是否安装
USE_SSHPASS=false
if command -v sshpass &> /dev/null; then
    USE_SSHPASS=true
    export SSHPASS="$REMOTE_PASSWORD"
    echo -e "${GREEN}✓ 检测到sshpass，将自动输入密码${NC}"
else
    echo -e "${YELLOW}⚠ 未安装sshpass，将需要手动输入密码${NC}"
    echo -e "${YELLOW}提示: 安装sshpass可自动输入密码${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}  macOS: brew install hudochenkov/sshpass/sshpass${NC}"
    else
        echo -e "${YELLOW}  Linux: sudo apt-get install sshpass${NC}"
    fi
    echo ""
    read -p "按回车继续（将需要手动输入密码）..." -r
    echo ""
fi

# SSH和SCP命令
if [ "$USE_SSHPASS" = true ]; then
    SSH_CMD="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    SCP_CMD="sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    RSYNC_RSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
else
    SSH_CMD="ssh -o StrictHostKeyChecking=no"
    SCP_CMD="scp -o StrictHostKeyChecking=no"
    RSYNC_RSH="ssh -o StrictHostKeyChecking=no"
fi

# 步骤1: 测试SSH连接
echo -e "${BLUE}[1/7] 测试SSH连接...${NC}"
if [ "$USE_SSHPASS" = true ]; then
    if sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=10 $REMOTE_HOST "echo '连接成功'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH连接成功${NC}"
    else
        echo -e "${RED}✗ SSH连接失败${NC}"
        echo -e "${YELLOW}请检查:${NC}"
        echo "  1. 服务器地址是否正确: $REMOTE_HOST"
        echo "  2. 网络是否可达: ping 192.168.1.172"
        echo "  3. SSH服务是否运行"
        exit 1
    fi
else
    echo -e "${YELLOW}请手动输入SSH密码进行连接测试...${NC}"
    if $SSH_CMD -o ConnectTimeout=10 $REMOTE_HOST "echo '连接成功'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH连接成功${NC}"
    else
        echo -e "${RED}✗ SSH连接失败${NC}"
        exit 1
    fi
fi
echo ""

# 步骤2: 创建远程目录
echo -e "${BLUE}[2/7] 创建远程目录...${NC}"
$SSH_CMD $REMOTE_HOST "mkdir -p $REMOTE_DIR" > /dev/null 2>&1
echo -e "${GREEN}✓ 远程目录已创建${NC}"
echo ""

# 步骤3: 传输项目文件
echo -e "${BLUE}[3/7] 传输项目文件...${NC}"

# 优先使用rsync（更高效）
if command -v rsync &> /dev/null; then
    echo "使用rsync传输文件（显示进度）..."
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
            --exclude='node_modules' \
            --progress 2>&1 | grep -E "(sending|sent|total)" || true
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
            --exclude='node_modules' \
            --progress 2>&1 | grep -E "(sending|sent|total)" || true
    fi
else
    # 使用scp传输
    echo "使用scp传输文件..."
    echo -e "${YELLOW}提示: 建议安装rsync以获得更好的传输效果${NC}"
    echo ""
    
    # 传输目录
    DIRS_TO_TRANSFER=(
        "config"
        "scripts"
        "web"
        "nginx"
        "systemd"
    )
    
    # 传输文件
    FILES_TO_TRANSFER=(
        "install.sh"
        "install_ubuntu.sh"
        "install_ubuntu_nosudo.sh"
        "start_web.sh"
        "install_to_ubuntu.sh"
    )
    
    # 传输所有.md文件
    MD_FILES=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" -type f)
    
    echo "传输目录..."
    for item in "${DIRS_TO_TRANSFER[@]}"; do
        if [ -d "$PROJECT_ROOT/$item" ]; then
            echo "  传输目录: $item"
            $SCP_CMD -r "$PROJECT_ROOT/$item" "$REMOTE_HOST:$REMOTE_DIR/" > /dev/null 2>&1 || true
        fi
    done
    
    echo "传输文件..."
    for item in "${FILES_TO_TRANSFER[@]}"; do
        if [ -f "$PROJECT_ROOT/$item" ]; then
            echo "  传输文件: $item"
            $SCP_CMD "$PROJECT_ROOT/$item" "$REMOTE_HOST:$REMOTE_DIR/" > /dev/null 2>&1 || true
        fi
    done
    
    # 传输README文件
    if [ -n "$MD_FILES" ]; then
        echo "传输文档文件..."
        echo "$MD_FILES" | while read -r md_file; do
            if [ -f "$md_file" ]; then
                filename=$(basename "$md_file")
                echo "  传输: $filename"
                $SCP_CMD "$md_file" "$REMOTE_HOST:$REMOTE_DIR/" > /dev/null 2>&1 || true
            fi
        done
    fi
fi

echo -e "${GREEN}✓ 文件传输完成${NC}"

# 验证关键文件是否传输成功
echo -e "${BLUE}验证关键文件...${NC}"
CRITICAL_FILES=(
    "web/index.html"
    "web/http_server.py"
    "start_web.sh"
    "scripts/start_stream.sh"
    "scripts/check_hls.sh"
    "scripts/test_hls_access.sh"
    "nginx/nginx.conf"
    "config/stream.conf"
)

ALL_FILES_OK=true
for file in "${CRITICAL_FILES[@]}"; do
    if $SSH_CMD $REMOTE_HOST "test -f $REMOTE_DIR/$file" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $file${NC}"
    else
        echo -e "${RED}  ✗ $file (缺失)${NC}"
        ALL_FILES_OK=false
    fi
done

if [ "$ALL_FILES_OK" = false ]; then
    echo -e "${YELLOW}⚠ 部分关键文件缺失，尝试重新传输...${NC}"
    # 重新传输缺失的文件
    for file in "${CRITICAL_FILES[@]}"; do
        if ! $SSH_CMD $REMOTE_HOST "test -f $REMOTE_DIR/$file" > /dev/null 2>&1; then
            if [ -f "$PROJECT_ROOT/$file" ]; then
                echo "  重新传输: $file"
                $SCP_CMD "$PROJECT_ROOT/$file" "$REMOTE_HOST:$REMOTE_DIR/$file" > /dev/null 2>&1 || true
            elif [ -d "$PROJECT_ROOT/$file" ]; then
                echo "  重新传输目录: $file"
                $SCP_CMD -r "$PROJECT_ROOT/$file" "$REMOTE_HOST:$REMOTE_DIR/$(dirname $file)/" > /dev/null 2>&1 || true
            fi
        fi
    done
fi
echo ""

# 步骤4: 设置执行权限
echo -e "${BLUE}[4/7] 设置执行权限...${NC}"
$SSH_CMD $REMOTE_HOST "cd $REMOTE_DIR && chmod +x scripts/*.sh *.sh web/*.py 2>/dev/null || true" > /dev/null 2>&1
echo -e "${GREEN}✓ 权限设置完成${NC}"
echo ""

# 步骤5: 在远程服务器上执行安装
echo -e "${BLUE}[5/7] 在远程服务器上安装和配置...${NC}"
echo -e "${YELLOW}正在执行远程安装（这可能需要几分钟）...${NC}"
echo ""

# 执行远程安装脚本
$SSH_CMD $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

echo "=========================================="
echo "  开始安装RTSP转HLS服务"
echo "=========================================="
echo ""

# 检查系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=$ID
    OS_NAME=$PRETTY_NAME
else
    OS_TYPE="unknown"
    OS_NAME="Unknown"
fi

echo "检测到系统: $OS_NAME"
echo ""

# 如果是Ubuntu/Debian，使用Ubuntu安装脚本
if [ "$OS_TYPE" = "ubuntu" ] || [ "$OS_TYPE" = "debian" ]; then
    if [ -f "./install_ubuntu.sh" ]; then
        echo "执行Ubuntu安装脚本..."
        echo ""
        bash ./install_ubuntu.sh
    else
        echo "执行通用安装脚本..."
        bash ./install.sh
    fi
else
    echo "执行通用安装脚本..."
    bash ./install.sh
fi

echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
ENDSSH

INSTALL_EXIT_CODE=$?

if [ $INSTALL_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}✗ 远程安装过程中出现错误${NC}"
    echo -e "${YELLOW}请检查上面的错误信息${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ 远程安装完成${NC}"
echo ""

# 验证安装结果并应用Nginx配置
echo -e "${BLUE}验证安装结果并应用配置...${NC}"
$SSH_CMD $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

echo "检查关键组件..."
# 检查FFmpeg
if command -v ffmpeg &> /dev/null; then
    echo "  ✓ FFmpeg已安装"
else
    echo "  ✗ FFmpeg未安装"
fi

# 检查Nginx
if command -v nginx &> /dev/null; then
    echo "  ✓ Nginx已安装"
    
    # 应用新的Nginx配置
    if [ -f "nginx/nginx.conf" ]; then
        echo "  应用Nginx配置..."
        sudo cp nginx/nginx.conf /etc/nginx/sites-available/rtsp-stream
        
        # 确保软链接存在
        if [ ! -L /etc/nginx/sites-enabled/rtsp-stream ]; then
            sudo ln -s /etc/nginx/sites-available/rtsp-stream /etc/nginx/sites-enabled/rtsp-stream 2>/dev/null || true
        fi
        
        # 测试配置
        if sudo nginx -t 2>/dev/null; then
            echo "  ✓ Nginx配置正确"
            # 重启Nginx以应用新配置
            sudo systemctl restart nginx 2>/dev/null || true
            echo "  ✓ Nginx已重启（应用新配置）"
        else
            echo "  ✗ Nginx配置有错误"
            sudo nginx -t
        fi
    fi
    
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo "  ✓ Nginx服务正在运行"
    else
        echo "  ⚠ Nginx服务未运行，尝试启动..."
        sudo systemctl start nginx 2>/dev/null || true
        sleep 2
        if systemctl is-active --quiet nginx 2>/dev/null; then
            echo "  ✓ Nginx服务已启动"
        else
            echo "  ✗ Nginx服务启动失败"
        fi
    fi
else
    echo "  ⚠ Nginx未安装（将使用Python HTTP服务器）"
fi

# 检查Python
if command -v python3 &> /dev/null || command -v python &> /dev/null; then
    echo "  ✓ Python已安装"
else
    echo "  ✗ Python未安装"
fi

# 检查HLS目录
if [ -d "/var/www/hls" ]; then
    echo "  ✓ HLS目录已创建: /var/www/hls"
    # 确保目录权限正确
    sudo chmod 755 /var/www/hls 2>/dev/null || true
    sudo chown www-data:www-data /var/www/hls 2>/dev/null || true
else
    echo "  ⚠ HLS目录不存在，创建中..."
    sudo mkdir -p /var/www/hls
    sudo chmod 755 /var/www/hls
    sudo chown www-data:www-data /var/www/hls
    echo "  ✓ HLS目录已创建"
fi

# 检查配置文件
if [ -f "config/stream.conf" ]; then
    echo "  ✓ 配置文件存在"
    RTSP_URL=$(grep "^RTSP_URL=" config/stream.conf | cut -d'"' -f2)
    if [[ "$RTSP_URL" == *"192.168.1.100"* ]] || [[ "$RTSP_URL" == *"示例"* ]]; then
        echo "  ⚠ RTSP地址未配置（需要手动配置）"
    else
        echo "  ✓ RTSP地址已配置: $RTSP_URL"
    fi
    
    # 确保HLS输出目录配置正确（Ubuntu环境）
    if grep -q 'HLS_OUTPUT_DIR="./hls_output"' config/stream.conf; then
        echo "  更新HLS输出目录配置为Ubuntu路径..."
        sed -i 's|HLS_OUTPUT_DIR="./hls_output"|HLS_OUTPUT_DIR="/var/www/hls"|' config/stream.conf
        echo "  ✓ 已更新为: /var/www/hls"
    fi
else
    echo "  ✗ 配置文件不存在"
fi

echo ""
echo "配置systemd服务（开机自启）..."
# 获取当前用户和项目路径
CURRENT_USER=$(whoami)
PROJECT_PATH=$(pwd)

echo "  当前用户: $CURRENT_USER"
echo "  项目路径: $PROJECT_PATH"

# 优先配置rtsp-web.service（启动start_web.sh，包含转流+Web服务器）
if [ -f "systemd/rtsp-web.service" ]; then
    echo "  配置rtsp-web.service（转流+Web服务器）..."
    
    # 创建服务文件，替换占位符
    SERVICE_FILE="/tmp/rtsp-web.service"
    sed "s|%USER%|$CURRENT_USER|g; s|%WORKDIR%|$PROJECT_PATH|g" \
        systemd/rtsp-web.service > "$SERVICE_FILE"
    
    # 复制到systemd目录
    sudo cp "$SERVICE_FILE" /etc/systemd/system/rtsp-web.service
    rm -f "$SERVICE_FILE"
    
    echo "  ✓ rtsp-web.service已创建"
else
    echo "  ⚠ rtsp-web.service文件不存在"
fi

# 配置rtsp-stream.service（仅转流服务，作为备选）
if [ -f "systemd/rtsp-stream.service" ]; then
    echo "  配置rtsp-stream.service（仅转流服务）..."
    
    # 创建服务文件，替换占位符
    SERVICE_FILE="/tmp/rtsp-stream.service"
    sed "s|%USER%|$CURRENT_USER|g; s|%WORKDIR%|$PROJECT_PATH|g" \
        systemd/rtsp-stream.service > "$SERVICE_FILE"
    
    # 复制到systemd目录
    sudo cp "$SERVICE_FILE" /etc/systemd/system/rtsp-stream.service
    rm -f "$SERVICE_FILE"
    
    echo "  ✓ rtsp-stream.service已创建"
else
    echo "  ⚠ rtsp-stream.service文件不存在"
fi

# 重新加载systemd
if [ -f "systemd/rtsp-web.service" ] || [ -f "systemd/rtsp-stream.service" ]; then
    sudo systemctl daemon-reload
    echo "  ✓ systemd已重新加载"
    
    # 优先启用rtsp-web.service（如果存在）
    if [ -f "systemd/rtsp-web.service" ]; then
        sudo systemctl enable rtsp-web.service 2>/dev/null || true
        echo "  ✓ rtsp-web.service已启用（开机自启，启动start_web.sh）"
    fi
    
    # 启用rtsp-stream.service（如果存在且rtsp-web不存在）
    if [ -f "systemd/rtsp-stream.service" ] && [ ! -f "systemd/rtsp-web.service" ]; then
        sudo systemctl enable rtsp-stream.service 2>/dev/null || true
        echo "  ✓ rtsp-stream.service已启用（开机自启）"
    fi
else
    echo "  ⚠ 没有找到systemd服务文件，跳过自动启动配置"
fi

echo ""
echo "配置防火墙..."
# 配置防火墙（UFW）
if command -v ufw &> /dev/null; then
    echo "  配置UFW防火墙..."
    
    # 检查防火墙状态
    if sudo ufw status | grep -q "Status: active"; then
        echo "  ✓ 防火墙已启用"
    else
        echo "  ⚠ 防火墙未启用，正在启用..."
        echo "y" | sudo ufw --force enable 2>/dev/null || true
    fi
    
    # 开放HTTP端口（Nginx）
    if sudo ufw status | grep -q "80/tcp"; then
        echo "  ✓ 端口80已开放"
    else
        sudo ufw allow 80/tcp 2>/dev/null || true
        echo "  ✓ 已开放端口80（HTTP）"
    fi
    
    # 开放Python HTTP服务器端口
    if sudo ufw status | grep -q "8080/tcp"; then
        echo "  ✓ 端口8080已开放"
    else
        sudo ufw allow 8080/tcp 2>/dev/null || true
        echo "  ✓ 已开放端口8080（Python HTTP服务器）"
    fi
    
    # 显示防火墙状态
    echo ""
    echo "  当前防火墙规则:"
    sudo ufw status | grep -E "(80|8080|Status)" | sed 's/^/    /'
else
    echo "  ⚠ UFW未安装，跳过防火墙配置"
    echo "  如需配置防火墙，请手动执行:"
    echo "    sudo ufw allow 80/tcp"
    echo "    sudo ufw allow 8080/tcp"
fi

echo ""
echo "启动并启用Nginx（如果已安装）..."
# 确保Nginx开机自启
if command -v nginx &> /dev/null; then
    sudo systemctl enable nginx 2>/dev/null || true
    if systemctl is-enabled --quiet nginx 2>/dev/null; then
        echo "  ✓ Nginx已设置为开机自启"
    fi
fi
ENDSSH

echo ""

# 步骤6: 自动启动服务
echo -e "${BLUE}[6/7] 自动启动服务...${NC}"
echo -e "${YELLOW}正在启动RTSP转HLS服务（后台运行）...${NC}"

# 在远程服务器上启动服务（使用nohup确保后台运行）
$SSH_CMD $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

echo "=========================================="
echo "  启动RTSP转HLS服务"
echo "=========================================="
echo ""

# 检查配置文件
if [ ! -f "config/stream.conf" ]; then
    echo "❌ 错误: 配置文件不存在"
    exit 1
fi

# 加载配置
source config/stream.conf 2>/dev/null || true

# 检查RTSP地址是否配置
if [ -z "$RTSP_URL" ] || [[ "$RTSP_URL" == *"192.168.1.100"* ]] || [[ "$RTSP_URL" == *"示例"* ]]; then
    echo "⚠️  警告: RTSP地址未正确配置"
    echo "当前RTSP_URL: $RTSP_URL"
    echo ""
    echo "尝试使用 start_web.sh 启动服务（可能会提示配置RTSP地址）..."
    echo ""
    # 即使RTSP地址未配置，也尝试启动，让start_web.sh来处理
fi

# 方法1: 优先使用systemd Web服务启动（如果已配置）
if [ -f /etc/systemd/system/rtsp-web.service ]; then
    echo "检测到systemd Web服务，使用systemd启动（转流+Web服务器）..."
    
    # 停止可能存在的旧服务
    sudo systemctl stop rtsp-web.service 2>/dev/null || true
    sudo systemctl stop rtsp-stream.service 2>/dev/null || true
    sleep 1
    
    # 启动Web服务
    if sudo systemctl start rtsp-web.service 2>/dev/null; then
        sleep 3
        
        # 检查服务状态
        if sudo systemctl is-active --quiet rtsp-web.service; then
            echo "✅ systemd Web服务已启动"
            echo "✅ 服务已设置为开机自启"
            
            # 等待HLS文件生成
            HLS_DIR=${HLS_OUTPUT_DIR:-/var/www/hls}
            echo "等待HLS文件生成..."
            for i in {1..15}; do
                if [ -f "$HLS_DIR/stream.m3u8" ]; then
                    echo "✅ HLS文件已生成"
                    break
                fi
                sleep 1
            done
            
            # 显示服务状态
            echo ""
            echo "服务状态:"
            sudo systemctl status rtsp-web.service --no-pager -l | head -10
            echo ""
            echo "✅ Web服务已配置为开机自动启动"
        else
            echo "⚠️  systemd Web服务启动失败，查看错误信息..."
            sudo systemctl status rtsp-web.service --no-pager -l | head -15
            echo ""
            echo "尝试使用转流服务..."
            # 继续尝试转流服务
        fi
    else
        echo "⚠️  systemd Web服务启动失败，尝试转流服务..."
        # 继续尝试转流服务
    fi
fi

# 方法1.5: 如果Web服务不可用，尝试转流服务
if [ -f /etc/systemd/system/rtsp-stream.service ] && ! sudo systemctl is-active --quiet rtsp-web.service 2>/dev/null; then
    echo "使用systemd转流服务启动..."
    
    # 停止可能存在的旧服务
    sudo systemctl stop rtsp-stream.service 2>/dev/null || true
    sleep 1
    
    # 启动转流服务
    if sudo systemctl start rtsp-stream.service 2>/dev/null; then
        sleep 3
        
        # 检查服务状态
        if sudo systemctl is-active --quiet rtsp-stream.service; then
            echo "✅ systemd转流服务已启动"
            echo "✅ 服务已设置为开机自启"
            echo "⚠️  注意: 只启动了转流服务，Web服务器需要手动启动"
            
            # 等待HLS文件生成
            HLS_DIR=${HLS_OUTPUT_DIR:-/var/www/hls}
            echo "等待HLS文件生成..."
            for i in {1..15}; do
                if [ -f "$HLS_DIR/stream.m3u8" ]; then
                    echo "✅ HLS文件已生成"
                    break
                fi
                sleep 1
            done
        else
            echo "⚠️  systemd转流服务启动失败，尝试直接启动..."
            # 继续尝试方法2
        fi
    else
        echo "⚠️  systemd转流服务启动失败，尝试直接启动..."
        # 继续尝试方法2
    fi
fi

# 如果systemd服务都不可用
if ! sudo systemctl is-active --quiet rtsp-web.service 2>/dev/null &&    ! sudo systemctl is-active --quiet rtsp-stream.service 2>/dev/null; then
    echo "⚠️  systemd服务未配置或启动失败，将使用脚本直接启动"
    echo "提示: 服务不会自动开机启动，建议配置systemd服务"
fi

# 方法2: 使用start_web.sh启动服务（推荐，后台运行）
if ! sudo systemctl is-active --quiet rtsp-web.service 2>/dev/null &&    ! sudo systemctl is-active --quiet rtsp-stream.service 2>/dev/null; then
    echo "使用 start_web.sh 启动服务（转流+Web服务器，后台运行）..."
    echo ""
    
    # 优先使用start_web.sh（启动转流和Web服务器）
    if [ -f "./start_web.sh" ]; then
        echo "执行启动脚本（后台运行）..."
        # 使用nohup在后台运行，并立即返回
        nohup bash ./start_web.sh > /tmp/start_web.log 2>&1 &
        START_PID=$!
        echo "启动脚本已在后台运行 (PID: $START_PID)"
        
        # 等待一下让脚本开始执行
        sleep 3
        
        # 检查FFmpeg进程是否启动
        if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
            FFMPEG_PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
            echo "✅ 转流服务已启动 (FFmpeg PID: $FFMPEG_PID)"
        else
            echo "⏳ 转流服务启动中，请稍后检查..."
        fi
        
        # 检查Python HTTP服务器是否启动
        if pgrep -f "python.*http_server" > /dev/null || lsof -Pi :8080 -sTCP:LISTEN > /dev/null 2>&1; then
            echo "✅ Web服务器已启动（端口8080）"
        else
            echo "⏳ Web服务器启动中，请稍后检查..."
        fi
        
        echo "查看启动日志: tail -f /tmp/start_web.log"
    elif [ -f "./scripts/start_stream.sh" ]; then
        echo "使用 start_stream.sh 启动转流服务（仅转流）..."
        # 使用nohup在后台运行，并立即返回
        nohup bash ./scripts/start_stream.sh > /tmp/start_stream.log 2>&1 &
        START_PID=$!
        echo "启动脚本已在后台运行 (PID: $START_PID)"
        
        # 等待一下让脚本开始执行
        sleep 2
        
        # 检查FFmpeg进程是否启动
        if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
            FFMPEG_PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
            echo "✅ 转流服务已启动 (FFmpeg PID: $FFMPEG_PID)"
        else
            echo "⏳ 转流服务启动中，请稍后检查..."
            echo "查看启动日志: tail -f /tmp/start_stream.log"
        fi
    else
        echo "⚠️  start_web.sh不存在，尝试直接启动FFmpeg..."
        
        # 直接启动FFmpeg（备用方案）
        # 停止可能存在的旧进程
        if [ -f "scripts/stop_stream.sh" ]; then
            ./scripts/stop_stream.sh > /dev/null 2>&1 || true
        fi
        
        # 检查FFmpeg是否安装
        if ! command -v ffmpeg &> /dev/null; then
            echo "❌ 错误: FFmpeg未安装"
            exit 1
        fi
        
        # 确保HLS输出目录存在
        HLS_DIR=${HLS_OUTPUT_DIR:-/var/www/hls}
        if [ ! -d "$HLS_DIR" ]; then
            echo "创建HLS输出目录: $HLS_DIR"
            sudo mkdir -p "$HLS_DIR"
            sudo chmod 755 "$HLS_DIR"
            sudo chown www-data:www-data "$HLS_DIR" 2>/dev/null || true
        fi
        
        # 创建日志目录
        mkdir -p "$(dirname "$FFMPEG_LOG")" 2>/dev/null || true
        
        # 检查RTSP地址
        if [ -z "$RTSP_URL" ] || [[ "$RTSP_URL" == *"192.168.1.100"* ]] || [[ "$RTSP_URL" == *"示例"* ]]; then
            echo "⚠️  RTSP地址未配置，无法启动转流"
            echo "请先配置: nano config/stream.conf"
        else
            # 启动转流
            echo "启动FFmpeg转流..."
            echo "RTSP源: $RTSP_URL"
            echo "HLS输出: $HLS_DIR/stream.m3u8"
            
            HLS_SEGMENT_TIME=${HLS_SEGMENT_TIME:-2}
            HLS_LIST_SIZE=${HLS_LIST_SIZE:-3}
            
            # 启动FFmpeg（后台运行）
            nohup ffmpeg -rtsp_transport tcp \
              -i "$RTSP_URL" \
              -c:v copy \
              -c:a aac -b:a 128k \
              -f hls \
              -hls_time $HLS_SEGMENT_TIME \
              -hls_list_size $HLS_LIST_SIZE \
              -hls_flags delete_segments+independent_segments \
              -hls_segment_filename "$HLS_DIR/stream_%03d.ts" \
              "$HLS_DIR/stream.m3u8" \
              > "$FFMPEG_LOG" 2>&1 &
            
            FFMPEG_PID=$!
            
            # 保存PID
            mkdir -p scripts 2>/dev/null || true
            echo "$FFMPEG_PID" > scripts/ffmpeg.pid
            
            # 等待进程启动
            sleep 3
            
            if ps -p $FFMPEG_PID > /dev/null 2>&1; then
                echo "✅ 转流服务已启动 (PID: $FFMPEG_PID)"
                
                # 等待HLS文件生成
                echo "等待HLS文件生成..."
                for i in {1..15}; do
                    if [ -f "$HLS_DIR/stream.m3u8" ]; then
                        echo "✅ HLS文件已生成"
                        break
                    fi
                    sleep 1
                done
            else
                echo "❌ 转流服务启动失败"
                echo "请检查日志: $FFMPEG_LOG"
            fi
        fi
    fi
fi

echo ""
echo "=========================================="
echo "  服务启动命令已执行（后台运行）"
echo "=========================================="
echo ""
echo "服务已在后台启动，SSH会话将退出"
echo ""
echo "使用以下命令检查服务状态:"
echo "  ./scripts/check_status.sh"
echo "  ps aux | grep ffmpeg"
echo "  tail -f logs/ffmpeg.log"
echo ""
# 确保所有后台进程都能继续运行
disown -a 2>/dev/null || true
ENDSSH

START_EXIT_CODE=$?

if [ $START_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  服务启动过程中出现警告或错误${NC}"
    echo -e "${YELLOW}请检查上面的输出信息${NC}"
    echo ""
else
    echo ""
    echo -e "${GREEN}✓ 服务启动完成${NC}"
    echo ""
fi

# 验证服务状态（等待几秒后检查）
echo -e "${BLUE}等待服务启动并验证状态...${NC}"
sleep 5

$SSH_CMD $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

echo "检查服务状态..."
echo ""

# 检查FFmpeg进程
if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
    echo "✅ FFmpeg进程运行中 (PID: $PID)"
else
    echo "❌ FFmpeg进程未运行"
    echo "查看启动日志:"
    tail -20 /tmp/start_stream.log 2>/dev/null || echo "日志文件不存在"
fi

# 检查HLS文件
HLS_DIR=${HLS_OUTPUT_DIR:-/var/www/hls}
if [ -f "$HLS_DIR/stream.m3u8" ]; then
    echo "✅ HLS播放列表存在: $HLS_DIR/stream.m3u8"
    
    # 检查文件是否最近更新
    if [ $(find "$HLS_DIR/stream.m3u8" -mmin -1 2>/dev/null | wc -l) -gt 0 ]; then
        echo "✅ HLS文件最近有更新（正常）"
    else
        echo "⚠️  警告: HLS文件超过1分钟未更新"
    fi
    
    # 统计TS切片
    TS_COUNT=$(ls -1 "$HLS_DIR"/*.ts 2>/dev/null | wc -l)
    echo "📊 TS切片数量: $TS_COUNT"
else
    echo "⚠️  HLS播放列表不存在（可能还在生成中）"
    echo "等待几秒后再次检查: ./scripts/check_status.sh"
fi

# 检查Nginx
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "✅ Nginx服务正在运行"
else
    echo "⚠️  Nginx服务未运行（将使用Python HTTP服务器）"
fi

echo ""
ENDSSH

echo ""

# 步骤7: 显示部署结果和后续操作
echo -e "${BLUE}[7/9] 部署完成！${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  部署成功！                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}远程服务器信息:${NC}"
echo -e "  地址: ${YELLOW}$REMOTE_HOST${NC}"
echo -e "  目录: ${YELLOW}$REMOTE_DIR${NC}"
echo ""
echo -e "${CYAN}下一步操作:${NC}"
echo ""
echo -e "${GREEN}✓ 服务已自动启动！${NC}"
echo ""
echo -e "${YELLOW}1. 如果RTSP地址未配置，请先编辑配置文件:${NC}"
echo -e "   ssh $REMOTE_HOST"
echo -e "   cd $REMOTE_DIR"
echo -e "   nano config/stream.conf"
echo -e "   然后重启服务: ${YELLOW}./start_web.sh${NC}"
echo ""
echo -e "${YELLOW}2. 访问播放页面:${NC}"
echo -e "   如果使用Nginx: ${YELLOW}http://192.168.1.172/index.html${NC}"
echo -e "   如果使用Python服务器: ${YELLOW}http://192.168.1.172:8080/index.html${NC}"
echo ""
echo -e "${YELLOW}3. 查看服务状态:${NC}"
echo -e "   ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./scripts/check_status.sh'"
echo ""
echo -e "${YELLOW}4. 测试HLS访问（诊断工具）:${NC}"
echo -e "   ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./scripts/test_hls_access.sh'"
echo ""
echo -e "${CYAN}服务管理命令:${NC}"
echo -e "  重启: ${YELLOW}ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./start_web.sh'${NC}"
echo -e "  停止: ${YELLOW}ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./scripts/stop_stream.sh'${NC}"
echo -e "  状态: ${YELLOW}ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./scripts/check_status.sh'${NC}"
echo -e "  诊断: ${YELLOW}ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./scripts/test_hls_access.sh'${NC}"
echo ""
echo -e "${CYAN}已完成的配置:${NC}"
echo -e "${GREEN}✓ systemd Web服务已配置并启用（开机自启，启动start_web.sh）${NC}"
echo -e "${GREEN}✓ 防火墙已配置（开放端口80和8080）${NC}"
echo -e "${GREEN}✓ Nginx已设置为开机自启${NC}"
echo ""
echo -e "${CYAN}重要提示:${NC}"
echo -e "${YELLOW}1. 确保已配置RTSP摄像头地址:${NC} nano config/stream.conf"
echo -e "${YELLOW}2. 如果遇到网络错误，运行诊断工具:${NC} ./scripts/test_hls_access.sh"
echo -e "${YELLOW}3. 检查浏览器控制台（F12）查看详细错误信息${NC}"
echo ""
echo -e "${CYAN}服务管理（systemd）:${NC}"
echo -e "  Web服务（转流+Web服务器）:${NC}"
echo -e "    查看状态: ${YELLOW}sudo systemctl status rtsp-web${NC}"
echo -e "    启动服务: ${YELLOW}sudo systemctl start rtsp-web${NC}"
echo -e "    停止服务: ${YELLOW}sudo systemctl stop rtsp-web${NC}"
echo -e "    重启服务: ${YELLOW}sudo systemctl restart rtsp-web${NC}"
echo -e "    查看日志: ${YELLOW}sudo journalctl -u rtsp-web -f${NC}"
echo ""
echo -e "  转流服务（仅转流）:${NC}"
echo -e "    查看状态: ${YELLOW}sudo systemctl status rtsp-stream${NC}"
echo -e "    启动服务: ${YELLOW}sudo systemctl start rtsp-stream${NC}"
echo -e "    停止服务: ${YELLOW}sudo systemctl stop rtsp-stream${NC}"
echo -e "    重启服务: ${YELLOW}sudo systemctl restart rtsp-stream${NC}"
echo -e "    查看日志: ${YELLOW}sudo journalctl -u rtsp-stream -f${NC}"
echo ""

# 步骤8: 启动/重启服务
echo -e "${BLUE}[8/9] 启动/重启服务...${NC}"
echo ""
echo -e "${YELLOW}是否要立即启动或重启服务？${NC}"
echo -e "  1) 启动服务（如果未运行）"
echo -e "  2) 重启服务（停止后重新启动）"
echo -e "  3) 跳过（服务已在后台启动）"
echo ""
read -p "请选择 [1/2/3] (默认: 3): " -r SERVICE_ACTION
SERVICE_ACTION=${SERVICE_ACTION:-3}

case $SERVICE_ACTION in
    1)
        echo ""
        echo -e "${BLUE}正在启动服务...${NC}"
        $SSH_CMD $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

echo "=========================================="
echo "  启动RTSP转HLS服务"
echo "=========================================="
echo ""

# 优先使用systemd服务
if [ -f /etc/systemd/system/rtsp-web.service ]; then
    echo "使用systemd Web服务启动..."
    sudo systemctl start rtsp-web.service 2>/dev/null || true
    sleep 2
    
    if sudo systemctl is-active --quiet rtsp-web.service; then
        echo "✅ systemd Web服务已启动"
    else
        echo "⚠️  systemd服务启动失败，尝试使用脚本启动..."
        if [ -f "./start_web.sh" ]; then
            nohup bash ./start_web.sh > /tmp/start_web.log 2>&1 &
            echo "✅ 已使用start_web.sh启动服务（后台运行）"
        fi
    fi
elif [ -f /etc/systemd/system/rtsp-stream.service ]; then
    echo "使用systemd转流服务启动..."
    sudo systemctl start rtsp-stream.service 2>/dev/null || true
    sleep 2
    
    if sudo systemctl is-active --quiet rtsp-stream.service; then
        echo "✅ systemd转流服务已启动"
    else
        echo "⚠️  systemd服务启动失败，尝试使用脚本启动..."
        if [ -f "./scripts/start_stream.sh" ]; then
            nohup bash ./scripts/start_stream.sh > /tmp/start_stream.log 2>&1 &
            echo "✅ 已使用start_stream.sh启动服务（后台运行）"
        fi
    fi
else
    echo "systemd服务未配置，使用脚本启动..."
    if [ -f "./start_web.sh" ]; then
        nohup bash ./start_web.sh > /tmp/start_web.log 2>&1 &
        echo "✅ 已使用start_web.sh启动服务（后台运行）"
    elif [ -f "./scripts/start_stream.sh" ]; then
        nohup bash ./scripts/start_stream.sh > /tmp/start_stream.log 2>&1 &
        echo "✅ 已使用start_stream.sh启动服务（后台运行）"
    fi
fi

echo ""
echo "等待服务启动..."
sleep 3

# 检查服务状态
if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
    echo "✅ 转流服务运行中 (PID: $PID)"
else
    echo "⚠️  转流服务未运行，请检查日志"
fi

if lsof -Pi :8080 -sTCP:LISTEN > /dev/null 2>&1 || systemctl is-active --quiet nginx 2>/dev/null; then
    echo "✅ Web服务器运行中"
else
    echo "⚠️  Web服务器未运行"
fi

echo ""
ENDSSH
        echo -e "${GREEN}✓ 服务启动完成${NC}"
        ;;
    2)
        echo ""
        echo -e "${BLUE}正在重启服务...${NC}"
        $SSH_CMD $REMOTE_HOST << 'ENDSSH'
cd ~/rtsp-stream

echo "=========================================="
echo "  重启RTSP转HLS服务"
echo "=========================================="
echo ""

# 停止现有服务
echo "停止现有服务..."
if [ -f /etc/systemd/system/rtsp-web.service ]; then
    sudo systemctl stop rtsp-web.service 2>/dev/null || true
fi
if [ -f /etc/systemd/system/rtsp-stream.service ]; then
    sudo systemctl stop rtsp-stream.service 2>/dev/null || true
fi

# 停止脚本启动的进程
if [ -f "./scripts/stop_stream.sh" ]; then
    bash ./scripts/stop_stream.sh > /dev/null 2>&1 || true
fi

# 清理端口
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
pkill -f "ffmpeg.*stream.m3u8" 2>/dev/null || true

sleep 2
echo "✅ 旧服务已停止"
echo ""

# 启动服务
echo "启动服务..."
if [ -f /etc/systemd/system/rtsp-web.service ]; then
    echo "使用systemd Web服务启动..."
    sudo systemctl start rtsp-web.service 2>/dev/null || true
    sleep 3
    
    if sudo systemctl is-active --quiet rtsp-web.service; then
        echo "✅ systemd Web服务已重启"
    else
        echo "⚠️  systemd服务启动失败，尝试使用脚本启动..."
        if [ -f "./start_web.sh" ]; then
            nohup bash ./start_web.sh > /tmp/start_web.log 2>&1 &
            echo "✅ 已使用start_web.sh重启服务（后台运行）"
        fi
    fi
elif [ -f /etc/systemd/system/rtsp-stream.service ]; then
    echo "使用systemd转流服务启动..."
    sudo systemctl start rtsp-stream.service 2>/dev/null || true
    sleep 3
    
    if sudo systemctl is-active --quiet rtsp-stream.service; then
        echo "✅ systemd转流服务已重启"
    else
        echo "⚠️  systemd服务启动失败，尝试使用脚本启动..."
        if [ -f "./scripts/start_stream.sh" ]; then
            nohup bash ./scripts/start_stream.sh > /tmp/start_stream.log 2>&1 &
            echo "✅ 已使用start_stream.sh重启服务（后台运行）"
        fi
    fi
else
    echo "systemd服务未配置，使用脚本启动..."
    if [ -f "./start_web.sh" ]; then
        nohup bash ./start_web.sh > /tmp/start_web.log 2>&1 &
        echo "✅ 已使用start_web.sh重启服务（后台运行）"
    elif [ -f "./scripts/start_stream.sh" ]; then
        nohup bash ./scripts/start_stream.sh > /tmp/start_stream.log 2>&1 &
        echo "✅ 已使用start_stream.sh重启服务（后台运行）"
    fi
fi

echo ""
echo "等待服务启动..."
sleep 3

# 检查服务状态
if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    PID=$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
    echo "✅ 转流服务运行中 (PID: $PID)"
else
    echo "⚠️  转流服务未运行，请检查日志"
fi

if lsof -Pi :8080 -sTCP:LISTEN > /dev/null 2>&1 || systemctl is-active --quiet nginx 2>/dev/null; then
    echo "✅ Web服务器运行中"
else
    echo "⚠️  Web服务器未运行"
fi

echo ""
ENDSSH
        echo -e "${GREEN}✓ 服务重启完成${NC}"
        ;;
    3)
        echo ""
        echo -e "${YELLOW}跳过服务启动/重启（服务已在步骤6中启动）${NC}"
        ;;
    *)
        echo ""
        echo -e "${YELLOW}无效选择，跳过服务启动/重启${NC}"
        ;;
esac

echo ""

# 步骤9: 显示访问路径并打开网页
echo -e "${BLUE}[9/9] 显示访问信息...${NC}"
echo ""

# 从REMOTE_HOST中提取IP地址
REMOTE_IP=$(echo "$REMOTE_HOST" | sed 's/.*@//' | sed 's/:.*//')

# HLS流路径
HLS_STREAM_URL="http://${REMOTE_IP}:8080/hls/stream.m3u8"
WEB_PLAYER_URL="http://${REMOTE_IP}:8080/index.html"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  访问信息                                                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📺 HLS流地址（直接播放）:${NC}"
echo -e "${YELLOW}   $HLS_STREAM_URL${NC}"
echo ""
echo -e "${CYAN}🌐 Web播放器地址:${NC}"
echo -e "${YELLOW}   $WEB_PLAYER_URL${NC}"
echo ""
echo -e "${CYAN}📋 路径格式说明:${NC}"
echo -e "   ${YELLOW}http://${REMOTE_IP}:8080/hls/stream.m3u8${NC}"
echo -e "   ${YELLOW}格式: http://IP地址:8080/hls/stream.m3u8${NC}"
echo ""

# 创建临时HTML页面，自动填写路径并打开
TEMP_HTML="/tmp/rtsp_stream_info.html"
cat > "$TEMP_HTML" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RTSP转HLS服务 - 访问信息</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Microsoft YaHei', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 800px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .info-section {
            margin-bottom: 30px;
        }
        .info-label {
            color: #667eea;
            font-weight: bold;
            margin-bottom: 8px;
            font-size: 14px;
            display: flex;
            align-items: center;
        }
        .info-label::before {
            content: "📺";
            margin-right: 8px;
        }
        .url-box {
            background: #f5f7fa;
            border: 2px solid #e1e8ed;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 10px;
            word-break: break-all;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            color: #333;
            position: relative;
        }
        .copy-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            margin-top: 8px;
            transition: background 0.3s;
        }
        .copy-btn:hover {
            background: #5568d3;
        }
        .copy-btn:active {
            background: #4457c1;
        }
        .format-info {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            border-radius: 6px;
            margin-top: 20px;
        }
        .format-info strong {
            color: #856404;
        }
        .button-group {
            display: flex;
            gap: 10px;
            margin-top: 20px;
        }
        .btn {
            flex: 1;
            padding: 12px 20px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            transition: all 0.3s;
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-primary:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        .btn-secondary:hover {
            background: #5a6268;
        }
        .success-msg {
            background: #d4edda;
            color: #155724;
            padding: 10px;
            border-radius: 6px;
            margin-top: 10px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 部署成功！</h1>
        <p class="subtitle">RTSP转HLS服务已成功部署到Ubuntu服务器</p>
        
        <div class="info-section">
            <div class="info-label">HLS流地址（直接播放）</div>
            <div class="url-box" id="hlsUrl">$HLS_STREAM_URL</div>
            <button class="copy-btn" onclick="copyToClipboard('hlsUrl')">📋 复制地址</button>
        </div>
        
        <div class="info-section">
            <div class="info-label" style="content: '🌐';">Web播放器地址</div>
            <div class="url-box" id="webUrl">$WEB_PLAYER_URL</div>
            <button class="copy-btn" onclick="copyToClipboard('webUrl')">📋 复制地址</button>
        </div>
        
        <div class="format-info">
            <strong>📋 路径格式说明：</strong><br>
            格式: <code>http://IP地址:8080/hls/stream.m3u8</code><br>
            示例: <code>http://$REMOTE_IP:8080/hls/stream.m3u8</code>
        </div>
        
        <div class="button-group">
            <button class="btn btn-primary" onclick="openPlayer()">🚀 打开播放器</button>
            <button class="btn btn-secondary" onclick="openStream()">📺 打开流地址</button>
        </div>
        
        <div class="success-msg" id="successMsg">✅ 已复制到剪贴板！</div>
    </div>
    
    <script>
        function copyToClipboard(elementId) {
            const element = document.getElementById(elementId);
            const text = element.textContent.trim();
            
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(() => {
                    showSuccess();
                });
            } else {
                // 兼容旧浏览器
                const textarea = document.createElement('textarea');
                textarea.value = text;
                textarea.style.position = 'fixed';
                textarea.style.opacity = '0';
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);
                showSuccess();
            }
        }
        
        function showSuccess() {
            const msg = document.getElementById('successMsg');
            msg.style.display = 'block';
            setTimeout(() => {
                msg.style.display = 'none';
            }, 2000);
        }
        
        function openPlayer() {
            window.open('$WEB_PLAYER_URL', '_blank');
        }
        
        function openStream() {
            window.open('$HLS_STREAM_URL', '_blank');
        }
        
        // 自动聚焦到第一个输入框（如果有）
        window.onload = function() {
            console.log('HLS流地址:', '$HLS_STREAM_URL');
            console.log('Web播放器:', '$WEB_PLAYER_URL');
        };
    </script>
</body>
</html>
EOF

# 尝试在浏览器中打开HTML页面
echo -e "${CYAN}正在打开访问信息页面...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "$TEMP_HTML" 2>/dev/null || echo -e "${YELLOW}⚠️  无法自动打开浏览器，请手动打开: $TEMP_HTML${NC}"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    xdg-open "$TEMP_HTML" 2>/dev/null || echo -e "${YELLOW}⚠️  无法自动打开浏览器，请手动打开: $TEMP_HTML${NC}"
else
    echo -e "${YELLOW}⚠️  无法自动打开浏览器，请手动打开: $TEMP_HTML${NC}"
fi

echo ""
echo -e "${GREEN}✓ 访问信息页面已生成${NC}"
echo -e "${YELLOW}   文件位置: $TEMP_HTML${NC}"
echo ""