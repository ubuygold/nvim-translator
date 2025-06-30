-- plugin/translator.lua
vim.api.nvim_create_user_command(
  "Translate",
  function()
    require("nvim-translator").translate()
  end,
  { range = true }
)

