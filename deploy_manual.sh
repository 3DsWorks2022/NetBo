#!/bin/bash

# 手动部署脚本（需要手动输入SSH密码）
# 使用方法: ./deploy_manual.sh

# 远程服务器配置
REMOTE_HOST="user@192.168.1.172"
REMOTE_DIR="~/rtsp-stream"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo "=========================================="
echo "  RTSP转HLS服务远程部署（手动模式）"
echo "=========================================="
echo ""
echo "目标服务器: $REMOTE_HOST"
echo "部署目录: $REMOTE_DIR"
echo ""
echo "提示: 您需要多次输入SSH密码"
echo ""

# 步骤1: 创建远程目录
echo "[1/4] 创建远程目录..."
ssh $REMOTE_HOST "mkdir -p $REMOTE_DIR"
echo "✅ 远程目录已创建"
echo ""

# 步骤2: 传输文件
echo "[2/4] 传输项目文件..."
echo "正在使用rsync传输文件（需要输入密码）..."

# 使用rsync传输（如果可用）
if command -v rsync &> /dev/null; then
    rsync -avz \
        --exclude='.git' \
        --exclude='*.log' \
        --exclude='*.pid' \
        --exclude='hls_output' \
        --exclude='logs' \
        --exclude='.DS_Store' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        "$PROJECT_ROOT/" "$REMOTE_HOST:$REMOTE_DIR/"
else
    echo "使用scp传输文件..."
    scp -r config scripts web nginx *.sh *.md "$REMOTE_HOST:$REMOTE_DIR/" 2>/dev/null || {
        echo "❌ 文件传输失败"
        exit 1
    }
fi

echo "✅ 文件传输完成"
echo ""

# 步骤3: 设置执行权限
echo "[3/4] 设置执行权限..."
ssh $REMOTE_HOST "cd $REMOTE_DIR && chmod +x scripts/*.sh *.sh 2>/dev/null || true"
echo "✅ 权限设置完成"
echo ""

# 步骤4: 显示后续操作说明
echo "[4/4] 部署完成！"
echo ""
echo "=========================================="
echo "  下一步操作"
echo "=========================================="
echo ""
echo "1. SSH登录服务器:"
echo "   ssh $REMOTE_HOST"
echo ""
echo "2. 进入项目目录:"
echo "   cd $REMOTE_DIR"
echo ""
echo "3. 编辑配置文件:"
echo "   nano config/stream.conf"
echo "   （修改RTSP_URL为您的摄像头地址）"
echo ""
echo "4. 安装和启动服务:"
echo "   ./install_ubuntu.sh  # Ubuntu系统"
echo "   或"
echo "   ./start_web.sh      # 直接启动"
echo ""
echo "5. 访问播放页面:"
echo "   http://192.168.1.72:8080/index.html"
echo ""
