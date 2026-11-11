#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
service_template="$script_dir/agent-workspace-mount.service"
mount_script="$script_dir/mount-agent-workspace.sh"
env_file="$script_dir/.env"
systemd_service_file="/etc/systemd/system/agent-workspace-mount.service"

run_privileged() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

# 1. 檢查必要工具
for cmd in rclone fusermount3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Error: %s is not installed. Please install it first (e.g. sudo apt install -y rclone fuse3).\n' "$cmd" >&2
    exit 1
  fi
done

# 2. 初始化 .env 設定檔
if [[ ! -f "$env_file" ]]; then
  if [[ -f "$script_dir/.env.example" ]]; then
    cp -- "$script_dir/.env.example" "$env_file"
    chmod 0600 "$env_file"
    printf 'Created %s from .env.example; please verify credentials.\n' "$env_file"
  else
    printf 'Error: Missing %s and .env.example.\n' "$env_file" >&2
    exit 1
  fi
else
  chmod 0600 "$env_file"
fi

# 讀取設定變數
set -a
. "$env_file"
set +a

workspace_path="${AGENT_WORKSPACE:-$HOME/rclone/agent-workspace}"
mkdir -p -- "$workspace_path"
chmod +x -- "$mount_script"

# 3. 模板代換與安裝 systemd 服務檔
tmp_service="$(mktemp)"
trap 'rm -f -- "$tmp_service"' EXIT

python3 - "$service_template" "$tmp_service" "$env_file" "$mount_script" "$workspace_path" <<'PY'
import pathlib, sys
src, dst, env_path, script_path, ws_path = sys.argv[1:6]
text = pathlib.Path(src).read_text(encoding="utf-8")
text = text.replace("__RCLONE_ENV_FILE__", env_path)
text = text.replace("__MOUNT_SCRIPT_PATH__", script_path)
text = text.replace("__AGENT_WORKSPACE_PATH__", ws_path)
pathlib.Path(dst).write_text(text, encoding="utf-8")
PY

run_privileged install -m 0644 "$tmp_service" "$systemd_service_file"
rm -f -- "$tmp_service"
trap - EXIT

# 4. 註冊並重啟 systemd 服務
run_privileged systemctl daemon-reload
run_privileged systemctl enable --now agent-workspace-mount.service

# 5. 等待掛載完成驗證
mount_ready=false
for _ in {1..10}; do
  if mountpoint -q "$workspace_path"; then
    mount_ready=true
    break
  fi
  sleep 0.5
done

if [[ "$mount_ready" == true ]]; then
  printf '✅ Agent workspace mounted successfully at: %s\n' "$workspace_path"
else
  printf '⚠️ Workspace mount did not become ready at: %s\n' "$workspace_path" >&2
  printf 'Check service logs with: journalctl -u agent-workspace-mount.service -n 20 --no-pager\n' >&2
  exit 1
fi
