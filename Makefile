# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install:; forge install
update:; forge update

# Build & test
build  :; forge build
test   :; forge test
test-chamber-integration-mainnet-fork :; FOUNDRY_FUZZ_RUNS=5 forge test --match-path "./test/integration/Chamber/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
test-issuer-wizard-integration-mainnet-fork :; FOUNDRY_FUZZ_RUNS=5 forge test --match-path "./test/integration/IssuerWizard/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
test-rebalance-wizard-integration-mainnet-fork :; FOUNDRY_FUZZ_RUNS=5 forge test --match-path "./test/integration/RebalanceWizard/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
test-streaming-fee-wizard-integration-mainnet-fork :; FOUNDRY_FUZZ_RUNS=5 forge test --match-path "./test/integration/StreamingFeeWizard/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
test-audit-pocs-mainnet-fork :; FOUNDRY_FUZZ_RUNS=5 forge test --match-path "./test/audit/**/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
test-unit-mainnet-fork :; forge test --match-path "./test/unit/**/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
trace   :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fmt