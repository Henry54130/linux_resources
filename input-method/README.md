# Fcitx5 輸入法模組套件

本模組拆分為三項獨立腳本，可依個人需要單獨或整批安裝。皆支援開機全域自動啟動與環境變數設定。

---

## 一鍵遠端安裝指令（複製貼上即可）

### 1. 全部一起裝（Fcitx5 + 小麥注音 + 拼音）
```bash
bash -c "$(curl -fsSL https://github.com/Henry54130/linux-resource/archive/refs/heads/main.tar.gz | tar -xz && cd linux-resource-main/input-method && sudo ./install.sh && cd ../.. && rm -rf linux-resource-main)"
```

### 2. 僅安裝 Fcitx5 基礎框架（不含額外輸入法）
```bash
bash -c "$(curl -fsSL https://github.com/Henry54130/linux-resource/archive/refs/heads/main.tar.gz | tar -xz && cd linux-resource-main/input-method && sudo ./install-fcitx5.sh && cd ../.. && rm -rf linux-resource-main)"
```

### 3. 僅安裝 小麥注音（會自動補裝 Fcitx5 依賴）
```bash
bash -c "$(curl -fsSL https://github.com/Henry54130/linux-resource/archive/refs/heads/main.tar.gz | tar -xz && cd linux-resource-main/input-method && sudo ./install-mcbopomofo.sh && cd ../.. && rm -rf linux-resource-main)"
```

### 4. 僅安裝 拼音（會自動補裝 Fcitx5 依賴）
```bash
bash -c "$(curl -fsSL https://github.com/Henry54130/linux-resource/archive/refs/heads/main.tar.gz | tar -xz && cd linux-resource-main/input-method && sudo ./install-pinyin.sh && cd ../.. && rm -rf linux-resource-main)"
```

---

## 本地安裝方式

若已下載倉庫，進入目錄執行對應指令即可：
```bash
cd input-method
sudo ./install-fcitx5.sh
sudo ./install-mcbopomofo.sh
sudo ./install-pinyin.sh
sudo ./install.sh
```
