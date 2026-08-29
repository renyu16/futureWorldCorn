#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: run as root (sudo ./install-node.sh)" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl not found" >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  MAJOR="$(node -v | sed 's/v//; s/\..*//')"
  if [[ "$MAJOR" -ge 18 ]]; then
    echo "node already installed: $(node -v)"
    exit 0
  fi
  echo "node too old: $(node -v), upgrading..."
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "error: unsupported package manager (only RHEL-family with dnf supported)" >&2
  exit 1
fi

# 1) 优先系统 dnf 模块（RHEL9 系自带 nodejs 20 模块）
if dnf module enable -y nodejs:20 2>/dev/null && dnf -y install nodejs 2>/dev/null; then
  hash -r
  if node -v 2>/dev/null | grep -qE '^v(1[89]|[2-9][0-9])\.'; then
    node -v
    exit 0
  fi
fi

# 2) NodeSource 20（失败不中断）
if curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - 2>/dev/null; then
  dnf -y install nodejs
fi

hash -r
node -v