# Rclone 模組進度記錄

更新時間：2026-11-11（分支 `feature/rclone-mount-batch`）

## 目標
1. 新增 Nextcloud 掛載支援（`setup-nextcloud.sh`）。
2. 所有雲端掛載統一放到 `~/rclone/{remote 名稱}`（onedrive / gdrive / nextcloud / agent-workspace）。
3. README 提供「複製貼上一行、下載整包、跑完自動刪除」的安裝指令，格式對齊 `input-method/README.md`。

## 已完成並在 mint@msi 實測成功
- **Nextcloud**（`setup-nextcloud.sh`）：掛載到 `~/rclone/nextcloud`，可正常 `ls` 列出檔案。
  - remote 需命名為全小寫 `nextcloud`（大小寫會跟 systemd service 裡寫死的 `nextcloud:` 不符，掛載會失敗）。
  - `url` 必須是完整 WebDAV 路徑，例如 `http://host:port/remote.php/dav/files/USERNAME/`，光打網域/主機會導致 `Dir.Stat error` / `IO error`。
  - 腳本已改為非互動：直接問 URL/帳號/密碼，用 `rclone config create --obscure` 建立 remote，不會再進容易誤改欄位的 `rclone config` 編輯精靈。

## 已修正、但尚未在真實環境驗證通過（卡在無法 push）
- **Google Drive**（`setup-google-drive.sh`）：systemd service 模板裡的 `--drive-export-dir ""` 在部分 systemd 版本會被整段吃掉，導致 `--vfs-read-chunk-size` 被誤判成它的值，rclone 啟動直接 FAILURE。本地已移除該行（commit `589fc44`），**但因為這個環境沒有 git 推送權限，GitHub `main` 上還是舊版，mint@msi 用 curl 一鍵指令抓到的仍是壞版本**，所以最新一次實測（exit code 1、`--drive-export-dir  --vfs-read-chunk-size`）還是舊 bug 的重現，不代表修正無效。
  - 需要：push 到 `origin/main` 後用一鍵指令重測一次確認。

## 尚未測試
- `setup-onedrive.sh` → `~/rclone/onedrive`
- `setup-agent-workspace.sh` / `mount-agent-workspace.sh` → `~/rclone/agent-workspace`（系統服務，需 `.env` 填 Nextcloud WebDAV 帳密）
- `rclone_mount_batch.sh` → 批次掛載

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
