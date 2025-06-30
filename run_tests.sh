#!/bin/bash

# run_tests.sh - Test runner script

set -e

echo "Setting up test environment..."

# Create test directory
mkdir -p .tests/lazy

# Install plenary.nvim if it doesn't exist
if [ ! -d ".tests/lazy/plenary.nvim" ]; then
    echo "Installing plenary.nvim..."
    git clone --depth=1 https://github.com/nvim-lua/plenary.nvim.git .tests/lazy/plenary.nvim
fi

echo "Running tests..."

# Run all tests
nvim --headless --noplugin -u tests/minimal_init.lua \
    -c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init = 'tests/minimal_init.lua', sequential = true})" \
    -c "qa!"

echo "Tests completed!"
