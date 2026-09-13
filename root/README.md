# 社團電腦維護與部署系統 (Club Linux Deployment & Rescue System)

針對社團共用電腦（Linux Mint XFCE / Windows 雙系統環境）設計的自動化維護工具組。

---

## 隨身碟救援與刷機 SOP

遇到電腦故障或需要重新安裝時，請使用社辦專用 Ventoy 隨身碟：

### 步驟 1：插入隨身碟並執行引導腳本

- **Windows 環境**：
  打開隨身碟目錄，對 `reboot-to-usb.bat` 連點兩下（或右鍵以系統管理員身分執行）。電腦重新啟動後，在藍底畫面點選「使用裝置 (Use a device)」並選擇該隨身碟。
- **Linux 環境**：
  在隨身碟目錄開啟終端機，執行以下指令：
  ```bash
  sudo ./reboot-to-usb.sh
  ```
  電腦將自動重新啟動並直接載入隨身碟。

### 步驟 2：進入 Ventoy 選單並挑選任務

電腦啟動後將停留在開機選單，請依需求選擇：

- **`1_install_mint.iso`**：全自動重灌與映像檔寫入，直接將本機還原為社團標準環境。
- **`2_repair_remote.iso`**：無痕遠端救援模式（載入記憶體），自動啟用連線環境，由幹部遠端排錯。

---

## 隨身碟檔案配置

```text
/
├── reboot-to-usb.bat        # Windows 專用重開引導腳本
├── reboot-to-usb.sh         # Linux 專用重開引導腳本
├── 1_install_mint.iso       # 預設全自動安裝映像檔
├── 2_repair_remote.iso      # 純記憶體遠端救援映像檔
└── ventoy/
    └── ventoy.json          # 開機選單別名與預設倒數設定
```
