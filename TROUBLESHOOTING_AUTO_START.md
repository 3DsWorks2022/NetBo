# 开机自启动问题排查指南

如果系统重启后服务没有自动启动，请按照以下步骤排查：

## 快速诊断

在Ubuntu服务器上执行诊断脚本：

```bash
cd ~/rtsp-stream
./scripts/check_service.sh
```

## 常见问题及解决方法

### 1. 服务未启用

**检查：**
```bash
systemctl is-enabled rtsp-web.service
```

**解决：**
```bash
sudo systemctl enable rtsp-web.service
sudo systemctl daemon-reload
```

### 2. 服务启动失败

**检查服务状态：**
```bash
sudo systemctl status rtsp-web.service
```

**查看详细日志：**
```bash
# 查看 systemd 日志
sudo journalctl -u rtsp-web.service -n 50 --no-pager

# 查看服务输出日志
tail -50 ~/rtsp-stream/logs/web_service.log
```

### 3. 路径问题

**检查服务文件中的路径：**
```bash
cat /etc/systemd/system/rtsp-web.service | grep -E "(ExecStart|WorkingDirectory)"
```

确保路径是**绝对路径**，不能包含 `~` 符号。

**如果路径错误，手动修复：**
```bash
# 编辑服务文件
sudo nano /etc/systemd/system/rtsp-web.service

# 确保路径类似：
# ExecStart=/bin/bash /home/user/rtsp-stream/start_web.sh
# WorkingDirectory=/home/user/rtsp-stream

# 重新加载并重启
sudo systemctl daemon-reload
sudo systemctl restart rtsp-web.service
```

### 4. 脚本权限问题

**检查并修复：**
```bash
cd ~/rtsp-stream
ls -la start_web.sh
chmod +x start_web.sh
```

### 5. 配置文件问题

**检查配置文件是否存在：**
```bash
ls -la ~/rtsp-stream/config/stream.conf
cat ~/rtsp-stream/config/stream.conf
```

确保 `RTSP_URL` 已正确配置。

### 6. 依赖问题

**检查依赖是否安装：**
```bash
# 检查 FFmpeg
which ffmpeg
ffmpeg -version

# 检查 Python
which python3
python3 --version
```

### 7. 网络未就绪

systemd 服务配置了 `After=network-online.target`，但如果网络服务启动较慢，可能需要等待。

**检查网络状态：**
```bash
systemctl status NetworkManager
# 或
systemctl status networking
```

### 8. 手动测试启动

**手动执行脚本测试：**
```bash
cd ~/rtsp-stream
bash start_web.sh
```

如果手动执行成功但 systemd 启动失败，检查：
- 环境变量差异
- 用户权限差异
- 工作目录差异

## 完整修复流程

如果服务未自动启动，按以下步骤修复：

```bash
# 1. 检查服务状态
sudo systemctl status rtsp-web.service

# 2. 查看错误日志
sudo journalctl -u rtsp-web.service -n 50

# 3. 检查服务是否启用
systemctl is-enabled rtsp-web.service

# 4. 如果未启用，启用服务
sudo systemctl enable rtsp-web.service

# 5. 确保脚本有执行权限
cd ~/rtsp-stream
chmod +x start_web.sh

# 6. 确保日志目录存在
mkdir -p logs
chmod 755 logs

# 7. 检查服务文件路径
cat /etc/systemd/system/rtsp-web.service | grep ExecStart

# 8. 重新加载 systemd
sudo systemctl daemon-reload

# 9. 手动启动测试
sudo systemctl start rtsp-web.service

# 10. 检查是否启动成功
sudo systemctl status rtsp-web.service

# 11. 如果启动成功，重启系统验证
sudo reboot
```

## 验证开机自启动

重启后，等待1-2分钟，然后检查：

```bash
# SSH 连接到服务器
ssh user@192.168.1.172

# 检查服务状态
sudo systemctl status rtsp-web.service

# 检查进程
ps aux | grep ffmpeg
ps aux | grep python

# 检查端口
netstat -tlnp | grep 8080
# 或
ss -tlnp | grep 8080
```

## 如果仍然无法自动启动

1. **查看完整日志：**
   ```bash
   sudo journalctl -u rtsp-web.service --no-pager
   ```

2. **检查系统启动日志：**
   ```bash
   sudo journalctl -b | grep rtsp-web
   ```

3. **手动创建服务文件：**
   ```bash
   sudo nano /etc/systemd/system/rtsp-web.service
   ```
   
   使用以下内容（替换实际路径）：
   ```ini
   [Unit]
   Description=RTSP to HLS Web Service
   After=network.target network-online.target
   Wants=network-online.target
   
   [Service]
   Type=simple
   User=你的用户名
   Group=你的用户名
   WorkingDirectory=/home/你的用户名/rtsp-stream
   ExecStart=/bin/bash /home/你的用户名/rtsp-stream/start_web.sh
   Restart=always
   RestartSec=10
   StandardOutput=append:/home/你的用户名/rtsp-stream/logs/web_service.log
   StandardError=append:/home/你的用户名/rtsp-stream/logs/web_service.log
   
   [Install]
   WantedBy=multi-user.target
   ```

4. **重新加载并启用：**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable rtsp-web.service
   sudo systemctl start rtsp-web.service
   ```

## 联系支持

如果以上方法都无法解决问题，请提供以下信息：

1. 服务状态：`sudo systemctl status rtsp-web.service`
2. 服务日志：`sudo journalctl -u rtsp-web.service -n 100`
3. 服务文件内容：`cat /etc/systemd/system/rtsp-web.service`
4. 脚本执行测试：`bash ~/rtsp-stream/start_web.sh`
