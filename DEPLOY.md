# Deployment Guide — Prediction Master to World Chain Sepolia

## Prerequisites

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify:

```bash
forge --version
cast --version
anvil --version
```

### 2. Get World Chain Sepolia Test ETH

- Visit the World Chain faucet at https://worldchain-sepolia-faucet.alchemy.com
- Paste your wallet address and request test ETH
- Verify balance with:

```bash
cast balance --rpc-url https://worldchain-sepolia.g.alchemy.com/public <YOUR_ADDRESS>
```

### 3. Set Up `.env`

Copy the example and fill in:

```bash
cp .env.example .env
```

Required vars in `.env`:

```
DEPLOYER_PRIVATE_KEY=0x...
FEE_COLLECTOR=0x...
KEEPER=0x...
```

- `DEPLOYER_PRIVATE_KEY` — the private key funding deployment (must have test ETH)
- `FEE_COLLECTOR` — address that collects protocol fees (defaults to deployer if omitted)
- `KEEPER` — address allowed to resolve markets via the OracleAdapter (defaults to deployer if omitted)

## Deployment Steps

### Step 1 — Verify contracts compile

```bash
forge build
```

Expected output:

```
[⠊] Compiling...
[⠒] Compiling 35 files with Solc 0.8.26
[⠑] Solc 0.8.26 finished in 2.34s
Compiler run successful!
```

### Step 2 — Run tests

```bash
forge test -vvv
```

All tests should pass. Expected output:

```
[⠊] Compiling...
[⠒] Compiling 35 files with Solc 0.8.26
[⠑] Solc 0.8.26 finished in 2.34s
Ran 6 tests for test/PredictionMarket.t.sol
[PASS]
...
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 12.34ms
```

### Step 3 — Deploy

```bash
forge script script/Deploy.s.sol \
  --rpc-url https://worldchain-sepolia.g.alchemy.com/public \
  --broadcast \
  --verify
```

The `--verify` flag will auto-verify on Worldscan after deployment.

Example output:

```
== Logs ==

==========================

Chain 4801

Estimated total gas used: 3123456

===================
=== Deployments ===
=================

CornToken deployed at: 0x1234567890abcdef1234567890abcdef12345678
PredictionMarket (proxy) deployed at: 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
OracleAdapter deployed at: 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef

Transactions saved to: broadcast/Deploy.s.sol/4801/run-latest.json
```

### Step 4 — Verify on Worldscan

If `--verify` was used in step 3, verification happens automatically. Otherwise:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/CornToken.sol:CornToken \
  --chain 4801 \
  --rpc-url https://worldchain-sepolia.g.alchemy.com/public
```

Repeat for `PredictionMarket` and `OracleAdapter`.

### Step 5 — Record addresses

Note the three deployed addresses from the deploy output:

| Contract           | Address                                      |
|--------------------|----------------------------------------------|
| CornToken          | `0x1234567890abcdef1234567890abcdef12345678` |
| PredictionMarket   | `0xabcdefabcdefabcdefabcdefabcdefabcdefabcd` |
| OracleAdapter      | `0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef` |

Update `frontend/src/contracts/addresses.ts` with the real addresses.

## After Deployment — Frontend Integration

### 1. Update contract addresses

Edit `frontend/src/contracts/addresses.ts` and replace `0x...` placeholders under `chainId: 4801` with the deployed addresses.

### 2. Start the frontend

```bash
cd frontend
npm install
npm run dev
```

### 3. Connect wallet

- Open http://localhost:5173
- Connect using RainbowKit (World Chain Sepolia network)
- If the network isn't in your wallet automatically, add:

  - **Network Name:** World Chain Sepolia
  - **RPC URL:** https://worldchain-sepolia.g.alchemy.com/public
  - **Chain ID:** 4801
  - **Currency Symbol:** ETH
  - **Block Explorer:** https://sepolia.worldscan.org

### 4. Test the full flow

1. Approve CORN token spending for the PredictionMarket contract
2. Create a market (connected wallet must be the contract owner) — or test as a user by betting on an existing market
3. Place a YES or NO bet
4. After the deadline, call `resolveMarket` (keeper role)
5. Claim rewards from winning positions

## Mainnet Deployment

When ready for mainnet (World Chain mainnet, chain ID 480):

1. Update `.env` with mainnet deployer key (ensure adequate ETH for gas)
2. Use the mainnet RPC: `https://worldchain-mainnet.g.alchemy.com/public`
3. Update `frontend/src/contracts/addresses.ts` under `chainId: 480`
4. Switch your wallet to World Chain mainnet

## Useful Cast Commands

```bash
# Check deployed contract bytecode (confirms deployment)
cast code <CONTRACT_ADDRESS> --rpc-url https://worldchain-sepolia.g.alchemy.com/public

# Call a read function
cast call <CONTRACT_ADDRESS> "totalSupply()(uint256)" \
  --rpc-url https://worldchain-sepolia.g.alchemy.com/public

# Send a tx (e.g. transfer CORN)
cast send <TOKEN_ADDRESS> "transfer(address,uint256)" \
  <TO> <AMOUNT> \
  --rpc-url https://worldchain-sepolia.g.alchemy.com/public \
  --private-key <KEY>
```
