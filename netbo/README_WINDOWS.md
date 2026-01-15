# Windows部署指南

## 方法一：使用PowerShell脚本（推荐）

### 前置要求

1. **安装OpenSSH客户端**
   - 打开 `设置` > `应用` > `可选功能`
   - 点击 `添加功能`
   - 搜索 `OpenSSH客户端` 并安装

2. **安装WSL（可选，推荐）**
   - 打开PowerShell（管理员）
   - 运行: `wsl --install`
   - 重启电脑

### 部署步骤

```powershell
# 在PowerShell中执行
.\deploy_windows.ps1
```

如果遇到执行策略限制，运行：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy_windows.ps1
```

## 方法二：使用批处理脚本

```cmd
deploy_windows.bat
```

## 方法三：使用WSL（最推荐）

如果安装了WSL，可以直接使用Linux部署脚本：

```powershell
wsl ./deploy.sh
```

## 方法四：使用WinSCP（图形界面）

### 1. 下载并安装WinSCP
- 访问: https://winscp.net/
- 下载并安装

### 2. 连接服务器
- 主机名: `192.168.1.72`
- 用户名: `xurongyu`
- 密码: `123456`
- 协议: SFTP

### 3. 传输文件
- 左侧：本地项目目录
- 右侧：远程目录 `~/rtsp-stream`
- 拖拽以下目录和文件到右侧：
  - `config`
  - `scripts`
  - `web`
  - `nginx`
  - `systemd`
  - `*.sh` 文件
  - `*.md` 文件

### 4. SSH登录执行安装

在WinSCP中点击"终端"按钮，或使用PuTTY/Windows Terminal：

```bash
cd ~/rtsp-stream
chmod +x scripts/*.sh *.sh
./install_ubuntu.sh
```

## 方法五：使用Git Bash

如果安装了Git for Windows，可以使用Git Bash：

```bash
# 在Git Bash中执行
./deploy.sh
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

### 3. 编辑配置

```bash
nano config/stream.conf
# 修改RTSP_URL为您的摄像头地址
```

### 4. 安装和启动

```bash
# Ubuntu系统
./install_ubuntu.sh

# 或直接启动
./start_web.sh
```

### 5. 访问播放页面

```
http://192.168.1.72:8080/index.html
```

## 推荐方案

**最推荐使用WSL**，因为：
1. 可以直接使用Linux部署脚本
2. 支持所有Linux命令
3. 兼容性最好

安装WSL后：
```powershell
wsl --install
# 重启后
wsl ./deploy.sh
```

## 故障排查

### SSH连接失败
- 检查Windows防火墙
- 确认服务器SSH服务运行
- 测试网络连通性: `ping 192.168.1.72`

### 文件传输失败
- 使用WinSCP图形界面工具
- 或安装WSL使用rsync

### 权限问题
- 确保以管理员身份运行PowerShell（如需要）
- 或使用WSL避免权限问题
