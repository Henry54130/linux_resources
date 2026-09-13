# 社團共用機自動還原管理系統 (Guest Management)

## 快速一鍵安裝（複製貼上這一行即可）

請直接打開終端機，複製貼上下列指令並按 Enter（輸入開機密碼）：

```bash
bash -c "$(curl -fsSL [https://github.com/Henry54130/linux-resource/archive/refs/heads/main.tar.gz](https://github.com/Henry54130/linux-resource/archive/refs/heads/main.tar.gz) | tar -xz && cd linux-resource-main/guest-management && sudo ./install.sh && cd ../.. && rm -rf linux-resource-main)"
```

---

## 日常操作說明（全離線）

### 1. 修改範本桌面/環境
1. 登入 `template` 使用者（密碼：`guest`）調整桌布、捷徑或書籤。
2. 打開終端機輸入：
   ```bash
   sudo update-guest-template
   ```
3. 登出即同步完成。

### 2. 建立常用社員專用帳號
```bash
sudo install-persistent-user <帳號> <密碼>
```
*(此帳號會擁有客製化桌面，且登出不會被清除)*
