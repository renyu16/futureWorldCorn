# Build & Test
build:
	forge build

# 本地测试：纯 anvil 执行，零外部 RPC 依赖（一条命令全量运行全部合约测试）
# 覆盖：PredictionMarket / CornToken / GovCrownToken / OracleAdapter / HumanHouse
#       + 集成：GovernanceIntegration（治理委托骨架）/ DeployDryRun（Timelock 所有权转移）
test:
	forge test -vvv

test-gas:
	forge test --gas-report

# Deploy (requires .env with DEPLOYER_PRIVATE_KEY)
deploy-sepolia:
	forge script script/Deploy.s.sol \
		--rpc-url https://worldchain-sepolia.g.alchemy.com/public \
		--broadcast \
		--verify

deploy-mainnet:
	forge script script/Deploy.s.sol \
		--rpc-url https://worldchain-mainnet.g.alchemy.com/public \
		--broadcast \
		--verify

# Frontend
frontend-install:
	cd frontend && npm install

frontend-dev:
	cd frontend && npm run dev

frontend-build:
	cd frontend && npm run build

# Clean
clean:
	forge clean
	rm -rf frontend/node_modules frontend/dist
