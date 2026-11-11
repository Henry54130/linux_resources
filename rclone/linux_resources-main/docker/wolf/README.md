

## 1. 快速安裝

```bash
curl -fsSL https://raw.githubusercontent.com/Henry54130/linux_resources/main/docker/wolf/install.sh | bash

```

## 2. 解決痛點（微調原因）

官方映像檔存在以下限制，難以直接作為日常開發與生產力環境使用：

* **缺少繁中環境**：無 CJK 中文字型與語系支援，介面與網頁易缺字、破音字或亂碼。
* **無生產力工具**：預設未內建常用瀏覽器、編輯器與辦公套件。
* **桌面無法持久化**：重啟後個人化桌面偏好與系統設定容易重置。
* **權限管理不便**：容器啟動時隨機指派 root 密碼，難以快速取得管理權限進行配置。

## 3. 功能特色

* **開箱即用的生產力軟體**：
* **瀏覽器**：Brave Browser
* **編輯與筆記**：VSCodium、Obsidian
* **辦公套件**：LibreOffice（含繁體中文語系包）
* **系統工具**：GNOME System Monitor
* **字型支援**：Google Noto Sans CJK TC 繁體中文字型


* **無縫權限與持久化整合**：
* 自動映射宿主機目前使用者的帳號名稱與 UID/GID，避免掛載檔案權限衝突。
* 容器內提供免密碼 `sudo` 權限，便於開發除錯。


## 4. 專案架構

| 檔案 | 角色 | 說明 |
| --- | --- | --- |
| `Dockerfile.xfce` | 映像檔建置 | 以官方映像檔為基底，預先安裝常用工具、配置中文字型與使用者權限 |
| `docker-compose.yml` | 服務編排 | 整合官方 Wolf 服務與自訂 XFCE 桌面，提供可持久化的串流遠端桌面環境 |
| `install.sh` | 自動化腳本 | 檢查 Docker 環境、下載相關配置檔並自動啟動容器服務 |


