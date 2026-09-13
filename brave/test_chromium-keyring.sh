#!/usr/bin/env bash
set -e

BRAVE_BIN="$(which brave-browser || which brave || echo '/opt/brave.com/brave/brave')"

echo "=========================================="
echo "測試 1：標準啟動（會查詢系統 Keyring）"
echo "=========================================="
pkill -f brave || true
sleep 1

time timeout 20s "$BRAVE_BIN" \
  --headless=new \
  --disable-gpu \
  --dump-dom "https://www.google.com/search?q=test" > /dev/null || echo ">> 逾時（被 Keyring 卡死）"

echo ""
echo "=========================================="
echo "測試 2：繞過 Keyring (--password-store=basic)"
echo "=========================================="
pkill -f brave || true
sleep 1

time "$BRAVE_BIN" \
  --headless=new \
  --disable-gpu \
  --password-store=basic \
  --dump-dom "https://www.google.com/search?q=test" > /dev/null

echo ""
echo "測試完成。"
