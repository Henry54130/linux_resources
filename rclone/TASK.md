# Rclone 模組進度記錄

更新時間：2026-11-11（分支 `feature/rclone-mount-batch`）

## 目標
1. 新增 Nextcloud 掛載支援（`setup-personal-nextcloud.sh`）。
2. 所有雲端掛載統一放到 `~/rclone/{remote 名稱}`（onedrive / gdrive / nextcloud / agent-workspace）。
3. README 提供「複製貼上一行、下載整包、跑完自動刪除」的安裝指令，格式對齊 `input-method/README.md`。

## 已完成並在 mint@msi 實測成功
- **Nextcloud**（`setup-personal-nextcloud.sh`）：掛載到 `~/rclone/nextcloud`，可正常 `ls` 列出檔案。
  - remote 需命名為全小寫 `nextcloud`（大小寫會跟 systemd service 裡寫死的 `nextcloud:` 不符，掛載會失敗）。
  - `url` 必須是完整 WebDAV 路徑，例如 `http://host:port/remote.php/dav/files/USERNAME/`，光打網域/主機會導致 `Dir.Stat error` / `IO error`。
  - 腳本已改為非互動：直接問 URL/帳號/密碼，用 `rclone config create --obscure` 建立 remote，不會再進容易誤改欄位的 `rclone config` 編輯精靈。

## 已修正、但尚未在真實環境驗證通過（卡在無法 push）
- **Google Drive**（`setup-google-drive.sh`）：systemd service 模板裡的 `--drive-export-dir ""` 在部分 systemd 版本會被整段吃掉，導致 `--vfs-read-chunk-size` 被誤判成它的值，rclone 啟動直接 FAILURE。本地已移除該行（commit `589fc44`），**但因為這個環境沒有 git 推送權限，GitHub `main` 上還是舊版，mint@msi 用 curl 一鍵指令抓到的仍是壞版本**，所以最新一次實測（exit code 1、`--drive-export-dir  --vfs-read-chunk-size`）還是舊 bug 的重現，不代表修正無效。
  - 需要：push 到 `origin/main` 後用一鍵指令重測一次確認。

## 尚未測試
- `setup-onedrive.sh` → `~/rclone/onedrive`
- `setup-agents-nextcloud.sh` → `~/rclone/agents-nextcloud`（2026-11-22 已統一成跟其他三個一樣用具名 remote + `rclone config create --obscure`，拿掉獨立的 `mount-agents-nextcloud.sh`/`agents-nextcloud-mount.service` 模板與 `.env` 帳密欄位；差異只剩固定 remote 名稱 `agents-nextcloud`（不走型別自動偵測，避免跟個人 nextcloud 的 webdav remote 混淆）跟多帶的 `--allow-other --uid/--gid 1000`，給 docker 的 root 讀取。原本想用範圍較小的 `--allow-root`，但在 mint@msi 實測發現 rclone 直接印 `ERROR: Ignoring --allow-root. Support has been removed upstream (bazil/fuse#144)`，這個 flag 現在是死的，只能退回 `--allow-other`，等於對該台機器所有使用者開放——單人機器上可接受，但記住這不是真的「只限自己」）
- `rclone_mount_batch.sh` → 批次掛載

## 新增：共用 logger + 巡檢腳本（2026-11-22）
- 新增 `lib/log.sh`：所有 `setup-*.sh` 與新的 `check-all.sh` 共用這個 `log()` 函式，每次執行會各自在 repo 本身的 `rclone/logs/{執行時間}.log`（已加 `.gitignore`）寫一份記錄（不覆蓋舊的）。注意：這跟掛載點 `~/rclone/{remote}` 是兩個不相關的目錄，別搞混。，內容包含整段終端輸出 + 執行完後自動附加的 `systemctl status`/`journalctl`/掛載檢查診斷區塊。目的：掛載出問題時只要貼一個 log 檔，不用再逐個手動跑診斷指令。
- 新增 `check-all.sh`：唯讀巡檢 `~/rclone/` 下每個 remote 目錄——是否真的 `mountpoint`、`ls -la` 內容、往下兩層有沒有實際檔案（避免「服務顯示 active 但其實是空殼」這種誤判，像 agents-nextcloud 之前卡住時遇到的情況）。
- 新增 `install-all.sh`：一個網路指令依序跑完 `install-rclone.sh`（缺才裝）→ 四個 `setup-*.sh` → `check-all.sh`。用 `set -uo pipefail`（不含 `-e`），單一 setup 因 remote 還沒設定而失敗不會擋住其他項，跑完印每一項的成功/失敗總結。

