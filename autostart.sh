#!/bin/bash
# setup_autostart.sh

# 获取当前目录和用户名
CURRENT_DIR=$(pwd)
CURRENT_USER=$(whoami)

echo "📁 当前目录: $CURRENT_DIR"
echo "👤 当前用户: $CURRENT_USER"

# 1. 创建 systemd 服务文件
echo "📝 创建 systemd 服务文件..."
sudo tee /etc/systemd/system/web.service << EOF
[Unit]
Description=Web Application Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$CURRENT_DIR
ExecStart=$CURRENT_DIR/start_web.sh
Restart=always
RestartSec=10
User=$CURRENT_USER
Group=$CURRENT_USER

# 环境变量
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 日志
StandardOutput=append:/var/log/web.log
StandardError=append:/var/log/web-error.log

# 资源限制（可选）
# LimitNOFILE=65535
# LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created"

# 2. 确保脚本可执行
chmod +x start_web.sh

# 3. 重新加载 systemd
sudo systemctl daemon-reload

# 4. 启用开机自启
sudo systemctl enable web.service

# 5. 启动服务
sudo systemctl start web.service

# 6. 检查状态
echo "📊 服务状态:"
sudo systemctl status web.service --no-pager

# 7. 创建日志文件（如果不存在）
sudo touch /var/log/web.log /var/log/web-error.log
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/web*.log

echo "🎉 设置完成！"
echo "📋 常用命令:"
echo "  sudo systemctl status web.service    # 查看状态"
echo "  sudo journalctl -u web.service -f    # 实时日志"
echo "  sudo systemctl restart web.service   # 重启服务"
echo "  sudo systemctl stop web.service      # 停止服务"