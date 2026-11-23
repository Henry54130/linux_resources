# Rclone 雲端掛載模組套件

本模組提供 OneDrive、Google Drive、Nextcloud 等雲端儲存掛載腳本，皆以 systemd 使用者服務（或系統服務）方式常駐，開機/登入後自動掛載。所有掛載點統一放在 `~/rclone/{remote 名稱}` 下，各腳本可依需要單獨執行。

---

## 一鍵遠端安裝指令（複製貼上即可）

### 0. 一次裝完所有雲端掛載（推薦）
> 依序跑 `install-rclone.sh`（缺才裝）→ 四個 `setup-*.sh` → `check-all.sh` 總結。其中任何一個因為還沒設定對應 remote 而失敗，不會擋住剩下的，最後會印出每一個的成功/失敗狀態。含互動輸入（問密碼等），**不要**包在 `bash -c "$(...)"` 裡（理由見下方）。
```bash
cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./install-all.sh && cd ../.. && rm -rf linux_resources-main
```

### 1. 安裝 rclone 與 fuse3（基礎依賴，需先執行）
> 如果用上面的 `install-all.sh` 可以跳過這步，它會自己檢查並補裝。
```bash
bash -c "$(cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && sudo ./install-rclone.sh && cd ../.. && rm -rf linux_resources-main)"
```

> 以下指令含互動輸入（`rclone config` / 開啟編輯器），**不要**包在 `bash -c "$(...)"` 裡執行 —— 那會讓整段輸出被 command substitution 捕捉而不會顯示在終端機上，看起來像卡住，其實是互動選單在你看不到的地方等你輸入。直接貼上整行、在目前的互動式 shell 執行即可。

### 2. 設定 OneDrive 掛載（掛載至 `~/rclone/onedrive`）
> 若尚未設定 OneDrive remote，腳本會提示你執行 `rclone config`（OneDrive 需走瀏覽器 OAuth 登入授權，無法像 Nextcloud 那樣用帳密一行帶過）。remote 取什麼名字都可以，腳本會依型別自動偵測，並**為每一個** `onedrive` 型別 remote 各自建立 `rclone-{名稱}.service` 掛到 `~/rclone/{名稱}`（可同時掛多個 OneDrive 帳號，名稱需各不相同）。
```bash
cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-onedrive.sh && cd ../.. && rm -rf linux_resources-main
```

### 3. 設定 Google Drive 掛載（掛載至 `~/rclone/gdrive`）
> 若尚未設定任何 Google Drive remote，腳本會提示你執行 `rclone config`。會**為每一個** `drive` 型別 remote 各自建立 `rclone-{名稱}.service` 掛到 `~/rclone/{名稱}`（可同時掛多個 Google Drive 帳號，名稱需各不相同）。
```bash
cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-google-drive.sh && cd ../.. && rm -rf linux_resources-main
```

### 4. 設定 Nextcloud 掛載（掛載至 `~/rclone/nextcloud`）
> 若尚未設定 `nextcloud` remote，腳本會直接問你 Nextcloud 網址、帳號、密碼（可填登入密碼或自行在 Nextcloud 網頁 Security 設定建立的 App Password），用 `rclone config create --obscure` 非互動建立 remote，不會再跑容易誤改欄位的 `rclone config` 編輯精靈。
```bash
cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-personal-nextcloud.sh && cd ../.. && rm -rf linux_resources-main
```

### 5. 設定 Agent Nextcloud 掛載（具名 remote，使用者服務 + linger，掛載至 `~/rclone/agents-nextcloud`）
> **兩層掛載架構的第 1 層**：rclone 把 Nextcloud 掛到 `~/rclone/agents-nextcloud`，之後由 docker bind-mount 進 agent 容器的 `/workspace/agents-nextcloud`（第 2 層）。跟其他三個掛載一樣走 `rclone config create --obscure` 建立具名 remote（固定取名 `agents-nextcloud`，不用型別自動偵測，否則會跟個人 Nextcloud 的 webdav remote 搞混）；差別只在於這個掛載帶 `--allow-other --uid/--gid 1000`，且需要 `/etc/fuse.conf` 的 `user_allow_other`（腳本會嘗試自動加入）——因為 dockerd 是以 root 身分讀取這個 FUSE 掛載去 bind-mount，FUSE 預設連 root 都擋。本來想用範圍較小的 `allow_root`（只讓 root 進來，不給其他 host 使用者），但 rclone 的 mount 已經不支援這個 flag 了（上游 bazil/fuse#144 移除），所以只能用 `allow_other`。若尚未設定 remote，腳本會直接問你網址/帳號/密碼。
```bash
cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./setup-agents-nextcloud.sh && cd ../.. && rm -rf linux_resources-main
```

