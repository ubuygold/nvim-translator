# Makefile for nvim-translator

# Test related variables
TESTS_INIT = tests/minimal_init.lua
TESTS_DIR = tests/

# Default target
.PHONY: all
all: test

# Run all tests
.PHONY: test
test:
	@echo "Running nvim-translator tests..."
	@nvim --headless --noplugin -u $(TESTS_INIT) -c "lua require('tests.run_tests')" -c "qa!"

# Run specific test files
.PHONY: test-config
test-config:
	@echo "Running config tests..."
	@nvim --headless --noplugin -u $(TESTS_INIT) -c "lua require('plenary.test_harness').test_file('tests/nvim-translator/config_spec.lua')" -c "qa!"

.PHONY: test-client
test-client:
	@echo "Running client tests..."
	@nvim --headless --noplugin -u $(TESTS_INIT) -c "lua require('plenary.test_harness').test_file('tests/nvim-translator/client_spec.lua')" -c "qa!"

.PHONY: test-init
test-init:
	@echo "Running init tests..."
	@nvim --headless --noplugin -u $(TESTS_INIT) -c "lua require('plenary.test_harness').test_file('tests/nvim-translator/init_spec.lua')" -c "qa!"

.PHONY: test-integration
test-integration:
	@echo "Running integration tests..."
	@nvim --headless --noplugin -u $(TESTS_INIT) -c "lua require('plenary.test_harness').test_file('tests/integration_spec.lua')" -c "qa!"

# Clean test environment
.PHONY: clean
clean:
	@echo "Cleaning test environment..."
	@rm -rf .tests

# Install test dependencies
.PHONY: deps
deps:
	@echo "Installing test dependencies..."
	@mkdir -p .tests/lazy
	@if [ ! -d ".tests/lazy/plenary.nvim" ]; then \
		git clone --depth=1 https://github.com/nvim-lua/plenary.nvim.git .tests/lazy/plenary.nvim; \
	fi

# Check code style (if stylua is available)
.PHONY: lint
lint:
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Running stylua..."; \
		stylua --check lua/ tests/; \
	else \
		echo "stylua not found, skipping lint"; \
	fi

# Format code
.PHONY: format
format:
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Formatting with stylua..."; \
		stylua lua/ tests/; \
	else \
		echo "stylua not found, skipping format"; \
	fi

# Display help information
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  test           - Run all tests"
	@echo "  test-config    - Run config module tests"
	@echo "  test-client    - Run client module tests"
	@echo "  test-init      - Run init module tests"
	@echo "  test-integration - Run integration tests"
	@echo "  deps           - Install test dependencies"
	@echo "  clean          - Clean test environment"
	@echo "  lint           - Check code style"
	@echo "  format         - Format code"
	@echo "  help           - Show this help"
