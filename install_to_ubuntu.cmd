@echo off
REM 一键部署到Ubuntu服务器 (Windows批处理入口)
REM 使用方法: 双击此文件或运行 install_to_ubuntu.cmd
REM 此脚本会调用PowerShell脚本执行实际部署

chcp 65001 >nul
echo.
echo ========================================
echo   一键部署到Ubuntu服务器
echo ========================================
echo.

REM 检查PowerShell是否可用
powershell -Command "exit 0" >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到PowerShell，请安装PowerShell 5.0或更高版本
    echo.
    pause
    exit /b 1
)

REM 获取脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install_to_ubuntu.ps1"

REM 检查PowerShell脚本是否存在
if not exist "%PS_SCRIPT%" (
    echo [错误] 未找到PowerShell脚本: %PS_SCRIPT%
    echo.
    pause
    exit /b 1
)

echo 正在启动PowerShell脚本...
echo.

REM 执行PowerShell脚本
REM 使用 -ExecutionPolicy Bypass 绕过执行策略限制
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

REM 检查执行结果
if errorlevel 1 (
    echo.
    echo [错误] 部署过程中出现错误
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo [完成] 部署脚本执行完成
    echo.
)

pause
