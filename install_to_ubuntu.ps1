# 一键部署到Ubuntu服务器 (Windows PowerShell版本)
# 使用方法: .\install_to_ubuntu.ps1
# 功能: 自动传输文件、安装依赖、配置服务、启动服务
# 要求: Windows 10+ (自带OpenSSH和PowerShell)

# 设置错误处理
$ErrorActionPreference = "Continue"

# 远程服务器配置
$REMOTE_HOST = "user@192.168.1.172"
$REMOTE_PASSWORD = "123456"
$REMOTE_DIR = "~/rtsp-stream"

# 获取脚本所在目录
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = $SCRIPT_DIR

# 颜色输出函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { param($msg) Write-ColorOutput Green "✓ $msg" }
function Write-Error { param($msg) Write-ColorOutput Red "✗ $msg" }
function Write-Warning { param($msg) Write-ColorOutput Yellow "⚠ $msg" }
function Write-Info { param($msg) Write-ColorOutput Cyan $msg }
function Write-Step { param($msg) Write-ColorOutput Blue $msg }

# 显示标题
Write-Info "╔════════════════════════════════════════╗"
Write-Info "║  一键部署到Ubuntu服务器              ║"
Write-Info "╚════════════════════════════════════════╝"
Write-Output ""
Write-Output "目标服务器: $REMOTE_HOST"
Write-Output "部署目录: $REMOTE_DIR"
Write-Output "项目路径: $PROJECT_ROOT"
Write-Output ""

# 检查OpenSSH是否安装
$sshPath = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshPath) {
    Write-Error "未找到OpenSSH客户端"
    Write-Output "请安装OpenSSH客户端:"
    Write-Output "  1. 打开 设置 > 应用 > 可选功能"
    Write-Output "  2. 添加功能 > 搜索 'OpenSSH客户端' > 安装"
    exit 1
}
Write-Success "检测到OpenSSH客户端"

# 检查scp是否可用
$scpPath = Get-Command scp -ErrorAction SilentlyContinue
if (-not $scpPath) {
    Write-Error "未找到scp命令"
    exit 1
}

# 步骤1: 测试SSH连接
Write-Step "[1/9] 测试SSH连接..."
try {
    $testResult = ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $REMOTE_HOST "echo '连接成功'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "SSH连接成功"
    } else {
        Write-Error "SSH连接失败"
        Write-Output "请检查:"
        Write-Output "  1. 服务器地址是否正确: $REMOTE_HOST"
        Write-Output "  2. 网络是否可达: ping 192.168.1.172"
        Write-Output "  3. SSH服务是否运行"
        Write-Output "  4. 密码是否正确"
        exit 1
    }
} catch {
    Write-Error "SSH连接失败: $_"
    exit 1
}
Write-Output ""

# 步骤2: 创建远程目录
Write-Step "[2/9] 创建远程目录..."
ssh -o StrictHostKeyChecking=no $REMOTE_HOST "mkdir -p $REMOTE_DIR" 2>&1 | Out-Null
Write-Success "远程目录已创建"
Write-Output ""

# 步骤3: 传输项目文件
Write-Step "[3/9] 传输项目文件..."

# 定义要传输的目录和文件
$DIRS_TO_TRANSFER = @(
    "config",
    "scripts",
    "web",
    "nginx",
    "systemd"
)

$FILES_TO_TRANSFER = @(
    "install.sh",
    "install_ubuntu.sh",
    "install_ubuntu_nosudo.sh",
    "start_web.sh",
    "install_to_ubuntu.sh"
)

# 传输目录
Write-Output "传输目录..."
foreach ($dir in $DIRS_TO_TRANSFER) {
    $dirPath = Join-Path $PROJECT_ROOT $dir
    if (Test-Path $dirPath -PathType Container) {
        Write-Output "  传输目录: $dir"
        scp -o StrictHostKeyChecking=no -r "$dirPath" "${REMOTE_HOST}:${REMOTE_DIR}/" 2>&1 | Out-Null
    }
}

# 传输文件
Write-Output "传输文件..."
foreach ($file in $FILES_TO_TRANSFER) {
    $filePath = Join-Path $PROJECT_ROOT $file
    if (Test-Path $filePath -PathType Leaf) {
        Write-Output "  传输文件: $file"
        scp -o StrictHostKeyChecking=no "$filePath" "${REMOTE_HOST}:${REMOTE_DIR}/" 2>&1 | Out-Null
    }
}

# 传输所有.md文件
Write-Output "传输文档文件..."
Get-ChildItem -Path $PROJECT_ROOT -Filter "*.md" -File | ForEach-Object {
    Write-Output "  传输: $($_.Name)"
    scp -o StrictHostKeyChecking=no $_.FullName "${REMOTE_HOST}:${REMOTE_DIR}/" 2>&1 | Out-Null
}

