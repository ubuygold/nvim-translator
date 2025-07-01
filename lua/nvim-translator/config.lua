-- lua/nvim-translator/config.lua
local M = {}

M.default_config = {
  api_url = "https://deeplx.vercel.app/translate",
  source_lang = "auto",
  target_lang = "EN",
  keymap = "<leader>lt", -- Add default keymap
}

M.opts = {}

function M.setup(opts)
  -- Copy default configuration first
  M.opts = vim.deepcopy(M.default_config)

  -- Process options if provided
  if opts then
    for key, value in pairs(opts) do
      M.opts[key] = value
    end
  end
end

return M
