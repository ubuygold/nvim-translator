-- tests/minimal_init.lua
-- Minimal Neovim init configuration for test environment

-- Set standard paths for test environment
vim.env.LAZY_STDPATH = ".tests"

-- Set basic Neovim options
vim.opt.runtimepath:prepend(".")
vim.opt.packpath:prepend(".")

-- Add current directory to Lua path
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/lua/?.lua"
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/lua/?/init.lua"

-- Set basic vim options
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false

-- Ensure plenary is available (for testing)
local function ensure_plenary()
  local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
  if not vim.loop.fs_stat(plenary_path) then
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

-- Load our plugin
require("nvim-translator")
