# LaoWang Nav 一键安装脚本 (Windows PowerShell)
# 使用方法：irm https://raw.githubusercontent.com/tony-wang1990/laowang-nav/master/scripts/install.ps1 | iex

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  LaoWang Nav 一键安装向导" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 配置变量
$CONTAINER_NAME = "laowang-nav"
$WATCHTOWER_NAME = "watchtower"
$IMAGE_NAME = "ghcr.io/tony-wang1990/laowang-nav:latest"
$DEFAULT_PORT = "8080"
$INSTALL_DIR = "$env:USERPROFILE\laowang-nav"

# 检查 Docker
Write-Host "[1/6] 检查 Docker 环境..." -ForegroundColor Yellow
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "❌ Docker 未安装" -ForegroundColor Red
    Write-Host "请先安装 Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
    exit 1
}
Write-Host "✓ Docker 已安装" -ForegroundColor Green
Write-Host ""

# 询问端口
Write-Host "请输入要使用的端口 (默认 8080):" -ForegroundColor Blue
$PORT = Read-Host ">"
if ([string]::IsNullOrWhiteSpace($PORT)) {
    $PORT = $DEFAULT_PORT
}
Write-Host "使用端口: $PORT" -ForegroundColor Green
Write-Host ""

# 停止旧容器
Write-Host "[2/6] 清理旧容器..." -ForegroundColor Yellow
try { docker stop $CONTAINER_NAME 2>$null | Out-Null; Write-Host "已停止旧容器" } catch {}
try { docker rm $CONTAINER_NAME 2>$null | Out-Null; Write-Host "已删除旧容器" } catch {}
try { docker stop $WATCHTOWER_NAME 2>$null | Out-Null } catch {}
try { docker rm $WATCHTOWER_NAME 2>$null | Out-Null } catch {}
Write-Host "✓ 清理完成" -ForegroundColor Green
Write-Host ""

# 创建目录
Write-Host "[3/6] 创建数据目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$INSTALL_DIR\user-data" | Out-Null
New-Item -ItemType Directory -Force -Path "$INSTALL_DIR\public\item-icons" | Out-Null
Write-Host "✓ 目录已创建: $INSTALL_DIR" -ForegroundColor Green
Write-Host ""

# 拉取镜像
Write-Host "[4/6] 拉取最新镜像..." -ForegroundColor Yellow
docker pull $IMAGE_NAME
Write-Host "✓ 镜像拉取成功" -ForegroundColor Green
Write-Host ""

# 初始化配置
Write-Host "[5/6] 初始化配置文件..." -ForegroundColor Yellow
$confPath = "$INSTALL_DIR\user-data\conf.yml"
if (-not (Test-Path $confPath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tony-wang1990/laowang-nav/master/user-data/conf.yml" `
        -OutFile $confPath
    Write-Host "✓ 配置文件已下载" -ForegroundColor Green
}
else {
    Write-Host "配置文件已存在，保留现有配置"
}
Write-Host ""

# 启动容器
Write-Host "[6/6] 启动服务..." -ForegroundColor Yellow
Set-Location $INSTALL_DIR

$userDataPath = "$INSTALL_DIR\user-data".Replace('\', '/')
$iconsPath = "$INSTALL_DIR\public\item-icons".Replace('\', '/')

docker run -d `
    --name $CONTAINER_NAME `
    -p "${PORT}:8080" `
    -v "${userDataPath}:/app/user-data" `
    -v "${iconsPath}:/app/public/item-icons" `
    -e NODE_ENV=production `
    --restart unless-stopped `
    $IMAGE_NAME | Out-Null

Write-Host "✓ 主容器已启动" -ForegroundColor Green

# 启动 Watchtower
docker run -d `
    --name $WATCHTOWER_NAME `
    --restart unless-stopped `
    -v //var/run/docker.sock:/var/run/docker.sock `
    containrrr/watchtower `
    --interval 300 $CONTAINER_NAME | Out-Null

Write-Host "✓ 自动更新服务已启动" -ForegroundColor Green
Write-Host ""

# 完成信息
Write-Host "================================" -ForegroundColor Green
Write-Host "🎉 安装完成！" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "📂 安装目录: " -NoNewline
Write-Host $INSTALL_DIR -ForegroundColor Blue
Write-Host "🌐 访问地址: " -NoNewline
Write-Host "http://localhost:$PORT" -ForegroundColor Blue

# 获取本机 IP
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "以太网*", "Wi-Fi*" -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
if ($ipAddress) {
    Write-Host "🌐 局域网访问: " -NoNewline
    Write-Host "http://${ipAddress}:${PORT}" -ForegroundColor Blue
}

Write-Host ""
Write-Host "💡 常用命令:"
Write-Host "  查看日志: docker logs -f $CONTAINER_NAME"
Write-Host "  重启服务: docker restart $CONTAINER_NAME"
Write-Host "  停止服务: docker stop $CONTAINER_NAME"
Write-Host "  配置文件: $INSTALL_DIR\user-data\conf.yml"
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
