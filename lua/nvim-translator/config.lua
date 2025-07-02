-- lua/nvim-translator/config.lua
local M = {}

M.default_config = {
  api_url = "https://deeplx.vercel.app/translate",
  source_lang = "auto",
  target_lang = "EN",
  keymap = "<leader>lt", -- Default keymap for direct translation
  keymap_to = "<leader>lT", -- Keymap for translating to a selected language
  -- List of languages for the picker
  languages = {
    { code = "EN", name = "English", text = "English (EN)" },
    { code = "ZH", name = "Chinese", text = "Chinese (ZH)" },
    { code = "DE", name = "German", text = "German (DE)" },
    { code = "FR", name = "French", text = "French (FR)" },
    { code = "ES", name = "Spanish", text = "Spanish (ES)" },
    { code = "JA", name = "Japanese", text = "Japanese (JA)" },
    { code = "KO", name = "Korean", text = "Korean (KO)" },
    { code = "RU", name = "Russian", text = "Russian (RU)" },
    { code = "IT", name = "Italian", text = "Italian (IT)" },
    { code = "PT", name = "Portuguese", text = "Portuguese (PT)" },
    -- You can add more languages here
  },
}

M.opts = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", vim.deepcopy(M.default_config), opts or {})
end

return M
