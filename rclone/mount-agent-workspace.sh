#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="$script_dir/.env"

if [[ -f "$env_file" ]]; then
  set -a
  . "$env_file"
  set +a
fi

workspace_path="${AGENT_WORKSPACE:-/home/huang/DATA/agent-mount}"
mount_uid="${MOUNT_UID:-1000}"
mount_gid="${MOUNT_GID:-1000}"

mode="foreground"
case "${1:-}" in
  --foreground) mode="foreground" ;;
  --daemon) mode="daemon" ;;
  "") ;;
  *) printf 'Usage: %s [--foreground|--daemon]\n' "$0" >&2; exit 2 ;;
esac

if mountpoint -q "$workspace_path"; then
  [[ "$mode" == foreground ]] && exit 0
  printf 'Already mounted: %s\n' "$workspace_path"
  exit 0
fi

: "${NEXTCLOUD_WEBDAV_URL:?Set NEXTCLOUD_WEBDAV_URL in .env}"
: "${NEXTCLOUD_USER:?Set NEXTCLOUD_USER in .env}"
: "${NEXTCLOUD_PASSWORD:?Set NEXTCLOUD_PASSWORD in .env}"

command -v rclone >/dev/null || { echo 'rclone is required.' >&2; exit 1; }
command -v fusermount3 >/dev/null || { echo 'fusermount3 is required.' >&2; exit 1; }

mkdir -p -- "$workspace_path"
pass="$(rclone obscure "$NEXTCLOUD_PASSWORD")"
args=(mount :webdav: "$workspace_path"
  --webdav-url "$NEXTCLOUD_WEBDAV_URL" --webdav-vendor nextcloud
  --webdav-user "$NEXTCLOUD_USER" --webdav-pass "$pass"
  --allow-other --uid "$mount_uid" --gid "$mount_gid" --umask 0022
  --vfs-cache-mode writes --dir-cache-time 10s)

if [[ "$mode" == daemon ]]; then
  log_path="${RCLONE_MOUNT_LOG:-/tmp/agent-workspace-rclone.log}"
  nohup rclone "${args[@]}" >>"$log_path" 2>&1 </dev/null &
  printf 'Started rclone mount; log: %s\n' "$log_path"
else
  exec rclone "${args[@]}"
fi
