#!/bin/bash
TARGET_USER="guest"
TARGET_HOME="/home/$TARGET_USER"
TEMPLATE="/etc/guest-template/"

if [ -d "$TEMPLATE" ]; then
    # 終止殘留行程，解鎖檔案
    pkill -u "$TARGET_USER" -9 2>/dev/null
    sleep 1

    # 增量同步覆蓋
    rsync -a --delete "$TEMPLATE" "$TARGET_HOME/"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
fi

exit 0
