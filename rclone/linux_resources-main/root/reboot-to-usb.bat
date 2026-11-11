@echo off
chcp 65001 >nul
title 救援模式引導程式 (Windows)

:: 自動要求管理員權限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 正在取得管理員權限...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo =======================================================
echo          社團電腦救援模式引導程式 (Windows)
echo =======================================================
echo.
echo 1. 關閉快速啟動 (避免鎖死硬碟與隨身碟)...
powercfg -h off >nul 2>&1

echo 2. 準備進入 UEFI 開機選單...
echo.
echo 【提示】電腦重開後，請在藍底畫面點選：
echo    -> [使用裝置 (Use a device)]
echo    -> 選擇你的 [USB 隨身碟名稱]
echo.
echo 電腦將在 3 秒後重新啟動...
timeout /t 3 /nobreak >nul

:: 冷重啟並直衝進階開機選單
shutdown /r /o /f /t 0
