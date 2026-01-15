# 配置免密码sudo（解决部署时密码问题）

## 问题说明

在远程部署时，如果服务器需要sudo密码，部署脚本无法自动输入密码。有两种解决方案：

## 方案一：配置免密码sudo（推荐）

### 1. SSH登录服务器

```bash
ssh user@192.168.1.172
# 密码: 123456
```

### 2. 配置免密码sudo

```bash
# 编辑sudoers文件
sudo visudo

# 在文件末尾添加（将xurongyu替换为您的用户名）
xurongyu ALL=(ALL) NOPASSWD: ALL
```

或者使用以下命令（更安全）：

```bash
echo "xurongyu ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/xurongyu
sudo chmod 0440 /etc/sudoers.d/xurongyu
```

### 3. 验证配置

```bash
sudo -n true && echo "免密码sudo配置成功" || echo "配置失败"
```

## 方案二：手动执行安装

如果不想配置免密码sudo，可以：

### 1. 先传输文件

```bash
./deploy.sh
# 或手动传输
rsync -avz --exclude='.git' --exclude='*.log' --exclude='hls_output' \
  ./ user@192.168.1.172:~/rtsp-stream/
```

### 2. SSH登录手动安装

```bash
ssh user@192.168.1.172
cd ~/rtsp-stream
./install_ubuntu.sh
# 此时可以交互式输入sudo密码
```

## 方案三：使用无sudo模式

如果无法获得sudo权限，可以使用无sudo安装脚本：

```bash
ssh user@192.168.1.172
cd ~/rtsp-stream
./install_ubuntu_nosudo.sh
./start_web.sh
```

此模式：
- 不使用Nginx（使用Python HTTP服务器）
- 不使用systemd（需要手动启动）
- 使用用户目录而不是系统目录

## 推荐方案

**推荐使用方案一（配置免密码sudo）**，因为：
1. 可以完全自动化部署
2. 支持systemd开机自启
3. 可以使用Nginx作为Web服务器

配置完成后，重新运行 `./deploy.sh` 即可自动完成部署。