### 6. 巡檢所有掛載（唯讀，不裝任何東西）
```bash
cd ~ && curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && cd linux_resources-main/rclone && ./check-all.sh && cd ../.. && rm -rf linux_resources-main
```

---

## 本地安裝方式

若已下載倉庫，進入目錄執行對應指令即可：
```bash
cd rclone
./install-all.sh                # 一次跑完下面所有步驟（缺依賴會自動裝，個別失敗不擋其他項）

# 或者逐個手動跑：
sudo ./install-rclone.sh        # 安裝 rclone + fuse3
./setup-onedrive.sh             # 掛載 OneDrive（需先 rclone config 設定 onedrive remote）
./setup-google-drive.sh         # 掛載 Google Drive（需先 rclone config 設定 gdrive remote）
./setup-personal-nextcloud.sh            # 掛載 Nextcloud（會互動問帳密，可填登入密碼或 App Password）
./setup-agents-nextcloud.sh      # 掛載 Agent Nextcloud（同樣走具名 remote，固定取名 agents-nextcloud，額外帶 allow-other 給 docker 讀）
cp .env.example .env && vim .env  # 選填：覆寫 rclone_mount_batch.sh 的批次掛載設定
./rclone_mount_batch.sh         # 批次掛載 .env 指定（或全部已設定）的 remote
./check-all.sh                  # 巡檢 ~/rclone/ 下每個掛載：真的掛上了嗎？下兩層有東西嗎？
```

### 腳本說明
| 腳本 | 用途 | 掛載方式 |
| --- | --- | --- |
| `install-all.sh` | 依序跑 `install-rclone.sh` + 全部 `setup-*.sh` + `check-all.sh`，個別失敗不擋其他項，最後印成功/失敗總結 | - |
| `install-rclone.sh` | 安裝 rclone、fuse3 | - |
| `setup-onedrive.sh` | 掛載**所有** `onedrive` 型別 remote | 每個 remote 各一個 systemd **使用者**服務 `rclone-{名稱}.service` → `~/rclone/{名稱}` |
| `setup-google-drive.sh` | 掛載**所有** `drive` 型別 remote | 每個 remote 各一個 systemd **使用者**服務 `rclone-{名稱}.service` → `~/rclone/{名稱}` |
| `setup-personal-nextcloud.sh` | 掛載**所有** `webdav` 型別 remote（排除 `agents-nextcloud`） | 每個 remote 各一個 systemd **使用者**服務 `rclone-{名稱}.service` → `~/rclone/{名稱}` |
| `setup-agents-nextcloud.sh` | 掛載 Agent Nextcloud（具名 remote `agents-nextcloud`，供 docker bind-mount 讀取） | systemd **使用者**服務 + linger → `~/rclone/agents-nextcloud`，帶 `--allow-other`（`allow_root` 已被 rclone 移除不能用） |
| `rclone_mount_batch.sh` | 批次掛載多個已設定的 remote | 前景／背景常駐 → `~/rclone/{remote}`，可用 `.env` 設定清單 |
| `check-all.sh` | 巡檢 `~/rclone/` 下每個 remote：是否真的掛載、`ls -la` 內容、下兩層有沒有實際檔案 | 唯讀檢查，不掛載也不改動任何東西 |

### 記錄（logging）
所有 `setup-*.sh` 與 `check-all.sh` 共用 `lib/log.sh`：每次執行都會在這個 repo 目錄下的 `rclone/logs/{執行時間}.log`（已加入 `.gitignore`，不會進版控）產生一份完整紀錄（終端機看到的輸出 + 最後的 `systemctl status`／`journalctl`／掛載檢查），不會覆蓋前一次的記錄。東西掛不起來的時候，直接把最新那個 log 檔內容貼出來分析即可，不用再手動跑一輪 `journalctl`。