## 新增：多 remote 支援 + 服務名跟隨 remote 名稱（2026-11-23）
- `setup-onedrive.sh` 補上先前缺少的 rclone 安裝檢查 + 偵測不到 remote 時的互動 fallback（會問要不要跑 `rclone config`），對齊 gdrive。
- 三個型別偵測腳本（onedrive / gdrive / personal-nextcloud）由「只抓第一個同型別 remote、服務名寫死」改為 **迴圈掛載該型別的每一個 remote**：用 `mapfile` 收集全部，各自建立 `~/rclone/{名稱}` 掛載點與專屬服務 `rclone-{名稱}.service`。可同時掛多個同型別帳號（例如多個 gdrive），前提是 remote 名稱各不相同。
  - linger 與 `daemon-reload` 維持迴圈外只做一次。
  - **personal-nextcloud 排除 `agents-nextcloud`**（兩者同為 webdav 型別）：否則會把 agents 掛載也掃進來、建出缺少 `--allow-other` 的衝突服務。`agents-nextcloud` 仍由專屬腳本以固定名稱管理。
  - 注意：remote 名稱會變成 systemd unit 名的一部分，需為 ASCII（`[a-zA-Z0-9:_.-]`），勿用空格或中文。
- 坑點 4（下方）已過時：onedrive/gdrive/personal-nextcloud 現已改型別偵測，remote 名稱大小寫/取名不再需要跟腳本寫死的字串一致；只有 `agents-nextcloud` 仍是固定名稱。

## 過程中修正的坑（給未來參考）
1. **`bash -c "$(...)"` 包裝會吃掉 stdout**：互動式腳本（會跑 `rclone config` 或開編輯器）包在這層裡，選單文字會被 command substitution 捕捉、不顯示在終端機，看起來像卡住。README 的一鍵指令已改成直接串接執行，不包 `bash -c`。
2. **一鍵指令疊目錄**：若在已解壓的目錄裡繼續貼下一個一鍵指令，會巢狀解壓、清理只退一層。README 的指令已全部加 `cd ~ &&` 防呆。
3. **`rclone config` 編輯精靈容易誤觸**：手動編輯既有 remote 時，`url`/`pass` 欄位預設值很容易被打錯或被略過（例如 `pass` 選單預設是「不設密碼」，沒選 `y` 就按 Enter 會把密碼清空）。能避開互動精靈、改用 `rclone config create/update` 帶參數直接寫比較安全。
4. **remote 名稱大小寫敏感**：腳本寫死小寫名稱（`nextcloud:`、`gdrive:`、`onedrive:`），手動在 `rclone config` 建立時要注意打一樣的大小寫。
5. 這個工作環境（sandbox）**沒有 GitHub 推送權限**，所有 push 需要使用者自己執行（或在 GitHub 網頁合併 PR）。

## 下一步
1. 使用者 push 目前 `feature/rclone-mount-batch`（已包含所有修正）到 GitHub，或合併 PR 進 `main`。
2. 用一鍵指令重測 Google Drive，確認 `--drive-export-dir` 修正生效。
3. 依序測 OneDrive / Agent Workspace / 批次掛載。
4. 全部測過後，把本地已經 merge 好的 `main` 分支 push 上去（或在 GitHub 重新合併）。