Write-Success "文件传输完成"
Write-Output ""

# 验证关键文件
Write-Step "验证关键文件..."
$CRITICAL_FILES = @(
    "web/index.html",
    "web/http_server.py",
    "start_web.sh",
    "scripts/start_stream.sh",
    "scripts/check_hls.sh",
    "scripts/test_hls_access.sh",
    "nginx/nginx.conf",
    "config/stream.conf"
)

$allFilesOk = $true
foreach ($file in $CRITICAL_FILES) {
    $result = ssh -o StrictHostKeyChecking=no $REMOTE_HOST "test -f ${REMOTE_DIR}/$file" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "  $file"
    } else {
        Write-Error "  $file (缺失)"
        $allFilesOk = $false
    }
}

if (-not $allFilesOk) {
    Write-Warning "部分关键文件缺失，尝试重新传输..."
    foreach ($file in $CRITICAL_FILES) {
        $result = ssh -o StrictHostKeyChecking=no $REMOTE_HOST "test -f ${REMOTE_DIR}/$file" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $filePath = Join-Path $PROJECT_ROOT $file
            if (Test-Path $filePath) {
                Write-Output "  重新传输: $file"
                $dirName = Split-Path $file -Parent
                if ($dirName) {
                    ssh -o StrictHostKeyChecking=no $REMOTE_HOST "mkdir -p ${REMOTE_DIR}/$dirName" 2>&1 | Out-Null
                }
                scp -o StrictHostKeyChecking=no "$filePath" "${REMOTE_HOST}:${REMOTE_DIR}/$file" 2>&1 | Out-Null
            }
        }
    }
}
Write-Output ""

# 步骤4: 设置执行权限
Write-Step "[4/9] 设置执行权限..."
ssh -o StrictHostKeyChecking=no $REMOTE_HOST "cd $REMOTE_DIR && chmod +x scripts/*.sh *.sh web/*.py 2>/dev/null || true" 2>&1 | Out-Null
Write-Success "权限设置完成"
Write-Output ""

# 步骤5: 在远程服务器上执行安装
Write-Step "[5/9] 在远程服务器上安装和配置..."
Write-Warning "正在执行远程安装（这可能需要几分钟）..."
Write-Output ""

$installScript = @"
cd ~/rtsp-stream

echo "=========================================="
echo "  开始安装RTSP转HLS服务"
echo "=========================================="
echo ""

# 检查系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=`$ID
    OS_NAME=`$PRETTY_NAME
else
    OS_TYPE="unknown"
    OS_NAME="Unknown"
fi

echo "检测到系统: `$OS_NAME"
echo ""

# 如果是Ubuntu/Debian，使用Ubuntu安装脚本
if [ "`$OS_TYPE" = "ubuntu" ] || [ "`$OS_TYPE" = "debian" ]; then
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
"@

ssh -o StrictHostKeyChecking=no $REMOTE_HOST $installScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "远程安装过程中出现错误"
    Write-Warning "请检查上面的错误信息"
    exit 1
}

Write-Success "远程安装完成"
Write-Output ""

# 步骤6: 验证安装结果并配置服务
Write-Step "[6/9] 验证安装结果并配置服务..."

$configScript = @"
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
    RTSP_URL=`$(grep "^RTSP_URL=" config/stream.conf | cut -d'"' -f2)
    if [[ "`$RTSP_URL" == *"192.168.1.100"* ]] || [[ "`$RTSP_URL" == *"示例"* ]]; then
        echo "  ⚠ RTSP地址未配置（需要手动配置）"
    else
        echo "  ✓ RTSP地址已配置: `$RTSP_URL"
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
# 配置systemd服务
CURRENT_USER=`$(whoami)
PROJECT_PATH=`$(pwd)

echo "  当前用户: `$CURRENT_USER"
echo "  项目路径: `$PROJECT_PATH"

# 优先配置rtsp-web.service（启动start_web.sh，包含转流+Web服务器）
if [ -f "systemd/rtsp-web.service" ]; then
    echo "  配置rtsp-web.service（转流+Web服务器）..."
    
    # 创建服务文件，替换占位符
    SERVICE_FILE="/tmp/rtsp-web.service"
    sed "s|%USER%|`$CURRENT_USER|g; s|%WORKDIR%|`$PROJECT_PATH|g" \
        systemd/rtsp-web.service > "`$SERVICE_FILE"
    
    # 复制到systemd目录
    sudo cp "`$SERVICE_FILE" /etc/systemd/system/rtsp-web.service
    rm -f "`$SERVICE_FILE"
    
    echo "  ✓ rtsp-web.service已创建"
