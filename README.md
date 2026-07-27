# Prediction Master (futureWorldCorn)

A prediction market dApp on World Chain with CORN token, AMM-based betting, Chainlink oracles, and bicameral governance (TokenHouse + HumanHouse with World ID ZKP).

## Architecture

```
Phase 1 (MVP)
  CornToken (ERC20+Permit, 1B supply)
  PredictionMarket (UUPS upgradeable, AMM betting, fees, resolution, claims)
  OracleAdapter (Chainlink feed + push resolution)

Phase 2 (Governance)
  GovCrownToken (ERC20Votes wrapper for CORN)
  TimelockController (governance execution)
  TokenHouse (OZ Governor, token-weighted voting)

Phase 3 (Human Verification)
  HumanHouse (World ID ZKP one-person-one-vote dispute resolution)
```

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (forge, cast, anvil)
- Node.js 18+ and npm

### Build & Test

```bash
# Compile contracts
forge build

# Run all tests (53 tests, zero external RPC needed)
forge test -vvv
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:5173

## Contract Deployment

See [DEPLOY.md](./DEPLOY.md) for full deployment guide.

### Phase 1 (MVP)

```bash
forge script script/Deploy.s.sol \
  --rpc-url <RPC_URL> \
  --broadcast --verify
```

### Phase 2 (Governance + Timelock)

```bash
forge script script/DeployPhase2.s.sol \
  --rpc-url <RPC_URL> \
  --broadcast
```

### Phase 3 (TokenHouse + HumanHouse)

```bash
forge script script/DeployPhase3.s.sol \
  --rpc-url <RPC_URL> \
  --broadcast
```

## Project Structure

```
src/
  CornToken.sol           # ERC20 + Permit + Ownable + burn + lockMint
  PredictionMarket.sol     # UUPS upgradeable, AMM betting
  OracleAdapter.sol        # Chainlink oracle integration
  GovCrownToken.sol        # ERC20Votes wrapper for governance
  TokenHouse.sol           # OZ Governor (token-weighted)
  HumanHouse.sol           # World ID ZKP dispute resolution
  interfaces/              # IWorldID, IPredictionMarket
  libraries/               # ByteHasher

script/
  Deploy.s.sol             # Phase 1 deploy
  DeployPhase2.s.sol       # Phase 2: GovCrownToken + Timelock
  DeployPhase3.s.sol       # Phase 3: TokenHouse + HumanHouse
  TransferToTimelock.s.sol # Alternative Phase 2 (no GovCrownToken)

test/
  *.t.sol                  # Unit tests
  integration/             # Integration + deployment dry-run tests
  mocks/                   # MockWorldIdRouter

frontend/
  src/
    pages/                 # MarketList, MarketDetail, CreateMarket, Portfolio, Delegate, Governance, HumanHouse
    hooks/                 # useToken, useMarket, useGovernance, useHumanHouse
    contracts/abi.ts       # Contract ABIs and addresses
```

## Testing

All 53 tests run with zero external RPC dependency:

```bash
forge test
```

| Suite | Tests | Coverage |
|-------|-------|----------|
| CornToken.t.sol | 10 | mint, burn, permit, lockMint |
| PredictionMarket.t.sol | 11 | create, bet, resolve, claim, fees |
| PredictionMarketUpgrade.t.sol | 4 | UUPS proxy, upgrade, storage |
| OracleAdapter.t.sol | 3 | Chainlink feed, push resolution |
| GovCrownToken.t.sol | 6 | wrap/unwrap, delegation, votes |
| HumanHouse.t.sol | 13 | dispute, vote, execute, World ID |
| PredictionMarketIntegration.t.sol | 2 | full flow, oracle resolution |
| GovernanceIntegration.t.sol | 3 | propose->vote->queue->execute |
| DeployDryRun.t.sol | 1 | deployment dry-run |

## Tech Stack

- **Smart Contracts:** Solidity 0.8.26, OpenZeppelin v5, Foundry
- **Oracle:** Chainlink AggregatorV3Interface
- **Identity:** World ID v3 (ZKP via Semaphore)
- **Frontend:** React 18, wagmi v2, viem, RainbowKit, Vite
- **Chain:** World Chain (chain ID 480 mainnet / 4801 Sepolia)
