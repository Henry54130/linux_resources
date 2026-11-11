# Rclone 雲端掛載模組套件

本模組提供 OneDrive、Google Drive、Nextcloud 等雲端儲存掛載腳本，皆以 systemd 使用者服務（或系統服務）方式常駐，開機/登入後自動掛載。所有掛載點統一放在 `~/rclone/{remote 名稱}` 下，各腳本可依需要單獨執行。

---

## 一鍵遠端安裝指令（複製貼上即可）

### 1. 安裝 rclone 與 fuse3（基礎依賴，需先執行）
```bash
bash -c "$(curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && sudo ./install-rclone.sh && cd ../.. && rm -rf linux_resources-main)"
```

> 以下指令含互動輸入（`rclone config` / 開啟編輯器），**不要**包在 `bash -c "$(...)"` 裡執行 —— 那會讓整段輸出被 command substitution 捕捉而不會顯示在終端機上，看起來像卡住，其實是互動選單在你看不到的地方等你輸入。直接貼上整行、在目前的互動式 shell 執行即可。

### 2. 設定 OneDrive 掛載（掛載至 `~/rclone/onedrive`）
> 執行前請先用 `rclone config` 設定好名為 `onedrive` 的 remote。
```bash
curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-onedrive.sh && cd ../.. && rm -rf linux_resources-main
```

### 3. 設定 Google Drive 掛載（掛載至 `~/rclone/gdrive`）
> 若尚未設定 `gdrive` remote，腳本會提示你執行 `rclone config`。
```bash
curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-google-drive.sh && cd ../.. && rm -rf linux_resources-main
```

### 4. 設定 Nextcloud 掛載（掛載至 `~/rclone/nextcloud`）
> 若尚未設定 `nextcloud` remote，腳本會問你 Nextcloud 網址、帳號、密碼，並呼叫 Nextcloud 的 `getapppassword` API 自動換一個名為 `rclone_{主機名}_{帳號}` 的 App Password 來建立 remote——不會把你的主密碼存到任何地方，也不會再跑互動式的 `rclone config` 精靈（避免手動編輯誤改欄位）。若帳號有開 2FA，API 交換可能失敗，需改到 Nextcloud 網頁的 Security 設定手動建立 App Password。
```bash
curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-nextcloud.sh && cd ../.. && rm -rf linux_resources-main
```

### 5. 設定 Agent Workspace 掛載（Nextcloud WebDAV 直連，系統服務，掛載至 `~/rclone/agent-workspace`）
> 此方式不經 `rclone config`，直接以帳密連線，適合無人值守的伺服器/容器環境。指令會先打開編輯器讓你填入 `NEXTCLOUD_WEBDAV_URL`、`NEXTCLOUD_USER`、`NEXTCLOUD_PASSWORD`（`AGENT_WORKSPACE` 可留空，預設為 `~/rclone/agent-workspace`），存檔後才繼續安裝。
```bash
curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && { [ -f .env ] || cp .env.example .env; } && ${EDITOR:-nano} .env && ./setup-agent-workspace.sh && cd ../.. && rm -rf linux_resources-main
```

---

## 本地安裝方式

若已下載倉庫，進入目錄執行對應指令即可：
```bash
cd rclone
sudo ./install-rclone.sh        # 安裝 rclone + fuse3
./setup-onedrive.sh             # 掛載 OneDrive（需先 rclone config 設定 onedrive remote）
./setup-google-drive.sh         # 掛載 Google Drive（需先 rclone config 設定 gdrive remote）
./setup-nextcloud.sh            # 掛載 Nextcloud（會互動問帳密並自動取得 App Password）
cp .env.example .env && vim .env  # 填入 Nextcloud WebDAV 帳密與掛載路徑
./setup-agent-workspace.sh      # 以系統服務掛載 Agent Workspace（WebDAV 直連，會要求 sudo）
./rclone_mount_batch.sh         # 批次掛載 .env 指定（或全部已設定）的 remote
```

### 腳本說明
| 腳本 | 用途 | 掛載方式 |
| --- | --- | --- |
| `install-rclone.sh` | 安裝 rclone、fuse3 | - |
| `setup-onedrive.sh` | 掛載 OneDrive | systemd **使用者**服務 → `~/rclone/onedrive` |
| `setup-google-drive.sh` | 掛載 Google Drive | systemd **使用者**服務 → `~/rclone/gdrive` |
| `setup-nextcloud.sh` | 掛載 Nextcloud | systemd **使用者**服務 → `~/rclone/nextcloud` |
| `setup-agent-workspace.sh` | 以帳密直連掛載 Nextcloud WebDAV | systemd **系統**服務 → `~/rclone/agent-workspace`（可用 `AGENT_WORKSPACE` 覆寫） |
| `rclone_mount_batch.sh` | 批次掛載多個已設定的 remote | 前景／背景常駐 → `~/rclone/{remote}`，可用 `.env` 設定清單 |
