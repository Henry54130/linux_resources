## 1. 安裝指令

```bash
curl -fsSL https://raw.githubusercontent.com/Henry54130/linux_resources/main/docker/wolf/install.sh | bash
```

---

## 2. 效果

新增官方無法持久化的設定
* **軟體套件**：
* Brave 瀏覽器
* VSCodium 編輯器
* Obsidian 筆記軟體
* LibreOffice（含繁中）
* GNOME System Monitor
* Google Noto CJK 繁中字型


* **系統權限**：
* 映射宿主機同名使用者與 UID/GID
* 容器內免密碼 `sudo`

---

## 3. 微調原因
官方映像檔中
* 無中文支援、無字型
* 無生產力軟體
* 桌面設定無法持久化
* 每次root密碼都會變（難以進行開發）

## 4. 架構

|檔案|功用|說明|
|----|----|----|
|Dockerfile.xfce|客製化持久系統|以官方映像檔為基底，設定密碼、安裝基本程式|
|docker-compose.yml|拉取官方wolf img,結合上者形成較好用的遠端桌面|
|install.sh|全自動安裝|檢查docker指令、下載所需檔案並執行docker compose|

