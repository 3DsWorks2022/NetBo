# 远程部署指南

## 快速部署

### 方法一：使用部署脚本（推荐）

```bash
./deploy.sh
```

这个脚本会自动：
1. 测试SSH连接
2. 创建远程目录
3. 传输所有项目文件
4. 设置执行权限
5. 在远程服务器上执行安装

### 方法二：手动部署

#### 1. 传输文件到服务器

```bash
# 使用rsync（推荐）
rsync -avz --exclude='.git' --exclude='*.log' --exclude='hls_output' \
  ./ user@192.168.1.172:~/rtsp-stream/

# 或使用scp
scp -r config scripts web nginx *.sh *.md \
  user@192.168.1.172:~/rtsp-stream/
```

#### 2. SSH登录服务器

```bash
ssh user@192.168.1.172
# 密码: 123456
```

#### 3. 进入项目目录

```bash
cd ~/rtsp-stream
```

#### 4. 设置执行权限

```bash
chmod +x scripts/*.sh *.sh
```

#### 5. 编辑配置

```bash
nano config/stream.conf
# 修改RTSP_URL为您的摄像头地址
```

#### 6. 安装和启动

```bash
# Ubuntu/Debian系统
./install_ubuntu.sh

# 或其他系统
./install.sh

# 或直接启动
./start_web.sh
```

## 部署后配置

### 1. 修改RTSP地址

```bash
ssh user@192.168.1.172
cd ~/rtsp-stream
nano config/stream.conf
```

修改 `RTSP_URL` 为您的摄像头地址。

### 2. 启动服务

```bash
./start_web.sh
```

### 3. 访问播放页面

在浏览器中访问：
```
http://192.168.1.72:8080/index.html
```

或如果配置了Nginx：
```
http://192.168.1.72/
```

## 管理服务

### 查看状态

```bash
ssh user@192.168.1.172 'cd ~/rtsp-stream && ./scripts/check_status.sh'
```

### 重启服务

```bash
ssh user@192.168.1.172 'cd ~/rtsp-stream && ./scripts/restart_stream.sh'
```

### 查看日志

```bash
ssh user@192.168.1.172 'cd ~/rtsp-stream && tail -f logs/ffmpeg.log'
```

## 故障排查

### 1. SSH连接失败

- 检查网络连接
- 确认服务器IP地址
- 检查SSH服务是否运行

### 2. 文件传输失败

- 检查磁盘空间
- 确认目录权限
- 尝试手动scp传输

### 3. 服务无法启动

- 检查FFmpeg是否安装
- 检查RTSP地址是否正确
- 查看日志文件

## 注意事项

1. **首次部署**：建议先手动SSH登录，确认服务器环境
2. **配置文件**：部署后需要修改 `config/stream.conf` 中的RTSP地址
3. **防火墙**：确保服务器防火墙开放8080端口（或Nginx端口）
4. **权限问题**：如果遇到权限问题，可能需要使用sudo
