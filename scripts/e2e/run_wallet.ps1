# WalletConnect v2 E2E wallet-side automation (World Chain Sepolia 4801)
#
# Usage:  powershell -File scripts/e2e/run_wallet.ps1 [-Uri "wc:..."] [-Persist] [-TimeoutSec 120]
#
# Behavior:
#   1. If -Uri given: pair with dApp, auto-approve proposal, then sit listening.
#      If URI not given and session keys persist on disk: resumes listening to saved session.
#   2. On session_request eth_sendTransaction: sign with WC_DEV_PK, broadcast, respond txHash.
#   3. Default: persistent listener (never times out). Set -TimeoutSec to force a cap.
#   4. Writes logs to scripts/e2e/e2e.log and e2e.err.log. Exit codes: 0=tx ok, 1=pair fail, 3=approve fail, 4=timeout.
$ErrorActionPreference = 'Stop'
param(
    [string]$Uri = '',
    [int]$TimeoutSec = 0,
    [switch]$Persist
)

$root = Split-Path -Parent $PSScriptRoot
$e2eDir = $root   # scripts/e2e
if (-not $env:WC_DEV_PK) {
    $env:WC_DEV_PK = '0x' + 'a' * 64
}
$env:E2E_TIMEOUT = if ($Persist -or $TimeoutSec -le 0) { '0' } else { "$TimeoutSec" }

# Use a persistent storage dir so session keys survive process restarts.
New-Item -ItemType Directory -Path "$e2eDir\.storage" -Force | Out-Null
$env:WD_KEYVAL_STORAGE_DIR = "$e2eDir\.storage"

$args = @('node', "$e2eDir\test_e2e.js")
if ($Uri) { $args += $Uri }

$stdout = "$e2eDir\e2e.log"
$stderr = "$e2eDir\e2e.err.log"

Write-Output "Starting e2e wallet (persist=$($Persist.IsPresent), timeout=$TimeoutSec) uri=$Uri"
& node --version
# Launch detached so this shell returns; logs stream to files.
$p = Start-Process -FilePath 'node.exe' -ArgumentList ($args | ForEach-Object { "`"$_`"" }) `
    -WorkingDirectory $e2eDir -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru
Write-Output "PID=$($p.Id)  log=$stdout  err=$stderr"
Write-Output "NOTE: run without -NoNewWindow detach issues on PS5; use run_e2e.cmd for true background."
Write-Output "Tail log with:  Get-Content -Wait $stdout"