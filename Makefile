# Build & Test
build:
	forge build

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