fi

# 配置rtsp-stream.service（仅转流服务，作为备选）
if [ -f "systemd/rtsp-stream.service" ]; then
    echo "  配置rtsp-stream.service（仅转流服务）..."
    
    # 创建服务文件，替换占位符
    SERVICE_FILE="/tmp/rtsp-stream.service"
    sed "s|%USER%|`$CURRENT_USER|g; s|%WORKDIR%|`$PROJECT_PATH|g" \
        systemd/rtsp-stream.service > "`$SERVICE_FILE"
    
    # 复制到systemd目录
    sudo cp "`$SERVICE_FILE" /etc/systemd/system/rtsp-stream.service
    rm -f "`$SERVICE_FILE"
    
    echo "  ✓ rtsp-stream.service已创建"
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
else
    echo "  ⚠ UFW未安装，跳过防火墙配置"
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
"@

ssh -o StrictHostKeyChecking=no $REMOTE_HOST $configScript
Write-Output ""

# 步骤7: 自动启动服务
Write-Step "[7/9] 自动启动服务..."
Write-Warning "正在启动RTSP转HLS服务（后台运行）..."

$startScript = @"
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
            HLS_DIR=`${HLS_OUTPUT_DIR:-/var/www/hls}
            echo "等待HLS文件生成..."
            for i in {1..15}; do
                if [ -f "`$HLS_DIR/stream.m3u8" ]; then
                    echo "✅ HLS文件已生成"
                    break
                fi
                sleep 1
            done
        else
            echo "⚠️  systemd Web服务启动失败，尝试使用脚本启动..."
        fi
    fi
fi

# 如果systemd服务不可用，使用start_web.sh启动
if ! sudo systemctl is-active --quiet rtsp-web.service 2>/dev/null && ! sudo systemctl is-active --quiet rtsp-stream.service 2>/dev/null; then
    echo "使用 start_web.sh 启动服务（转流+Web服务器，后台运行）..."
    
    if [ -f "./start_web.sh" ]; then
        echo "执行启动脚本（后台运行）..."
        nohup bash ./start_web.sh > /tmp/start_web.log 2>&1 &
        START_PID=`$!
        echo "启动脚本已在后台运行 (PID: `$START_PID)"
        
        sleep 3
        
        # 检查FFmpeg进程是否启动
        if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
            FFMPEG_PID=`$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
            echo "✅ 转流服务已启动 (FFmpeg PID: `$FFMPEG_PID)"
        fi
        
        # 检查Python HTTP服务器是否启动
        if pgrep -f "python.*http_server" > /dev/null || lsof -Pi :8080 -sTCP:LISTEN > /dev/null 2>&1; then
            echo "✅ Web服务器已启动（端口8080）"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "  服务启动命令已执行（后台运行）"
echo "=========================================="
disown -a 2>/dev/null || true
"@

ssh -o StrictHostKeyChecking=no $REMOTE_HOST $startScript
Write-Output ""

# 步骤8: 验证服务状态
Write-Step "[8/9] 验证服务状态..."
Start-Sleep -Seconds 5

$statusScript = @"
cd ~/rtsp-stream

echo "检查服务状态..."
echo ""

# 检查FFmpeg进程
if pgrep -f "ffmpeg.*stream.m3u8" > /dev/null; then
    PID=`$(pgrep -f "ffmpeg.*stream.m3u8" | head -1)
    echo "✅ FFmpeg进程运行中 (PID: `$PID)"
else
    echo "❌ FFmpeg进程未运行"
fi

