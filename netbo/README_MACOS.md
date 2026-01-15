# macOS使用说明

## 快速开始（macOS）

### 1. 启动转流服务

```bash
./start.sh
```

这会启动FFmpeg转流，将RTSP流转为HLS格式。

### 2. 启动Web服务器

**打开新的终端窗口**，运行：

```bash
./start_web.sh
```

这会启动一个Python HTTP服务器（端口8080），用于提供HLS文件和播放页面。

### 3. 访问播放页面

在浏览器中打开：

```
http://localhost:8080/index.html
```

或者：

```
http://localhost:8080/player.html
```

### 4. 局域网访问

如果其他设备需要访问，使用您的Mac的局域网IP：

```
http://您的Mac局域网IP:8080/index.html
```

查看Mac的IP地址：
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

## 完整流程

```bash
# 终端1: 启动转流
./start.sh

# 终端2: 启动Web服务器
./start_web.sh

# 浏览器: 访问
# http://localhost:8080/index.html
```

## 停止服务

**停止转流：**
```bash
./scripts/stop_stream.sh
```

**停止Web服务器：**
在运行 `start_web.sh` 的终端按 `Ctrl+C`

## 查看状态

```bash
./scripts/check_status.sh
```

## 查看日志

```bash
tail -f logs/ffmpeg.log
```

## 注意事项

1. **HLS输出目录**: 已配置为 `./hls_output`（项目目录下），无需sudo权限
2. **端口**: Web服务器使用8080端口，确保没有被占用
3. **防火墙**: 如果需要局域网访问，确保Mac防火墙允许8080端口

## 故障排查

### 端口被占用
```bash
# 查看8080端口占用
lsof -i :8080

# 杀死占用进程
kill -9 <PID>
```

### FFmpeg未安装
```bash
# 使用Homebrew安装
brew install ffmpeg
```

### 无法访问
- 检查转流是否启动：`./scripts/check_status.sh`
- 检查HLS文件是否生成：`ls -lh hls_output/`
- 检查Web服务器是否运行：浏览器访问 `http://localhost:8080/`
