-include .env

# deps
update:; forge update
build  :; forge build
size  :; forge build --sizes

# storage inspection
inspect :; forge inspect ${contract} storage-layout --pretty

# if we want to run only matching tests, set that here
test := test_

# Declare PHONY targets
.PHONY: update build size inspect test trace gas test-contract test-contract-gas trace-contract test-test test-test-trace trace-test snapshot snapshot-diff trace-setup trace-max coverage coverage-report coverage-debug clean format format-check deploy coverage-html

test :; forge test -vv
trace :; forge test -vvv
gas :; forge test --gas-report
test-contract :; forge test -vv --match-contract $(contract)
test-contract-gas :; forge test --gas-report --match-contract ${contract}
trace-contract :; forge test -vvv --match-contract $(contract)
test-test :; forge test -vv --match-test $(test)
test-test-trace :; forge test -vvv --match-test $(test)
trace-test :; forge test -vvvvv --match-test $(test)
snapshot :; forge snapshot -vv
snapshot-diff :; forge snapshot --diff -vv
trace-setup :; forge test -vvvv
trace-max :; forge test -vvvvv
coverage :; forge coverage
coverage-report :; forge coverage --report lcov
coverage-debug :; forge coverage --report debug

clean :; forge clean
format :; forge fmt
format-check :; forge fmt --check
deploy :; forge script script/Deploy.s.sol --slow --multi --private-key ${PRIVATE_KEY} --broadcast --verify --verifier-api-key ${ETHERSCAN_API_KEY}

coverage-html:
	@echo "Running coverage..."
	forge build;\
	forge coverage --report lcov
	@echo "Analyzing..."
	lcov --remove lcov.info 'script/*' 'src/WrappedToken.sol' --output-file lcov.info; \
	genhtml -o coverage-report lcov.info;
	@echo "Coverage report generated at coverage-report/index.html"
