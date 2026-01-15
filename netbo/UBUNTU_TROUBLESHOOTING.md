# Ubuntu部署问题排查指南

## 快速诊断

### 方法一：使用诊断脚本（推荐）

在Ubuntu服务器上运行：

```bash
cd ~/rtsp-stream  # 或您的项目目录
chmod +x scripts/diagnose_ubuntu.sh
./scripts/diagnose_ubuntu.sh
```

### 方法二：使用修复脚本

```bash
chmod +x fix_ubuntu_deploy.sh
./fix_ubuntu_deploy.sh
```

## 常见问题及解决方案

### 问题1: HLS输出目录路径错误

**症状**: FFmpeg无法写入HLS文件，日志显示权限错误

**原因**: 配置文件使用相对路径 `./hls_output`，Ubuntu应该使用 `/var/www/hls`

**解决方案**:

```bash
# 编辑配置文件
nano config/stream.conf

# 修改这一行：
# 从: HLS_OUTPUT_DIR="./hls_output"
# 改为: HLS_OUTPUT_DIR="/var/www/hls"

# 然后创建目录并设置权限
sudo mkdir -p /var/www/hls
sudo chmod 755 /var/www/hls
sudo chown -R $USER:$USER /var/www/hls
```

### 问题2: 目录权限不足

**症状**: FFmpeg无法创建HLS文件

**解决方案**:

```bash
# 创建目录
sudo mkdir -p /var/www/hls
sudo mkdir -p /var/www/html

# 设置权限（允许当前用户写入）
sudo chmod 755 /var/www/hls
sudo chown -R $USER:$USER /var/www/hls

# 或者使用www-data用户（如果使用Nginx）
sudo chown -R www-data:www-data /var/www/hls
```

### 问题3: Nginx未配置或未启动

**症状**: 无法访问播放页面，或404错误

**解决方案**:

```bash
# 1. 检查Nginx是否安装
which nginx || sudo apt-get install -y nginx

# 2. 部署Nginx配置
sudo cp nginx/nginx.conf /etc/nginx/sites-available/rtsp-stream
sudo ln -s /etc/nginx/sites-available/rtsp-stream /etc/nginx/sites-enabled/

# 3. 测试配置
sudo nginx -t

# 4. 重启Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

# 5. 检查状态
sudo systemctl status nginx
```

### 问题4: FFmpeg无法连接RTSP源

**症状**: FFmpeg进程启动后立即退出，日志显示连接失败

**解决方案**:

```bash
# 1. 测试RTSP连接
ffmpeg -rtsp_transport tcp -i "rtsp://您的RTSP地址" -t 5 -f null -

# 2. 检查网络连通性
ping 摄像头IP地址

# 3. 检查RTSP地址格式
# 正确格式: rtsp://username:password@IP:port/path
# 例如: rtsp://admin:123456@192.168.1.100:554/stream

# 4. 编辑配置文件
nano config/stream.conf
# 确保RTSP_URL格式正确
```

### 问题5: systemd服务配置错误

**症状**: 服务无法启动，或开机不自启

**解决方案**:

```bash
# 1. 检查服务文件
sudo cat /etc/systemd/system/rtsp-stream.service

# 2. 确保路径正确（%USER%和%WORKDIR%应该被替换）
# 如果还是占位符，需要重新运行安装脚本

# 3. 重新加载systemd
sudo systemctl daemon-reload

# 4. 启动服务
sudo systemctl start rtsp-stream.service
sudo systemctl enable rtsp-stream.service

# 5. 查看服务状态
sudo systemctl status rtsp-stream.service

# 6. 查看服务日志
sudo journalctl -u rtsp-stream.service -f
```

### 问题6: 端口被占用

**症状**: Nginx无法启动，或端口冲突

**解决方案**:

```bash
# 检查80端口占用
sudo lsof -i :80
# 或
sudo netstat -tulpn | grep :80

# 如果被占用，可以：
# 1. 停止占用端口的服务
# 2. 或修改Nginx配置使用其他端口
```

### 问题7: 防火墙阻止访问

**症状**: 本地可以访问，但外部无法访问

**解决方案**:

```bash
# Ubuntu UFW防火墙
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status

# 或iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

## 完整修复流程

如果遇到多个问题，按以下顺序执行：

```bash
# 1. 停止所有相关服务
./scripts/stop_stream.sh
sudo systemctl stop rtsp-stream.service 2>/dev/null || true

# 2. 运行修复脚本
chmod +x fix_ubuntu_deploy.sh
./fix_ubuntu_deploy.sh

# 3. 检查配置
cat config/stream.conf
# 确保 RTSP_URL 和 HLS_OUTPUT_DIR 正确

# 4. 启动服务
./scripts/start_stream.sh

# 5. 检查状态
./scripts/check_status.sh

# 6. 查看日志
tail -f logs/ffmpeg.log
```

## 远程诊断（从本地Mac连接Ubuntu服务器）

### 使用SSH执行诊断

```bash
# 连接到服务器并运行诊断
ssh user@192.168.1.172 'cd ~/rtsp-stream && bash scripts/diagnose_ubuntu.sh'

# 或先传输文件，再执行
scp -r scripts/diagnose_ubuntu.sh user@192.168.1.172:~/rtsp-stream/
ssh user@192.168.1.172 'cd ~/rtsp-stream && chmod +x scripts/diagnose_ubuntu.sh && ./scripts/diagnose_ubuntu.sh'
```

### 查看远程日志

```bash
# 查看FFmpeg日志
ssh user@192.168.1.172 'tail -50 ~/rtsp-stream/logs/ffmpeg.log'

# 查看Nginx日志
ssh user@192.168.1.172 'sudo tail -50 /var/log/nginx/error.log'

# 查看systemd服务日志
ssh user@192.168.1.172 'sudo journalctl -u rtsp-stream.service -n 50'
```

## 检查清单

部署后，按以下清单检查：

- [ ] FFmpeg已安装 (`ffmpeg -version`)
- [ ] Nginx已安装并运行 (`sudo systemctl status nginx`)
- [ ] 配置文件路径正确 (`cat config/stream.conf | grep HLS_OUTPUT_DIR`)
- [ ] HLS目录存在且可写 (`ls -la /var/www/hls`)
- [ ] RTSP地址配置正确 (`cat config/stream.conf | grep RTSP_URL`)
- [ ] FFmpeg进程运行中 (`./scripts/check_status.sh`)
- [ ] HLS文件正在生成 (`ls -la /var/www/hls/*.ts`)
- [ ] Nginx配置正确 (`sudo nginx -t`)
- [ ] 可以访问播放页面 (`curl http://localhost/`)

## 获取帮助

如果以上方法都无法解决问题，请收集以下信息：

```bash
# 1. 系统信息
uname -a
cat /etc/os-release

# 2. 配置文件
cat config/stream.conf

# 3. 日志文件
tail -100 logs/ffmpeg.log

# 4. 服务状态
./scripts/check_status.sh
sudo systemctl status nginx
sudo systemctl status rtsp-stream.service 2>/dev/null || echo "服务未配置"

# 5. 进程信息
ps aux | grep ffmpeg
ps aux | grep nginx
```

将这些信息提供给技术支持。
