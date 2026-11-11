## 安裝指令

```bash
curl -fsSL https://github.com/Henry54130/linux_resources/archive/refs/heads/main.tar.gz | tar -xz && (cd linux_resources-main/guest-management && sudo ./install.sh) && rm -rf linux_resources-main

```

---

## 日常操作說明

### 1. 修改範本桌面/環境

1. 登入 `template` 使用者（密碼：`guest`）調整桌布、捷徑或書籤。
2. 打開終端機輸入：
```bash
sudo update-guest-template

```


3. 登出即同步完成。

### 2. 建立專用帳號

```bash
sudo install-persistent-user <帳號> <密碼>

```
