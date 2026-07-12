#!/usr/bin/env bash
set -e

APP_NAME="autoscrape-free-nodes"
REPO_URL="https://github.com/Re0XIAOPA/AutoScrapeFreeNodes.git"
INSTALL_DIR="/opt/${APP_NAME}"
PORT="${PORT:-3000}"

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 运行：sudo -i"
  exit 1
fi

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_base_tools() {
  if command_exists apt-get; then
    apt-get update -y
    apt-get install -y curl git ca-certificates
  elif command_exists dnf; then
    dnf install -y curl git ca-certificates
  elif command_exists yum; then
    yum install -y curl git ca-certificates
  elif command_exists pacman; then
    pacman -Sy --noconfirm curl git ca-certificates
  elif command_exists zypper; then
    zypper install -y curl git ca-certificates
  elif command_exists apk; then
    apk add --no-cache curl git ca-certificates
  else
    echo "不支持的 Linux 包管理器，请手动安装 curl/git/docker"
    exit 1
  fi
}

install_docker() {
  if command_exists docker; then
    return
  fi

  echo "正在安装 Docker..."
  curl -fsSL https://get.docker.com | sh

  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker >/dev/null 2>&1 || service docker start >/dev/null 2>&1 || true
}

get_public_ip() {
  IP="$(curl -4 -fsSL --max-time 5 https://api.ipify.org || true)"
  if [ -z "$IP" ]; then
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  echo "$IP"
}

install_base_tools
install_docker

mkdir -p "$INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
  cd "$INSTALL_DIR"
  git pull
else
  rm -rf "$INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

cat > docker-compose.yml <<EOF
services:
  autoscrape:
    build: .
    container_name: ${APP_NAME}
    restart: unless-stopped
    ports:
      - "${PORT}:3000"
    environment:
      - PORT=3000
      - TZ=Asia/Shanghai
      - NODE_ENV=production
    volumes:
      - ./data:/app/data
    logging:
      driver: json-file
      options:
        max-size: 10m
        max-file: "3"
EOF

docker compose up -d --build || docker-compose up -d --build

PUBLIC_IP="$(get_public_ip)"

echo
echo "安装完成！"
echo "访问地址："
echo "http://${PUBLIC_IP}:${PORT}"
echo
echo "管理命令："
echo "查看日志：docker logs -f ${APP_NAME}"
echo "重启服务：docker restart ${APP_NAME}"
echo "卸载服务：docker rm -f ${APP_NAME} && rm -rf ${INSTALL_DIR}"