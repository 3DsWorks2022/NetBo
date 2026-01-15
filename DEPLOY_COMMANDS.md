# 部署命令（手动执行）

## 方法一：使用rsync传输（推荐）

```bash
# 在本地项目目录执行
rsync -avz \
  --exclude='.git' \
  --exclude='*.log' \
  --exclude='*.pid' \
  --exclude='hls_output' \
  --exclude='logs' \
  --exclude='.DS_Store' \
  ./ user@192.168.1.172:~/rtsp-stream/
```

## 方法二：使用scp传输

```bash
# 传输所有必要文件
scp -r config scripts web nginx *.sh *.md \
  user@192.168.1.172:~/rtsp-stream/
```

## 方法三：使用部署脚本（需要手动输入密码）

```bash
./deploy_manual.sh
```

## 部署后操作

### 1. SSH登录服务器

```bash
ssh user@192.168.1.172
# 密码: 123456
```

### 2. 进入项目目录

```bash
cd ~/rtsp-stream
```

### 3. 设置执行权限

```bash
chmod +x scripts/*.sh *.sh
```

### 4. 编辑配置文件

```bash
nano config/stream.conf
```

修改RTSP_URL为您的摄像头地址。

### 5. 安装和启动

```bash
# Ubuntu系统
./install_ubuntu.sh

# 或直接启动
./start_web.sh
```

### 6. 访问播放页面

```
http://192.168.1.72:8080/index.html
```
