#!/usr/bin/env bash
set -euo pipefail

APP_NAME="autoscrape-free-nodes"
APP_DIR="/opt/${APP_NAME}"
REPO="https://github.com/Re0XIAOPA/AutoScrapeFreeNodes.git"

if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 用户运行"
  exit 1
fi

echo "===================================="
echo " AutoScrapeFreeNodes 专业安装程序"
echo "===================================="

# 输入访问方式
echo "请选择访问方式:"
echo "1) 域名访问"
echo "2) IP访问"
read -rp "选择 [1/2]: " MODE

if [ "$MODE" = "1" ]; then
    read -rp "请输入域名(例如 sub.example.com): " HOST
    read -rp "是否使用HTTPS? [y/N]: " HTTPS
    if [[ "$HTTPS" =~ ^[Yy]$ ]]; then
        BASE_URL="https://${HOST}"
    else
        BASE_URL="http://${HOST}"
    fi
else
    read -rp "请输入VPS公网IP: " HOST
    read -rp "请输入端口(例如9862): " PORT
    BASE_URL="http://${HOST}:${PORT}"
fi

PORT=${PORT:-3000}

echo
echo "使用订阅地址:"
echo "$BASE_URL"
echo

# 安装基础环境
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

# 清理旧版本
echo "[1/5] 清理旧容器..."

docker rm -f ${APP_NAME} >/dev/null 2>&1 || true

mkdir -p /opt

# 获取源码
echo "[2/5] 下载源码..."

rm -rf "${APP_DIR}"
git clone "${REPO}" "${APP_DIR}"

cd "${APP_DIR}"

# 修改config.json
echo "[3/5] 修改config.json..."

python3 <<PY
import json

path="config.json"

with open(path,"r",encoding="utf-8") as f:
    data=json.load(f)

def fix(obj):
    if isinstance(obj,dict):
        for k,v in obj.items():
            if k=="url" and isinstance(v,str):
                for p in [
                    "/clash/sub",
                    "/vmess/sub",
                    "/sing-box/sub",
                    "/ss/sub",
                    "/ssr/sub",
                    "/trojan/sub"
                ]:
                    if p in v:
                        obj[k]="${BASE_URL}"+p
            else:
                fix(v)
    elif isinstance(obj,list):
        for x in obj:
            fix(x)

fix(data)

with open(path,"w",encoding="utf-8") as f:
    json.dump(data,f,ensure_ascii=False,indent=2)

print("config.json修改完成")
PY

# 创建compose
echo "[4/5] 创建Docker配置..."

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
    environment:
      NODE_ENV: production
      TZ: Asia/Shanghai
EOF

# 启动
echo "[5/5] 构建启动..."

docker compose down >/dev/null 2>&1 || true
docker compose build --no-cache
docker compose up -d

IP=$(curl -4 -fsSL https://api.ipify.org || hostname -I | awk '{print $1}')

echo
echo "===================================="
echo " 安装完成"
echo "===================================="
echo
echo "访问地址:"
echo "${BASE_URL}"
echo
echo "订阅地址:"
echo "${BASE_URL}/clash/sub"
echo "${BASE_URL}/vmess/sub"
echo "${BASE_URL}/sing-box/sub"
echo
echo "管理:"
echo "docker logs -f ${APP_NAME}"
echo "docker restart ${APP_NAME}"
echo
