#!/usr/bin/env bash
set -euo pipefail

APP_NAME="autoscrape-free-nodes"
APP_DIR="/opt/${APP_NAME}"
REPO_URL="https://github.com/Re0XIAOPA/AutoScrapeFreeNodes.git"
PORT="${PORT:-3000}"

echo "======================================"
echo " AutoScrapeFreeNodes 一键安装程序"
echo "======================================"

if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 用户运行"
    exit 1
fi

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    echo "[1/6] 检测基础依赖..."

    if has_cmd apt; then
        apt update -y
        apt install -y curl git ca-certificates
    elif has_cmd dnf; then
        dnf install -y curl git ca-certificates
    elif has_cmd yum; then
        yum install -y curl git ca-certificates
    elif has_cmd pacman; then
        pacman -Sy --noconfirm curl git ca-certificates
    elif has_cmd apk; then
        apk add --no-cache curl git ca-certificates
    else
        echo "无法识别系统，请手动安装 curl git"
        exit 1
    fi
}

install_docker() {
    echo "[2/6] 检测 Docker..."

    if ! has_cmd docker; then
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com | sh
    fi

    systemctl enable docker >/dev/null 2>&1 || true
    systemctl start docker >/dev/null 2>&1 || true

    if ! docker compose version >/dev/null 2>&1; then
        echo "Docker Compose 不可用，请检查 Docker 安装"
        exit 1
    fi
}

download_project() {
    echo "[3/6] 获取项目..."

    mkdir -p /opt

    if [ -d "${APP_DIR}/.git" ]; then
        cd "${APP_DIR}"
        git pull
    else
        rm -rf "${APP_DIR}"
        git clone "${REPO_URL}" "${APP_DIR}"
        cd "${APP_DIR}"
    fi
}

create_compose() {
    echo "[4/6] 创建 Docker 配置..."

    cat > docker-compose.yml <<EOF
services:
  autoscrape:
    build: .
    container_name: ${APP_NAME}
    restart: always
    ports:
      - "${PORT}:3000"
    environment:
      PORT: 3000
      NODE_ENV: production
      TZ: Asia/Shanghai
EOF
}

start_service() {
    echo "[5/6] 启动服务..."

    cd "${APP_DIR}"
    docker compose down >/dev/null 2>&1 || true
    docker compose up -d --build
}

get_ip() {
    curl -4 -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

create_command() {
    cat >/usr/local/bin/autoscrape <<'EOF'
#!/bin/bash
cd /opt/autoscrape-free-nodes

case "$1" in
start)
docker compose up -d
;;
stop)
docker compose down
;;
restart)
docker compose restart
;;
logs)
docker logs -f autoscrape-free-nodes
;;
update)
git pull
docker compose up -d --build
;;
uninstall)
docker rm -f autoscrape-free-nodes
rm -rf /opt/autoscrape-free-nodes
rm -f /usr/local/bin/autoscrape
;;
*)
echo "autoscrape {start|stop|restart|logs|update|uninstall}"
;;
esac
EOF

chmod +x /usr/local/bin/autoscrape
}

finish() {
    IP=$(get_ip)

    echo
    echo "======================================"
    echo " 安装完成"
    echo "======================================"
    echo
    echo "访问地址:"
    echo
    echo " http://${IP}:${PORT}"
    echo
    echo "管理命令:"
    echo
    echo " autoscrape start"
    echo " autoscrape stop"
    echo " autoscrape restart"
    echo " autoscrape logs"
    echo " autoscrape update"
    echo " autoscrape uninstall"
    echo
}

install_packages
install_docker
download_project
create_compose
start_service
create_command
finish