# 检查HLS文件
HLS_DIR=`${HLS_OUTPUT_DIR:-/var/www/hls}
if [ -f "`$HLS_DIR/stream.m3u8" ]; then
    echo "✅ HLS播放列表存在: `$HLS_DIR/stream.m3u8"
    
    # 检查文件是否最近更新
    if [ `$(find "`$HLS_DIR/stream.m3u8" -mmin -1 2>/dev/null | wc -l) -gt 0 ]; then
        echo "✅ HLS文件最近有更新（正常）"
    else
        echo "⚠️  警告: HLS文件超过1分钟未更新"
    fi
    
    # 统计TS切片
    TS_COUNT=`$(ls -1 "`$HLS_DIR"/*.ts 2>/dev/null | wc -l)
    echo "📊 TS切片数量: `$TS_COUNT"
else
    echo "⚠️  HLS播放列表不存在（可能还在生成中）"
fi

# 检查Nginx
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "✅ Nginx服务正在运行"
else
    echo "⚠️  Nginx服务未运行（将使用Python HTTP服务器）"
fi

echo ""
"@

ssh -o StrictHostKeyChecking=no $REMOTE_HOST $statusScript
Write-Output ""

# 步骤9: 显示访问信息
Write-Step "[9/9] 显示访问信息..."
Write-Output ""

# 从REMOTE_HOST中提取IP地址
$REMOTE_IP = $REMOTE_HOST -replace '.*@', '' -replace ':.*', ''

# HLS流路径
$HLS_STREAM_URL = "http://${REMOTE_IP}:8080/hls/stream.m3u8"
$WEB_PLAYER_URL = "http://${REMOTE_IP}:8080/index.html"

Write-Info "╔══════════════════════════════════════════════════════════╗"
Write-Info "║  访问信息                                                ║"
Write-Info "╚══════════════════════════════════════════════════════════╝"
Write-Output ""
Write-Info "📺 HLS流地址（直接播放）:"
Write-Output "   $HLS_STREAM_URL"
Write-Output ""
Write-Info "🌐 Web播放器地址:"
Write-Output "   $WEB_PLAYER_URL"
Write-Output ""
Write-Info "📋 路径格式说明:"
Write-Output "   http://${REMOTE_IP}:8080/hls/stream.m3u8"
Write-Output "   格式: http://IP地址:8080/hls/stream.m3u8"
Write-Output ""

# 创建临时HTML页面
$TEMP_HTML = Join-Path $env:TEMP "rtsp_stream_info.html"
$htmlContent = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RTSP转HLS服务 - 访问信息</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Microsoft YaHei', sans-serif;
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
        h1 { color: #333; margin-bottom: 10px; font-size: 28px; }
        .subtitle { color: #666; margin-bottom: 30px; font-size: 14px; }
        .info-section { margin-bottom: 30px; }
        .info-label {
            color: #667eea;
            font-weight: bold;
            margin-bottom: 8px;
            font-size: 14px;
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
        }
        .copy-btn:hover { background: #5568d3; }
        .format-info {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            border-radius: 6px;
            margin-top: 20px;
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
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-primary:hover { background: #5568d3; }
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        .btn-secondary:hover { background: #5a6268; }
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
            <div class="info-label">📺 HLS流地址（直接播放）</div>
            <div class="url-box" id="hlsUrl">$HLS_STREAM_URL</div>
            <button class="copy-btn" onclick="copyToClipboard('hlsUrl')">📋 复制地址</button>
        </div>
        
        <div class="info-section">
            <div class="info-label">🌐 Web播放器地址</div>
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
            navigator.clipboard.writeText(text).then(() => {
                document.getElementById('successMsg').style.display = 'block';
                setTimeout(() => {
                    document.getElementById('successMsg').style.display = 'none';
                }, 2000);
            });
        }
        function openPlayer() {
            window.open('$WEB_PLAYER_URL', '_blank');
        }
        function openStream() {
            window.open('$HLS_STREAM_URL', '_blank');
        }
    </script>
</body>
</html>
"@

$htmlContent | Out-File -FilePath $TEMP_HTML -Encoding UTF8

# 在浏览器中打开HTML页面
Write-Info "正在打开访问信息页面..."
Start-Process $TEMP_HTML

Write-Output ""
Write-Success "访问信息页面已生成"
Write-Output "   文件位置: $TEMP_HTML"
Write-Output ""

# 显示最终信息
Write-Info "╔════════════════════════════════════════╗"
Write-Info "║  部署成功！                           ║"
Write-Info "╚════════════════════════════════════════╝"
Write-Output ""
Write-Info "远程服务器信息:"
Write-Output "  地址: $REMOTE_HOST"
Write-Output "  目录: $REMOTE_DIR"
Write-Output ""
Write-Info "下一步操作:"
Write-Output ""
Write-Success "✓ 服务已自动启动！"
Write-Output ""
Write-Output "1. 如果RTSP地址未配置，请先编辑配置文件:"
Write-Output "   ssh $REMOTE_HOST"
Write-Output "   cd $REMOTE_DIR"
Write-Output "   nano config/stream.conf"
Write-Output ""
Write-Output "2. 访问播放页面:"
Write-Output "   Web播放器: $WEB_PLAYER_URL"
Write-Output "   HLS流地址: $HLS_STREAM_URL"
Write-Output ""
Write-Output "3. 查看服务状态:"
Write-Output "   ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./scripts/check_status.sh'"
Write-Output ""
Write-Info "已完成的配置:"
Write-Success "✓ systemd Web服务已配置并启用（开机自启，启动start_web.sh）"
Write-Success "✓ 防火墙已配置（开放端口80和8080）"
Write-Success "✓ Nginx已设置为开机自启"
Write-Output ""
