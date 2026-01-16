#!/bin/bash

# 全面修复权限脚本（最高权限）
# 用于解决开机自启动权限问题

echo "=========================================="
echo "  修复所有文件权限（最高权限）"
echo "=========================================="
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "项目目录: $PROJECT_ROOT"
echo ""

# 修复所有脚本的执行权限（最高权限 777）
echo "[1] 修复脚本执行权限（最高权限）..."
chmod 777 *.sh 2>/dev/null || sudo chmod 777 *.sh 2>/dev/null || true
chmod 777 scripts/*.sh 2>/dev/null || sudo chmod 777 scripts/*.sh 2>/dev/null || true
chmod 777 web/*.py 2>/dev/null || sudo chmod 777 web/*.py 2>/dev/null || true

# 特别确保关键文件（最高权限）
echo "[2] 修复关键文件权限（最高权限）..."
chmod 777 start_web.sh 2>/dev/null || sudo chmod 777 start_web.sh 2>/dev/null || true
chmod 777 scripts/start_stream.sh 2>/dev/null || sudo chmod 777 scripts/start_stream.sh 2>/dev/null || true
chmod 777 scripts/stop_stream.sh 2>/dev/null || sudo chmod 777 scripts/stop_stream.sh 2>/dev/null || true
chmod 777 scripts/check_status.sh 2>/dev/null || sudo chmod 777 scripts/check_status.sh 2>/dev/null || true
chmod 777 scripts/check_service.sh 2>/dev/null || sudo chmod 777 scripts/check_service.sh 2>/dev/null || true
chmod 777 scripts/fix_permissions.sh 2>/dev/null || sudo chmod 777 scripts/fix_permissions.sh 2>/dev/null || true

# 确保目录权限（最高权限 777）
echo "[3] 修复目录权限（最高权限）..."
mkdir -p logs 2>/dev/null || sudo mkdir -p logs 2>/dev/null || true
chmod 777 logs 2>/dev/null || sudo chmod 777 logs 2>/dev/null || true
chmod 777 scripts 2>/dev/null || sudo chmod 777 scripts 2>/dev/null || true
chmod 777 web 2>/dev/null || sudo chmod 777 web 2>/dev/null || true
chmod 777 config 2>/dev/null || sudo chmod 777 config 2>/dev/null || true
chmod 777 . 2>/dev/null || sudo chmod 777 . 2>/dev/null || true

# 确保配置文件可读写（最高权限）
echo "[4] 修复配置文件权限（最高权限）..."
chmod 777 config/*.conf 2>/dev/null || sudo chmod 777 config/*.conf 2>/dev/null || true
chmod 777 config 2>/dev/null || sudo chmod 777 config 2>/dev/null || true

# 验证权限
echo ""
echo "[5] 验证关键文件权限:"
echo "  start_web.sh:"
ls -la start_web.sh 2>/dev/null | awk '{print "    "$1" "$9}'
echo "  scripts/start_stream.sh:"
ls -la scripts/start_stream.sh 2>/dev/null | awk '{print "    "$1" "$9}'

# 修复符号链接权限（如果存在）
echo ""
echo "[6] 修复符号链接权限..."
if [ -L "/usr/local/bin/rtsp-start-web" ]; then
    echo "  修复符号链接权限..."
    sudo chmod 777 /usr/local/bin/rtsp-start-web 2>/dev/null || true
    # 确保符号链接指向的文件也有权限
    LINK_TARGET=$(readlink -f /usr/local/bin/rtsp-start-web 2>/dev/null)
    if [ -f "$LINK_TARGET" ]; then
        chmod 777 "$LINK_TARGET" 2>/dev/null || sudo chmod 777 "$LINK_TARGET" 2>/dev/null || true
        echo "  ✓ 符号链接权限已修复: $LINK_TARGET"
    fi
fi

# 检查是否有文件仍然没有执行权限
echo ""
echo "[7] 检查未修复的文件..."
NO_EXEC=0
if [ ! -x start_web.sh ]; then
    echo "  ✗ start_web.sh 仍然没有执行权限，尝试强制修复..."
    sudo chmod 777 start_web.sh 2>/dev/null || true
    NO_EXEC=1
fi
if [ ! -x scripts/start_stream.sh ]; then
    echo "  ✗ scripts/start_stream.sh 仍然没有执行权限，尝试强制修复..."
    sudo chmod 777 scripts/start_stream.sh 2>/dev/null || true
    NO_EXEC=1
fi

# 最终验证
if [ -x start_web.sh ] && [ -x scripts/start_stream.sh ]; then
    echo "  ✓ 所有关键文件都有执行权限（最高权限）"
else
    echo "  ⚠ 部分文件权限修复失败，使用sudo强制修复..."
    sudo chmod -R 777 "$PROJECT_ROOT" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  权限修复完成（最高权限 777）"
echo "=========================================="
echo ""
echo "当前权限状态:"
ls -la start_web.sh 2>/dev/null | awk '{print "  "$1" "$9}'
ls -la scripts/start_stream.sh 2>/dev/null | awk '{print "  "$1" "$9}'
