# Ubuntu安装指南

本项目完全支持Ubuntu系统，可以快速部署RTSP转HLS流媒体服务。

## 系统要求

- Ubuntu 18.04+ 或 Debian 10+
- 服务器需要能访问局域网内的RTSP摄像头
- 服务器需要有公网IP（用于公网访问）

## 快速安装（推荐）

### 方法一：一键安装脚本

```bash
# 1. 上传项目到Ubuntu服务器
# 可以使用git clone或scp上传

# 2. 进入项目目录
cd netbo

# 3. 运行一键安装脚本
./install_ubuntu.sh
```

安装脚本会自动完成：
- ✅ 更新系统并安装FFmpeg和Nginx
- ✅ 配置RTSP源地址（可交互式输入）
- ✅ 创建必要目录（/var/www/hls, /var/www/html）
- ✅ 部署Web播放页面
- ✅ 配置Nginx
- ✅ 启动转流服务

### 方法二：使用通用安装脚本

```bash
./install.sh
```

## 手动安装步骤

如果一键安装遇到问题，可以手动安装：

### 1. 安装依赖

```bash
sudo apt-get update
sudo apt-get install -y ffmpeg nginx
```

### 2. 配置RTSP源

编辑配置文件：
```bash
nano config/stream.conf
```

修改RTSP地址：
```bash
RTSP_URL="rtsp://username:password@摄像头IP:554/stream"
HLS_OUTPUT_DIR="/var/www/hls"  # Ubuntu使用标准路径
```

### 3. 创建目录

```bash
sudo mkdir -p /var/www/hls
sudo mkdir -p /var/www/html
sudo chmod 755 /var/www/hls
```

### 4. 部署Web文件

```bash
sudo cp web/index.html /var/www/html/
```

### 5. 配置Nginx

```bash
sudo cp nginx/nginx.conf /etc/nginx/sites-available/rtsp-stream
sudo ln -s /etc/nginx/sites-available/rtsp-stream /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 6. 启动转流

```bash
./scripts/start_stream.sh
```

## 访问播放页面

安装完成后，在浏览器中访问：

```
http://您的服务器IP/
```

或

```
http://localhost/
```

## 管理服务

### 启动/停止/重启转流

```bash
./scripts/start_stream.sh      # 启动
./scripts/stop_stream.sh       # 停止
./scripts/restart_stream.sh    # 重启
./scripts/check_status.sh     # 查看状态
```

### 查看日志

```bash
tail -f logs/ffmpeg.log
```

### Nginx管理

```bash
sudo systemctl status nginx    # 查看状态
sudo systemctl restart nginx   # 重启
sudo systemctl stop nginx     # 停止
sudo systemctl start nginx    # 启动
```

## 配置为系统服务（可选）

创建systemd服务，实现开机自启和自动重启：

### 1. 创建服务文件

```bash
sudo nano /etc/systemd/system/rtsp-stream.service
```

### 2. 添加以下内容

```ini
[Unit]
Description=RTSP to HLS Stream Service
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/netbo
ExecStart=/path/to/netbo/scripts/start_stream.sh
Restart=always
RestartSec=10
StandardOutput=append:/path/to/netbo/logs/ffmpeg.log
StandardError=append:/path/to/netbo/logs/ffmpeg.log

[Install]
WantedBy=multi-user.target
```

**注意**：将 `your-username` 和 `/path/to/netbo` 替换为实际值。

### 3. 启用并启动服务

```bash
sudo systemctl daemon-reload
sudo systemctl enable rtsp-stream.service
sudo systemctl start rtsp-stream.service
```

### 4. 查看服务状态

```bash
sudo systemctl status rtsp-stream.service
```

## 防火墙配置

如果无法从外部访问，需要开放HTTP端口：

```bash
# Ubuntu UFW防火墙
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # 如果使用HTTPS
sudo ufw status
```

## 故障排查

### 1. FFmpeg无法连接RTSP

```bash
# 测试RTSP连接
ffmpeg -rtsp_transport tcp -i rtsp://摄像头IP:554/stream -t 5 -f null -
```

### 2. Nginx无法访问

```bash
# 检查Nginx状态
sudo systemctl status nginx

# 查看Nginx错误日志
sudo tail -f /var/log/nginx/error.log

# 测试Nginx配置
sudo nginx -t
```

### 3. HLS文件未生成

```bash
# 检查目录权限
ls -la /var/www/hls/

# 检查FFmpeg进程
ps aux | grep ffmpeg

# 查看日志
tail -f logs/ffmpeg.log
```

### 4. 端口被占用

```bash
# 查看80端口占用
sudo lsof -i :80

# 或使用netstat
sudo netstat -tulpn | grep :80
```

## 性能优化

### 1. 调整HLS参数

编辑 `scripts/start_stream.sh`，可以调整：
- `-hls_time 2`：切片时长（秒）
- `-hls_list_size 3`：playlist保留切片数

### 2. 多路流支持

为每个摄像头创建独立的配置和脚本，使用不同的HLS输出目录。

### 3. 使用HTTPS

使用Let's Encrypt免费SSL证书：
```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## 常见问题

**Q: 如何修改RTSP地址？**  
A: 编辑 `config/stream.conf`，修改 `RTSP_URL` 值，然后重启转流服务。

**Q: 如何查看转流是否正常？**  
A: 运行 `./scripts/check_status.sh` 或查看 `logs/ffmpeg.log`。

**Q: 如何支持多个摄像头？**  
A: 为每个摄像头创建独立的配置文件和启动脚本，使用不同的HLS输出目录。

**Q: 如何实现开机自启？**  
A: 参考上面的"配置为系统服务"部分。

---

**祝您使用愉快！** 🎉
