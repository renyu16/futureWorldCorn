#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

pid_alive_for_web() {
  local pid="$1"
  [[ -f .pid ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ "$(ps -p "$pid" -o comm= 2>/dev/null)" == node* ]] || return 1
}

if pid_alive_for_web "$(cat .pid 2>/dev/null)"; then
  kill "$(cat .pid)"
  sleep 1
  if pid_alive_for_web "$(cat .pid 2>/dev/null)"; then
    kill -9 "$(cat .pid)" 2>/dev/null || true
  fi
  rm -f .pid
  echo "stopped"
else
  if [[ -f .pid ]]; then
    rm -f .pid
    echo "stale pid removed"
  else
    echo "not running"
  fi
fi