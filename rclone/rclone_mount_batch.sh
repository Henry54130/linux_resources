#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="$script_dir/.env"

if [[ -f "$env_file" ]]; then
  set -a
  . "$env_file"
  set +a
fi

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [REMOTE...]

Batch mount rclone remotes under a common base directory.

Options:
  --daemon        Run mounts in the background and verify status (default)
  --foreground    Run mounts supervised in the foreground until interrupted
  -h, --help      Display this help message and exit

Arguments:
  REMOTE...       Optional list of remotes to mount. If omitted, mounts remotes
                  from RCLONE_BATCH_REMOTES in .env or all remotes from 'rclone listremotes'.
EOF
}

# 1. 參數解析與驗證
mode=""
cli_remotes=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --daemon)
      if [[ -n "$mode" && "$mode" != "daemon" ]]; then
        printf 'Error: Conflicting mode options.\n' >&2
        exit 2
      fi
      mode="daemon"
      shift
      ;;
    --foreground)
      if [[ -n "$mode" && "$mode" != "foreground" ]]; then
        printf 'Error: Conflicting mode options.\n' >&2
        exit 2
      fi
      mode="foreground"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    --)
      shift
      cli_remotes+=("$@")
      break
      ;;
    -*)
      printf 'Error: Unknown option %s\n' "$1" >&2
      show_help >&2
      exit 2
      ;;
    *)
      cli_remotes+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$mode" ]]; then
  mode="${RCLONE_BATCH_DEFAULT_MODE:-daemon}"
fi

if [[ "$mode" != "daemon" && "$mode" != "foreground" ]]; then
  printf 'Error: Invalid mode "%s". Must be "daemon" or "foreground".\n' "$mode" >&2
  exit 2
fi

# 2. 依賴檢查
for cmd in rclone mountpoint; do
  command -v "$cmd" >/dev/null 2>&1 || {
    printf 'Error: %s is required.\n' "$cmd" >&2
    exit 1
  }
done

fusermount_bin=""
if command -v fusermount3 >/dev/null 2>&1; then
  fusermount_bin="fusermount3"
elif command -v fusermount >/dev/null 2>&1; then
  fusermount_bin="fusermount"
else
  printf 'Error: fusermount3 or fusermount is required.\n' >&2
  exit 1
fi

# 3. 配置與環境變數驗證
base_dir="${RCLONE_BATCH_BASE_DIR:-${HOME}/rclone}"
mount_uid="${MOUNT_UID:-$(id -u)}"
mount_gid="${MOUNT_GID:-$(id -g)}"
mount_umask="${MOUNT_UMASK:-0022}"
vfs_cache_mode="${RCLONE_VFS_CACHE_MODE:-full}"
dir_cache_time="${RCLONE_DIR_CACHE_TIME:-10s}"
allow_other="${RCLONE_ALLOW_OTHER:-false}"
log_dir="${RCLONE_LOG_DIR:-/tmp/rclone-batch-mounts}"
mount_timeout="${RCLONE_MOUNT_TIMEOUT:-30}"

if [[ ! "$mount_uid" =~ ^[0-9]+$ ]]; then
  printf 'Error: Invalid MOUNT_UID: %s\n' "$mount_uid" >&2
  exit 1
fi
if [[ ! "$mount_gid" =~ ^[0-9]+$ ]]; then
  printf 'Error: Invalid MOUNT_GID: %s\n' "$mount_gid" >&2
  exit 1
fi
if [[ ! "$mount_timeout" =~ ^[0-9]+$ || "$mount_timeout" -le 0 ]]; then
  printf 'Error: Invalid RCLONE_MOUNT_TIMEOUT: %s (must be a positive integer)\n' "$mount_timeout" >&2
  exit 1
