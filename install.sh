#!/usr/bin/env bash
set -euo pipefail

APP_NAME="autoscrape-free-nodes"
APP_DIR="/opt/${APP_NAME}"
REPO_URL="https://github.com/你的用户名/AutoScrapeFreeNodes.git"

if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 用户运行"
  exit 1
fi

echo "========================================"
echo " AutoScrapeFreeNodes 安装程序"
echo "========================================"

read -rp "请输入访问域名或IP: " HOST
read -rp "是否使用HTTPS? (y/N): " SSL
read -rp "请输入外部访问端口(例如8080，默认3000): " PORT
PORT=${PORT:-3000}

if [[ "$SSL" =~ ^[Yy]$ ]]; then
  BASE_URL="https://${HOST}"
else
  BASE_URL="http://${HOST}:${PORT}"
fi

if command -v ss >/dev/null && ss -lnt | grep -q ":${PORT} "; then
  echo "端口 ${PORT} 已被占用"
  ss -lntp | grep ":${PORT}" || true
  exit 1
fi

if command -v apt >/dev/null; then
  apt update -y
  apt install -y curl git python3 ca-certificates
elif command -v yum >/dev/null; then
  yum install -y curl git python3 ca-certificates
elif command -v dnf >/dev/null; then
  dnf install -y curl git python3 ca-certificates
fi

if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker >/dev/null 2>&1 || true
systemctl start docker >/dev/null 2>&1 || true

docker rm -f ${APP_NAME} >/dev/null 2>&1 || true

rm -rf "${APP_DIR}"
git clone --depth=1 "${REPO_URL}" "${APP_DIR}"

cd "${APP_DIR}"

if [ -f config.json ]; then
python3 - "$BASE_URL" <<'PY'
import json,sys
p="config.json"
base=sys.argv[1]
with open(p,encoding="utf-8") as f:
    data=json.load(f)

paths=["/clash/sub","/vmess/sub","/sing-box/sub","/ss/sub","/ssr/sub","/trojan/sub"]

def f(x):
    if isinstance(x,dict):
        for k,v in x.items():
            if k=="url" and isinstance(v,str):
                for p in paths:
                    if p in v:
                        x[k]=base.rstrip("/") + p
            else:
                f(v)
    elif isinstance(x,list):
        for i in x:
            f(i)

f(data)

with open(p,"w",encoding="utf-8") as o:
    json.dump(data,o,ensure_ascii=False,indent=2)
PY
fi

cat > docker-compose.yml <<EOF
services:
  autoscrape:
    build: .
    container_name: ${APP_NAME}
    restart: unless-stopped
    ports:
      - "${PORT}:3000"
    volumes:
      - ./config.json:/app/config.json
EOF

docker compose down 2>/dev/null || true
docker compose build --no-cache
docker compose up -d

echo
echo "安装完成"
echo "访问地址: ${BASE_URL}"
echo "Clash: ${BASE_URL}/clash/sub"
echo "V2Ray: ${BASE_URL}/vmess/sub"
echo "Sing-box: ${BASE_URL}/sing-box/sub"
