# Phase 1 end-to-end smoke test on World Chain Sepolia (4801)
# Roles:
#   deployer (0xbaD8)  -> owner + keeper: createMarket, bet YES, pushResult, claim
#   ai_dev_b (0xaf07) -> bettor NO: bet NO, claim (should fail - loser)
#   ai_dev_a (0xDeF213) -> feeCollector (passive, receives fee)
#
# Flow: transfer CORN -> approve -> createMarket -> bet(YES) -> bet(NO) -> wait deadline -> resolve -> claim(winner) -> claim(loser revert)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$env:FOUNDRY_DISABLE_NIGHTLY_WARNING = '1'

# --- config ---
$rpc = 'https://worldchain-sepolia.g.alchemy.com/public'
$corn = '0x6a07C7b64702E67f32d14f55F26dAAc94082B981'
$market = '0xAecA3704114B03d2d85f6EC5C4df83b277A657bb'
$adapter = '0x617CEC12C21b4D4Def72afAd7858E7596e83dc82'

$deployerKey = '0x179a0e3c2b3d9710eee2a566a77a3f7157b81b6e07c95da0a8fbbd0e738ef507'
$deployer = '0xbaD893B052C669eAFB1CD96b8C30C8f99e1b9D80'
$aiDevBKey = '0xab6f206624bf8576886c194044deee7c8868e1146cc9992ebeed9732f310774a'
$aiDevB = '0xaf073172AfC69CE12d2CF3E1A3D00a0489D1A0C2'
$feeCollector = '0xDeF213DFeB1D3d09158E64C31d8e32fF0484033f'

$betAmount = '100000000000000000000'   # 100 CORN (1e18)
$fundAmount = '100000000000000000000'  # 100 CORN to ai_dev_b for betting

Add-Type -AssemblyName System.Numerics
function Big($s) { return [System.Numerics.BigInteger]::Parse($s) }

function Cast-Call($target, $sig, $argsList) {
    $a = @('call', $target, $sig, '--rpc-url', $rpc)
    if ($argsList) { $a += $argsList }
    $raw = & .\bin\cast.exe @a 2>&1
    # cast returns "value [formatted]" - take first token before space
    $first = ($raw -split '\s+')[0]
    return $first
}

function Cast-Send($target, $sig, $key, $argsList) {
    $a = @('send', $target, $sig, '--private-key', $key, '--rpc-url', $rpc)
    if ($argsList) { $a += $argsList }
    $raw = & .\bin\cast.exe @a 2>&1 | Out-String
    $hash = ($raw | Select-String 'transactionHash\s+(\S+)').Matches.Groups[1].Value
    return $hash
}

function Step($n, $msg) { Write-Output ('' + "`n" + '========== Step ' + $n + ': ' + $msg + ' ==========') }

# --- Step 0: Fund ai_dev_b with ETH for gas ---
Step 0 "fund ai_dev_b with 0.005 ETH for gas"
$ethB = & .\bin\cast.exe balance $aiDevB --rpc-url $rpc 2>&1
Write-Output "ai_dev_b ETH: $ethB"
if ((Big $ethB) -lt (Big '5000000000000000')) {
    $txRaw = & .\bin\cast.exe send $aiDevB --value 5000000000000000 --private-key $deployerKey --rpc-url $rpc 2>&1 | Out-String
    $txHash = ($txRaw | Select-String 'transactionHash\s+(\S+)').Matches.Groups[1].Value
    Write-Output "ETH transfer tx: $txHash"
} else {
    Write-Output "already has ETH, skip"
}
$ethB2 = & .\bin\cast.exe balance $aiDevB --rpc-url $rpc 2>&1
Write-Output "ai_dev_b ETH after: $ethB2"
if ((Big $ethB2) -lt (Big '5000000000000000')) { throw "ETH fund failed: $ethB2" }

# --- Step 1: Fund ai_dev_b with CORN (skip if already funded) ---
Step 1 "fund ai_dev_b with 100 CORN"
$bBefore = Cast-Call $corn "balanceOf(address)(uint256)" @($aiDevB)
Write-Output "ai_dev_b CORN before: $bBefore"
if ((Big $bBefore) -ge (Big $fundAmount)) {
    Write-Output "already funded, skip"
} else {
    $tx = Cast-Send $corn "transfer(address,uint256)" $deployerKey @($aiDevB, $fundAmount)
    Write-Output "transfer tx: $tx"
}
$bAfter = Cast-Call $corn "balanceOf(address)(uint256)" @($aiDevB)
Write-Output "ai_dev_b CORN after: $bAfter"
if ((Big $bAfter) -lt (Big $fundAmount)) { throw "fund failed: $bAfter" }

# --- Step 2: ai_dev_b approve market ---
Step 2 "ai_dev_b approve market"
$tx = Cast-Send $corn "approve(address,uint256)" $aiDevBKey @($market, $betAmount)
Write-Output "approve tx: $tx"
$allow = Cast-Call $corn "allowance(address,address)(uint256)" @($aiDevB, $market)
Write-Output "allowance(ai_dev_b, market): $allow"
if ((Big $allow) -lt (Big $betAmount)) { throw "approve failed: $allow" }

