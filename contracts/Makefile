# Include .env file if it exists
-include .env

.PHONY: all build test clean deploy-local deploy-sepolia deploy-polygon upgrade-sepolia upgrade-polygon

# Default target
all: build

# Build contracts
build:
	forge build

# Run tests
test:
	forge test

# Run tests with verbosity
test-v:
	forge test -vvv

# Run tests with gas report
test-gas:
	forge test --gas-report

# Clean build artifacts
clean:
	forge clean

# Format code
fmt:
	forge fmt

# Check formatting
fmt-check:
	forge fmt --check

# Generate gas snapshot
snapshot:
	forge snapshot

# Deploy to local Anvil
deploy-local:
	forge script script/DeployVault.s.sol:DeployVaultLocal --rpc-url $(RPC_URL_LOCAL) --broadcast

# Deploy to Sepolia testnet
deploy-sepolia:
	forge script script/DeployVault.s.sol:DeployVault \
		--rpc-url $(RPC_URL_SEPOLIA) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

# Deploy to Polygon mainnet
deploy-polygon:
	forge script script/DeployVault.s.sol:DeployVault \
		--rpc-url $(RPC_URL_POLYGON) \
		--broadcast \
		--verify \
		--etherscan-api-key $(POLYGONSCAN_API_KEY)

# Upgrade on Sepolia testnet
upgrade-sepolia:
	forge script script/UpgradeVault.s.sol:UpgradeVault \
		--rpc-url $(RPC_URL_SEPOLIA) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

# Upgrade on Polygon mainnet
upgrade-polygon:
	forge script script/UpgradeVault.s.sol:UpgradeVault \
		--rpc-url $(RPC_URL_POLYGON) \
		--broadcast \
		--verify \
		--etherscan-api-key $(POLYGONSCAN_API_KEY)

# Start local Anvil node
anvil:
	anvil

# Generate documentation
docs:
	forge doc

# Check contract sizes
sizes:
	forge build --sizes