fi
mount_timeout=$((10#$mount_timeout))

# 4. 遠端清單獲取與驗證
raw_remotes=()
if [[ ${#cli_remotes[@]} -gt 0 ]]; then
  raw_remotes=("${cli_remotes[@]}")
elif [[ -n "${RCLONE_BATCH_REMOTES:-}" ]]; then
  # 支援多行或空白分隔之清單
  while IFS= read -r line || [[ -n "$line" ]]; do
    for token in $line; do
      [[ -n "$token" ]] && raw_remotes+=("$token")
    done
  done <<< "$RCLONE_BATCH_REMOTES"
else
  if ! remote_output="$(rclone listremotes 2>/dev/null)"; then
    printf 'Error: Failed to fetch remotes from rclone listremotes.\n' >&2
    exit 1
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] && raw_remotes+=("$line")
  done <<< "$remote_output"
fi

valid_remotes=()
declare -A seen_remotes=()

for r in "${raw_remotes[@]}"; do
  cleaned="${r%:}"
  [[ -z "$cleaned" ]] && continue

  if [[ ! "$cleaned" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    printf 'Warning: Skipping invalid remote name: %s\n' "$cleaned" >&2
    continue
  fi

  if [[ -n "${seen_remotes[$cleaned]:-}" ]]; then
    continue
  fi
  seen_remotes["$cleaned"]=1
  valid_remotes+=("$cleaned")
done

if [[ ${#valid_remotes[@]} -eq 0 ]]; then
  printf 'No valid remotes to mount.\n'
  exit 0
fi

# 5. 目錄安全檢查
if [[ -L "$base_dir" ]]; then
  printf 'Error: Base directory is a symbolic link: %s\n' "$base_dir" >&2
  exit 1
fi
if [[ -e "$base_dir" && ! -d "$base_dir" ]]; then
  printf 'Error: Base directory is not a directory: %s\n' "$base_dir" >&2
  exit 1
fi
if ! mkdir -p -- "$base_dir"; then
  printf 'Error: Failed to create base directory: %s\n' "$base_dir" >&2
  exit 1
fi

if [[ -L "$log_dir" ]]; then
  printf 'Error: Log directory is a symbolic link: %s\n' "$log_dir" >&2
  exit 1
fi
if [[ -e "$log_dir" && ! -d "$log_dir" ]]; then
  printf 'Error: Log directory is not a directory: %s\n' "$log_dir" >&2
  exit 1
fi
if ! ( umask 077 && mkdir -p -- "$log_dir" ); then
  printf 'Error: Failed to create log directory: %s\n' "$log_dir" >&2
  exit 1
fi
chmod 700 "$log_dir" 2>/dev/null || true

# 6. 建構掛載選項
mount_args=(mount
  --uid "$mount_uid" --gid "$mount_gid" --umask "$mount_umask"
  --vfs-cache-mode "$vfs_cache_mode" --dir-cache-time "$dir_cache_time"
)
if [[ "$allow_other" == "true" || "$allow_other" == "1" ]]; then
  mount_args+=(--allow-other)
fi

# 掛載啟動輔助函式：直接設定全域變數 last_child_pid，避免命令替換 subshell 卡住
last_child_pid=0
start_mount() {
  local remote="$1"
  local local_path="$2"
  local remote_log="$3"

  rclone "${mount_args[@]}" "$remote:" "$local_path" >>"$remote_log" 2>&1 </dev/null &
  last_child_pid=$!
  if [[ "$mode" == "foreground" ]]; then
    # Track the child as soon as it exists, before any startup wait can be
    # interrupted. The foreground signal handler can then always reap it.
    active_pids+=("$last_child_pid")
    active_targets+=("$local_path")
  fi

  local mounted=false
  for ((i = 0; i < mount_timeout; i++)); do
    if mountpoint -q "$local_path" && kill -0 "$last_child_pid" 2>/dev/null; then
      mounted=true
      break
    fi
    if ! kill -0 "$last_child_pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  if [[ "$mounted" == true ]]; then
    return 0
  else
    kill -TERM "$last_child_pid" 2>/dev/null || true
    sleep 0.2
    kill -KILL "$last_child_pid" 2>/dev/null || true
    wait "$last_child_pid" 2>/dev/null || true
    if mountpoint -q "$local_path"; then
      "$fusermount_bin" -u "$local_path" 2>/dev/null || true
    fi
    return 1
  fi
}

# 7. 模式執行
if [[ "$mode" == "daemon" ]]; then
  failed_count=0
  for remote in "${valid_remotes[@]}"; do
    local_path="$base_dir/$remote"
    if [[ -L "$local_path" ]]; then
      printf '[Failed] Target path is a symbolic link: %s\n' "$local_path" >&2
      failed_count=$((failed_count + 1))
      continue
    fi

    if mountpoint -q "$local_path"; then
      printf '[Skipped] Already mounted: %s\n' "$local_path"
      continue
    fi

    if ! mkdir -p -- "$local_path"; then
      printf '[Failed] Cannot create mount directory: %s\n' "$local_path" >&2
      failed_count=$((failed_count + 1))
      continue
    fi
    remote_log="$log_dir/${remote}.log"

    printf '[Mounting] %s -> %s\n' "$remote" "$local_path"
    if start_mount "$remote" "$local_path" "$remote_log"; then
      printf '[Success] %s mounted at %s (PID: %d)\n' "$remote" "$local_path" "$last_child_pid"
    else
      printf '[Failed] %s mount failed or timed out (%ds). See log: %s\n' "$remote" "$mount_timeout" "$remote_log" >&2
      failed_count=$((failed_count + 1))
    fi
  done

  if [[ "$failed_count" -gt 0 ]]; then
    printf 'Completed with %d failure(s).\n' "$failed_count" >&2
    exit 1
  fi
  printf 'All targeted remotes mounted successfully.\n'
  exit 0

elif [[ "$mode" == "foreground" ]]; then
  active_pids=()
  active_targets=()
  cleaned_up=false
  interrupted=false

  cleanup_foreground() {
    [[ "$cleaned_up" == true ]] && return 0
    cleaned_up=true
    trap - INT TERM EXIT
    set +e
    printf '\nStopping supervised mounts...\n'
    for pid in "${active_pids[@]}"; do
      kill -TERM "$pid" 2>/dev/null || true
    done
    for _ in {1..6}; do
      any_alive=false
      for pid in "${active_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
          any_alive=true
          break
        fi
      done
      [[ "$any_alive" == false ]] && break
      sleep 0.5
    done
    for pid in "${active_pids[@]}"; do
      kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    done
    for target in "${active_targets[@]}"; do
      if mountpoint -q "$target"; then
        "$fusermount_bin" -u "$target" 2>/dev/null || true
      fi
    done
    printf 'Cleanup complete.\n'
  }

  on_signal() {
    local sig="$1"
    interrupted=true
    cleanup_foreground
    trap - "$sig" EXIT
    kill -s "$sig" "$$"
  }

  # 在啟動循環前即註冊訊號 Trap，防止啟動中途被終止時留下孤兒掛載
  trap 'on_signal INT' INT
  trap 'on_signal TERM' TERM
  trap cleanup_foreground EXIT

  for remote in "${valid_remotes[@]}"; do
    local_path="$base_dir/$remote"
    if [[ -L "$local_path" ]]; then
      printf '[Failed] Target path is a symbolic link: %s\n' "$local_path" >&2
      cleanup_foreground
      exit 1
    fi

    if mountpoint -q "$local_path"; then
      printf '[Skipped] Already mounted: %s\n' "$local_path"
      continue
    fi

    if ! mkdir -p -- "$local_path"; then
      printf '[Failed] Cannot create mount directory: %s\n' "$local_path" >&2
      cleanup_foreground
      exit 1
    fi
    remote_log="$log_dir/${remote}.log"

    printf '[Mounting] %s -> %s\n' "$remote" "$local_path"
    if start_mount "$remote" "$local_path" "$remote_log"; then
      printf '[Success] %s mounted at %s (PID: %d)\n' "$remote" "$local_path" "$last_child_pid"
    else
      printf '[Failed] %s mount failed or timed out (%ds). See log: %s\n' "$remote" "$mount_timeout" "$remote_log" >&2
      cleanup_foreground
      exit 1
    fi
  done

  if [[ ${#active_pids[@]} -eq 0 ]]; then
    printf 'No new remotes to supervise (all remotes were already mounted).\n'
    exit 0
  fi

  printf 'All remotes mounted. Supervised in foreground (Ctrl+C to stop)...\n'

  status=0
  wait -n || status=$?

  if [[ "$interrupted" == true ]]; then
    exit 0
  fi

  if [[ "$status" -eq 130 || "$status" -eq 143 ]]; then
    cleanup_foreground
    exit 0
  fi

  printf 'A supervised mount process terminated unexpectedly (status: %d).\n' "$status"
  cleanup_foreground
  exit 1
fi
