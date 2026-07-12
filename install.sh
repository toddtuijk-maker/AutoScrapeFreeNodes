#!/usr/bin/env bash
set -euo pipefail

# AutoScrapeFreeNodes Professional Installer
# GitHub: toddtuijk-maker

APP_NAME="autoscrape-free-nodes"
APP_DIR="/opt/${APP_NAME}"
REPO_URL="https://github.com/toddtuijk-maker/AutoScrapeFreeNodes.git"

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }

if [ "$(id -u)" != "0" ]; then
    red "请使用 root 用户运行"
    exit 1
fi

echo "=========================================="
echo " AutoScrapeFreeNodes 专业安装程序"
echo "=========================================="

echo
echo "请选择访问方式:"
echo "1) 域名访问"
echo "2) IP访问"
read -rp "请输入选项 [1/2]: " MODE

if [ "$MODE" = "1" ]; then
    read -rp "请输入域名(例如 jh.erger.ccwu.cc): " HOST
    read -rp "是否使用 HTTPS? [y/N]: " USE_SSL

    if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
        BASE_URL="https://${HOST}"
    else
        BASE_URL="http://${HOST}"
    fi
else
    read -rp "请输入VPS公网IP: " HOST
    BASE_URL="http://${HOST}"
fi

echo
read -rp "请输入Docker外部端口(默认3000): " HOST_PORT
HOST_PORT=${HOST_PORT:-3000}

echo
green "最终访问地址:"
echo "${BASE_URL}"

# 检查端口
if command -v ss >/dev/null 2>&1; then
    if ss -lnt | grep -q ":${HOST_PORT} "; then
        red "端口 ${HOST_PORT} 已被占用:"
        ss -lntp | grep ":${HOST_PORT}" || true
        exit 1
    fi
fi

# 安装基础依赖
install_packages(){
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y curl git python3 ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl git python3 ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl git python3 ca-certificates
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm curl git python
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl git python3
    else
        red "不支持的Linux系统"
        exit 1
    fi
}

install_packages

# Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "安装Docker..."
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker >/dev/null 2>&1 || true
systemctl start docker >/dev/null 2>&1 || true

if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    red "Docker Compose不存在"
    exit 1
fi

echo
echo "清理旧安装..."

docker rm -f ${APP_NAME} >/dev/null 2>&1 || true
rm -rf "${APP_DIR}"

echo "下载项目..."

git clone --depth=1 "${REPO_URL}" "${APP_DIR}"

cd "${APP_DIR}"

echo "修改config.json..."

export BASE_URL

python3 <<'PY'
import json,os

file="config.json"
base=os.environ["BASE_URL"].rstrip("/")

if not os.path.exists(file):
    print("没有config.json，跳过")
    exit()

with open(file,"r",encoding="utf-8") as f:
    data=json.load(f)

paths=[
"/clash/sub",
"/vmess/sub",
"/sing-box/sub",
"/ss/sub",
"/ssr/sub",
"/trojan/sub"
]

def change(x):
    if isinstance(x,dict):
        for k,v in x.items():
            if k=="url" and isinstance(v,str):
                for p in paths:
                    if p in v:
                        x[k]=base+p
            else:
                change(v)
    elif isinstance(x,list):
        for i in x:
            change(i)

change(data)

with open(file,"w",encoding="utf-8") as f:
    json.dump(data,f,ensure_ascii=False,indent=2)

print("config.json更新完成")
PY

echo "生成docker-compose..."

cat > docker-compose.yml <<EOF
services:
  autoscrape:
    build: .
    container_name: ${APP_NAME}
    restart: unless-stopped
    ports:
      - "${HOST_PORT}:3000"
    volumes:
      - ./config.json:/app/config.json
      - ./data:/app/data
    environment:
      NODE_ENV: production
      TZ: Asia/Shanghai
EOF

if command -v ufw >/dev/null 2>&1; then
    ufw allow ${HOST_PORT}/tcp || true
fi

echo "开始构建..."

${COMPOSE} down >/dev/null 2>&1 || true
${COMPOSE} build --no-cache
${COMPOSE} up -d

sleep 5

if docker ps | grep -q "${APP_NAME}"; then
    green "安装成功"
else
    red "启动失败"
    docker logs ${APP_NAME}
    exit 1
fi

echo
echo "=========================================="
echo " 完成"
echo "=========================================="
echo
echo "访问地址:"
echo "${BASE_URL}"
echo
echo "订阅:"
echo "${BASE_URL}/clash/sub"
echo "${BASE_URL}/vmess/sub"
echo "${BASE_URL}/sing-box/sub"
echo
echo "管理:"
echo "docker logs -f ${APP_NAME}"
echo "docker restart ${APP_NAME}"
echo
