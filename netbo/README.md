# RTSP公网直播低延迟解决方案

基于FFmpeg命令行和Nginx实现的RTSP转HLS流媒体服务，无需编写代码，支持Web浏览器播放，延迟控制在3-10秒。

## 架构说明

```
局域网环境：
  RTSP摄像头 (内网，不可上公网)
       ↓ RTSP协议
  服务器 (内网，可访问摄像头，同时有公网IP)
       ↓ FFmpeg命令行转码为HLS
  HLS切片存储 (/var/www/hls/)

公网访问：
  公网用户 → HTTP请求 → Nginx(公网IP) → 返回HLS流 → Web前端(hls.js播放)
```

## 功能特点

- ✅ **无需编程**: 纯命令行和配置文件
- ✅ **简单高效**: FFmpeg直接转码，性能好
- ✅ **易于维护**: 脚本化管理，方便操作
- ✅ **低延迟**: 2秒切片，适合实时监控
- ✅ **资源占用低**: 视频流直接复制，不重新编码
- ✅ **Web播放**: 支持浏览器直接播放，无需插件

## 系统要求

- Linux服务器（Ubuntu/Debian推荐）
- FFmpeg 4.0+
- Nginx 1.18+
- 服务器需要能访问局域网内的RTSP摄像头
- 服务器需要有公网IP或域名

## 快速开始

### Ubuntu/Debian系统（推荐）

**一键安装：**

```bash
# Ubuntu专用安装脚本（推荐）
./install_ubuntu.sh
```

**或使用通用安装脚本：**

```bash
./install.sh
```

安装脚本会自动完成：
- ✅ 检查并安装FFmpeg和Nginx
- ✅ 配置RTSP源地址（可交互式输入）
- ✅ 创建必要目录（/var/www/hls）
- ✅ 部署Web播放页面
- ✅ 配置Nginx
- ✅ 启动转流服务

**详细Ubuntu安装说明请参考：** [README_UBUNTU.md](README_UBUNTU.md)

### macOS/其他系统

**快速启动：**

```bash
# 启动转流服务
./scripts/start_stream.sh

# 启动Web服务器（新终端）
./start_web.sh
```

**详细macOS说明请参考：** [README_MACOS.md](README_MACOS.md)

### 方式二：手动部署

#### 1. 安装依赖

```bash
# 更新系统
sudo apt-get update

# 安装FFmpeg
sudo apt-get install -y ffmpeg

# 安装Nginx
sudo apt-get install -y nginx
```

#### 2. 配置项目

#### 2.1 配置RTSP源地址

编辑 `config/stream.conf` 文件，设置您的摄像头RTSP地址：

```bash
# 编辑配置文件
nano config/stream.conf
```

修改 `RTSP_URL` 为您的摄像头地址，例如：
```bash
RTSP_URL="rtsp://192.168.1.100:554/stream"
```

如果摄像头需要用户名密码：
```bash
RTSP_URL="rtsp://username:password@192.168.1.100:554/stream"
```

#### 2.2 创建HLS输出目录

```bash
# 创建HLS输出目录
sudo mkdir -p /var/www/hls
sudo chmod 755 /var/www/hls

# 创建Web静态文件目录
sudo mkdir -p /var/www/html
```

#### 2.3 部署Web播放页面

```bash
# 复制播放页面到Nginx目录
sudo cp web/index.html /var/www/html/
```

### 3. 配置Nginx

```bash
# 复制Nginx配置文件
sudo cp nginx/nginx.conf /etc/nginx/sites-available/rtsp-stream

# 创建软链接启用配置
sudo ln -s /etc/nginx/sites-available/rtsp-stream /etc/nginx/sites-enabled/

# 测试Nginx配置
sudo nginx -t

# 如果测试通过，重启Nginx
sudo systemctl restart nginx
```

**注意**: 如果有域名，编辑 `/etc/nginx/sites-available/rtsp-stream`，取消 `server_name` 注释并设置您的域名。

### 4. 启动转流服务

**快速启动（已部署环境）：**
```bash
./start.sh
```

**或手动启动：**
```bash
# 进入项目目录
cd /path/to/netbo

# 启动转流
./scripts/start_stream.sh
```

### 5. 访问播放页面

在浏览器中访问：
```
http://您的服务器公网IP/
```

或如果有域名：
```
http://您的域名/
```

## 管理脚本

### 一键命令

**首次部署：**
```bash
./install.sh    # 一键部署和启动
```

