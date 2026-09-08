@echo off
REM WalletConnect v2 E2E: run the auto wallet in the background.
REM Usage: run_e2e.cmd <wc-uri>   (E2E_TIMEOUT=120 or leave unset for persistent)
setlocal
set "URI=%~1"
if "%URI%"=="" (echo usage: run_e2e.cmd wc:...& exit /b 1)
if not defined WC_DEV_PK set "WC_DEV_PK=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
if not defined E2E_TIMEOUT set "E2E_TIMEOUT=0"
cd /d "%~dp0"
node test_e2e.js "%URI%" > e2e.log 2> e2e.err.log