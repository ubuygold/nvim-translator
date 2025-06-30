#!/usr/bin/env -S nvim -l

-- tests/run_tests.lua
-- Test runner script

-- Ensure plenary is available
local function ensure_plenary()
  local plenary_path = ".tests/lazy/plenary.nvim"
  if not vim.loop.fs_stat(plenary_path) then
    print("Installing plenary.nvim...")
    vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/nvim-lua/plenary.nvim.git",
      plenary_path,
    })
  end
  vim.opt.runtimepath:prepend(plenary_path)
end

ensure_plenary()

-- Load minimal init configuration
dofile("tests/minimal_init.lua")

-- Run all tests
local plenary_test = require("plenary.test_harness")

-- Set test directory
local test_dir = vim.fn.getcwd() .. "/tests"

print("Running nvim-translator tests...")
print("Test directory: " .. test_dir)

-- Run tests
local success = plenary_test.test_directory(test_dir, {
  minimal_init = "tests/minimal_init.lua",
  sequential = true,
})

-- Exit with appropriate exit code
if success then
  print("All tests passed!")
  vim.cmd("qa! 0")
else
  print("Some tests failed!")
  vim.cmd("qa! 1")
end