**快速启动（已部署环境）：**
```bash
./start.sh      # 快速启动服务
```

### 详细管理脚本

项目提供了多个管理脚本，位于 `scripts/` 目录：

**启动转流**
```bash
./scripts/start_stream.sh
```

**停止转流**
```bash
./scripts/stop_stream.sh
```

**重启转流**
```bash
./scripts/restart_stream.sh
```

**检查状态**
```bash
./scripts/check_status.sh
```

## 配置说明

### stream.conf 配置项

- `RTSP_URL`: RTSP摄像头地址
- `HLS_OUTPUT_DIR`: HLS文件输出目录（默认: `/var/www/hls`）
- `HLS_PLAYLIST`: HLS播放列表文件名（默认: `stream.m3u8`）
- `FFMPEG_LOG`: FFmpeg日志文件路径

### FFmpeg参数说明

转流脚本使用以下FFmpeg参数实现低延迟：

- `-rtsp_transport tcp`: 使用TCP传输（更稳定）
- `-c:v copy`: 视频流直接复制（不重新编码，降低延迟和CPU占用）
- `-c:a aac`: 音频转码为AAC格式
- `-hls_time 2`: 每个切片2秒（低延迟）
- `-hls_list_size 3`: playlist只保留3个切片
- `-hls_flags delete_segments+independent_segments`: 删除旧切片，独立切片

## 故障排查

### 1. FFmpeg无法连接RTSP源

**检查项**:
- RTSP地址是否正确
- 摄像头是否在线
- 服务器是否能访问摄像头IP
- RTSP端口是否开放（默认554）

**测试命令**:
```bash
# 测试RTSP连接
ffmpeg -rtsp_transport tcp -i rtsp://摄像头IP:554/stream -t 5 -f null -
```

### 2. HLS文件未生成

**检查项**:
- HLS输出目录是否有写权限
- FFmpeg进程是否在运行: `./scripts/check_status.sh`
- 查看FFmpeg日志: `tail -f logs/ffmpeg.log`

### 3. 浏览器无法播放

**检查项**:
- Nginx是否正常运行: `sudo systemctl status nginx`
- HLS文件是否存在: `ls -lh /var/www/hls/`
- 浏览器控制台是否有错误
- CORS配置是否正确

### 4. 延迟过高

**优化建议**:
- 确保使用 `-c:v copy`（不重新编码视频）
- 检查网络带宽是否足够
- 考虑使用更低的 `hls_time`（如1秒，但会增加服务器负载）

## 多路流支持

如果需要支持多个摄像头，可以：

1. 为每个摄像头创建独立的配置文件和脚本
2. 使用不同的HLS输出目录
3. 在Web页面中添加多个播放器

示例：
```bash
# 摄像头1
RTSP_URL="rtsp://192.168.1.100:554/stream"
HLS_OUTPUT_DIR="/var/www/hls/camera1"
HLS_PLAYLIST="camera1.m3u8"

# 摄像头2
RTSP_URL="rtsp://192.168.1.101:554/stream"
HLS_OUTPUT_DIR="/var/www/hls/camera2"
HLS_PLAYLIST="camera2.m3u8"
```

## 生产环境建议

### 1. 使用systemd服务管理

创建systemd服务文件 `/etc/systemd/system/rtsp-stream.service`:

```ini
[Unit]
Description=RTSP to HLS Stream Service
After=network.target

[Service]
Type=simple
User=your-user
WorkingDirectory=/path/to/netbo
ExecStart=/path/to/netbo/scripts/start_stream.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
sudo systemctl enable rtsp-stream.service
sudo systemctl start rtsp-stream.service
```

### 2. 配置HTTPS

使用Let's Encrypt免费SSL证书：
```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 3. 防火墙配置

```bash
# 开放HTTP端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 4. 日志轮转

配置logrotate管理日志文件，避免日志文件过大。

## 性能优化

- **视频编码**: 如果摄像头输出格式浏览器不支持，可能需要转码，但会增加CPU占用和延迟
- **网络带宽**: 确保服务器带宽足够支持并发用户
- **存储空间**: HLS切片会占用磁盘空间，定期清理旧切片

## 许可证

本项目为开源项目，可自由使用和修改。

## 技术支持

如遇问题，请检查：
1. FFmpeg日志: `logs/ffmpeg.log`
2. Nginx日志: `/var/log/nginx/error.log`
3. 系统日志: `journalctl -u nginx`

---

**祝您使用愉快！** 🎉