# --- Step 3: createMarket (deployer as owner) ---
Step 3 "createMarket"
$mcBefore = Cast-Call $market "marketCount()(uint256)"
Write-Output "marketCount before: $mcBefore"
$deadline = [uint64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) + 90   # now + 90s
$question = "Smoke: ETH above 1000 USD?"
$tx = Cast-Send $market "createMarket(string,uint40,uint16)" $deployerKey @($question, $deadline.ToString(), '200')
Write-Output "createMarket tx: $tx"
$mcAfter = Cast-Call $market "marketCount()(uint256)"
Write-Output "marketCount after: $mcAfter"
$marketId = [uint64]$mcAfter   # createMarket does marketCount++ then uses it, so id == marketCount
Write-Output "marketId: $marketId"
if ([uint64]$mcAfter -ne ([uint64]$mcBefore + 1)) { throw "marketCount not incremented" }

# --- Step 4: deployer bet YES ---
Step 4 "deployer bet YES 100 CORN"
$allowD = Cast-Call $corn "allowance(address,address)(uint256)" @($deployer, $market)
Write-Output "deployer allowance: $allowD"
if ((Big $allowD) -lt (Big $betAmount)) {
    $tx = Cast-Send $corn "approve(address,uint256)" $deployerKey @($market, $betAmount)
    Write-Output "deployer approve tx: $tx"
}
# YES = 0
$tx = Cast-Send $market "bet(uint256,uint8,uint256)" $deployerKey @($marketId.ToString(), '0', $betAmount)
Write-Output "bet YES tx: $tx"
$sy = Cast-Call $market "sharesYes(uint256,address)(uint256)" @($marketId.ToString(), $deployer)
Write-Output "sharesYes(deployer): $sy"
if ((Big $sy) -ne (Big $betAmount)) { throw "sharesYes mismatch: $sy" }

# --- Step 5: ai_dev_b bet NO ---
Step 5 "ai_dev_b bet NO 100 CORN"
# NO = 1
$tx = Cast-Send $market "bet(uint256,uint8,uint256)" $aiDevBKey @($marketId.ToString(), '1', $betAmount)
Write-Output "bet NO tx: $tx"
$sn = Cast-Call $market "sharesNo(uint256,address)(uint256)" @($marketId.ToString(), $aiDevB)
Write-Output "sharesNo(ai_dev_b): $sn"
if ((Big $sn) -ne (Big $betAmount)) { throw "sharesNo mismatch: $sn" }

# --- Step 6: wait for deadline ---
Step 6 "wait 95s for deadline to pass"
Start-Sleep -Seconds 95

# --- Step 7: resolve via OracleAdapter.pushResult (YES wins = true) ---
Step 7 "resolve market (YES wins)"
$tx = Cast-Send $adapter "pushResult(uint256,bool)" $deployerKey @($marketId.ToString(), 'true')
Write-Output "pushResult tx: $tx"
# status: 0=Open,1=Resolved,2=... check
$status = Cast-Call $market "markets(uint256)" @($marketId.ToString())
Write-Output "market struct: $status"

# --- Step 8: winner (deployer) claim ---
Step 8 "deployer (winner) claim"
$dBefore = Cast-Call $corn "balanceOf(address)(uint256)" @($deployer)
Write-Output "deployer CORN before claim: $dBefore"
$tx = Cast-Send $market "claimReward(uint256)" $deployerKey @($marketId.ToString())
Write-Output "claim tx: $tx"
$claimedD = Cast-Call $market "claimed(uint256,address)(bool)" @($marketId.ToString(), $deployer)
Write-Output "claimed(deployer): $claimedD"
if ($claimedD -ne 'true') { throw "deployer claim failed" }
$dAfter = Cast-Call $corn "balanceOf(address)(uint256)" @($deployer)
Write-Output "deployer CORN after claim: $dAfter"

# --- Step 9: loser (ai_dev_b) claim should revert ---
Step 9 "ai_dev_b (loser) claim - expect revert"
try {
    $tx = Cast-Send $market "claimReward(uint256)" $aiDevBKey @($marketId.ToString())
    Write-Output "UNEXPECTED: loser claim succeeded: $tx"
    throw "loser claim should have reverted"
} catch {
    $msg = $_.Exception.Message
    $short = $msg.Substring(0, [Math]::Min(120, $msg.Length))
    Write-Output "EXPECTED: loser claim reverted ($short)"
}

# --- Step 10: feeCollector balance check ---
Step 10 "feeCollector balance check"
$fcBal = Cast-Call $corn "balanceOf(address)(uint256)" @($feeCollector)
Write-Output "feeCollector CORN balance: $fcBal"

Write-Output ('' + "`n" + '========== SMOKE TEST PASSED ==========')
