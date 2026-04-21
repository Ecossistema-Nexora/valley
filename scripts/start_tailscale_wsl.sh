#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
SYSTEMD_SOCKET_PATH="/run/tailscale/tailscaled.sock"
FALLBACK_SOCKET_PATH="/var/run/tailscale/tailscaled.sock"
STATE_PATH="/var/lib/tailscale/tailscaled.state"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source /dev/stdin <<<"$(tr -d '\r' < "$ENV_FILE")"
  set +a
fi

HOSTNAME_VALUE="${VALLEY_TAILSCALE_WSL_HOSTNAME:-valley-wsl2}"
WSL_USER_VALUE="${VALLEY_TAILSCALE_WSL_USER:-eretazan}"
AUTH_KEY_VALUE="${TAILSCALE_AUTHKEY:-${TS_AUTHKEY:-}}"
AUTH_ARG=()
if [[ -n "$AUTH_KEY_VALUE" ]]; then
  AUTH_ARG+=("--authkey=${AUTH_KEY_VALUE}")
fi
SSH_ARG=()
if [[ "${VALLEY_TAILSCALE_SSH:-true}" == "true" ]]; then
  SSH_ARG+=("--ssh")
fi

ensure_package() {
  local package="$1"
  if ! dpkg -s "$package" >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y "$package"
  fi
}

wait_for_tailscale() {
  local socket_path="$1"
  local attempt=0
  while (( attempt < 30 )); do
    if [[ -S "$socket_path" ]] && tailscale --socket="$socket_path" status >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done
  return 1
}

if ! command -v tailscale >/dev/null 2>&1; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
  else
    echo "curl nao encontrado no WSL. Instale tailscale manualmente ou instale curl." >&2
    exit 2
  fi
fi

mkdir -p "$(dirname "$SYSTEMD_SOCKET_PATH")" "$(dirname "$STATE_PATH")"
SOCKET_PATH="$SYSTEMD_SOCKET_PATH"

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files tailscaled.service >/dev/null 2>&1; then
  pkill -f 'tailscaled --socket=/var/run/tailscale/tailscaled.sock' >/dev/null 2>&1 || true
  rm -f "$FALLBACK_SOCKET_PATH" "$SYSTEMD_SOCKET_PATH"
  systemctl reset-failed tailscaled >/dev/null 2>&1 || true
  systemctl enable tailscaled >/dev/null 2>&1 || true
  systemctl start tailscaled
  wait_for_tailscale "$SYSTEMD_SOCKET_PATH" || true
fi

if ! tailscale --socket="$SOCKET_PATH" status >/dev/null 2>&1; then
  SOCKET_PATH="$FALLBACK_SOCKET_PATH"
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files tailscaled.service >/dev/null 2>&1; then
    systemctl stop tailscaled >/dev/null 2>&1 || true
    systemctl reset-failed tailscaled >/dev/null 2>&1 || true
  fi
  mkdir -p "$(dirname "$SOCKET_PATH")"
  rm -f "$SOCKET_PATH"
  pkill -x tailscaled >/dev/null 2>&1 || true
  nohup tailscaled --socket="$SOCKET_PATH" --state="$STATE_PATH" >/tmp/tailscaled.log 2>&1 &
  if ! wait_for_tailscale "$SOCKET_PATH"; then
    echo "tailscaled nao ficou pronto no WSL." >&2
    exit 1
  fi
fi

ensure_package openssh-server

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files ssh.service >/dev/null 2>&1; then
  systemctl enable ssh >/dev/null 2>&1 || true
  systemctl restart ssh
elif command -v service >/dev/null 2>&1; then
  service ssh restart
else
  mkdir -p /var/run/sshd
  /usr/sbin/sshd
fi

tailscale --socket="$SOCKET_PATH" up --hostname "$HOSTNAME_VALUE" --accept-routes "${SSH_ARG[@]}" "${AUTH_ARG[@]}"
tailscale --socket="$SOCKET_PATH" ip -4
echo "wsl_user=${WSL_USER_VALUE}"
ss -lntp | grep ':22 ' || true
