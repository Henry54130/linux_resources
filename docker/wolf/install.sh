#!/bin/bash
set -e

# 1. 檢查並安裝 Docker / Docker Compose
if ! command -v docker &> /dev/null; then
    echo "未偵測到 Docker，正在安裝 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    echo "Docker 安裝完成。請注意：若後續指令權限不足，請重新登入後再次執行。"
fi

if ! docker compose version &> /dev/null; then
    echo "未偵測到 Docker Compose，正在安裝外掛程式..."
    sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin
fi

# 確保 Docker 服務正在運行
if ! systemctl is-active --quiet docker; then
    echo "正在啟動 Docker 服務..."
    sudo systemctl start docker
fi

# 2. 建立並進入安裝目錄
INSTALL_DIR="$HOME/wolf-desktop"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 3. 自動偵測 iGPU render 節點
RENDER_NODE=$(ls /dev/dri/renderD* 2>/dev/null | head -n 1)
if [ -z "$RENDER_NODE" ]; then
    echo "未偵測到 GPU 渲染節點，使用預設 /dev/dri/renderD128"
    RENDER_NODE="/dev/dri/renderD128"
else
    echo "偵測到 GPU 節點: $RENDER_NODE"
fi

# 4. 下載設定檔
BASE_URL="https://raw.githubusercontent.com/Henry54130/linux_resources/main/docker/wolf"
curl -fsSL "$BASE_URL/Dockerfile.xfce" -o Dockerfile.xfce
curl -fsSL "$BASE_URL/docker-compose.yml" -o docker-compose.yml

# 5. 動態修改 GPU 節點
sed -i "s|/dev/dri/renderD128|$RENDER_NODE|g" docker-compose.yml

# 6. 動態帶入當前使用者 UID/GID 並啟動
USER=$(whoami) USER_UID=$(id -u) USER_GID=$(id -g) docker compose up -d --build

echo "Wolf 部署完成。"
