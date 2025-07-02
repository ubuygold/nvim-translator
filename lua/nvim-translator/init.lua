-- lua/nvim-translator/init.lua
local M = {}

local config = require("nvim-translator.config")
local client = require("nvim-translator.client")

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  -- getpos returns [bufnum, lnum, col, off]
  -- nvim_buf_get_text expects {row, col} where row and col are 0-indexed
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  local lines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
  return table.concat(lines, "\n")
end

local function show_translation(text)
  -- Split the text into a list of lines, which is more robust for buffer content
  local lines = vim.split(text or "", "\n")

  -- Use snacks.win to replace manual window management
  require("snacks.win")({
    text = lines, -- Use the 'text' field as per snacks.win documentation
    title = "Translation Result",
    title_pos = "center",
    border = "rounded",
    width = 0.8,
    height = 0.8,
  })
end -- 修复：移除多余的 '}'，并添加 'end' 来正确关闭函数

function M.translate(opts)
  local config = require("nvim-translator.config")
  -- Ensure configuration is initialized
  if vim.tbl_isempty(config.opts) then
    config.setup({})
  end
  local selection = get_visual_selection()
  if selection == "" then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  client.translate(selection, config.opts.source_lang, config.opts.target_lang, function(translated_text, has_errors)
    if has_errors then
      vim.notify("Some paragraphs could not be translated and were left in their original form.", vim.log.levels.WARN)
    end
    if translated_text then
      vim.schedule(function()
        show_translation(translated_text)
      end)
    end
  end)
end

-- New function to select a language and then translate
function M.select_language_and_translate(opts)
  local ok, picker = pcall(require, "snacks.picker")
  if not ok then
    vim.notify("This feature requires 'folke/snacks.nvim'.", vim.log.levels.ERROR)
    return
  end

  local selection = get_visual_selection()
  if selection == "" then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  local config = require("nvim-translator.config")
  -- Ensure configuration is initialized
  if vim.tbl_isempty(config.opts) then
    config.setup({})
  end

  picker({
    items = config.opts.languages,
    title = "Select Target Language",
    preview = false,
    layout = "select",
    format = "text",
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      local target_lang = item.code
      client.translate(selection, config.opts.source_lang, target_lang, function(translated_text, has_errors)
        if has_errors then
          vim.notify("Some paragraphs could not be translated and were left in their original form.", vim.log.levels.WARN)
        end
        if translated_text then
          vim.schedule(function()
            show_translation(translated_text)
          end)
        end
      end)
    end,
  })
end

function M.setup(opts)
  config.setup(opts)

  -- Create the user commands
  vim.api.nvim_create_user_command("Translate", M.translate, { range = true })
  vim.api.nvim_create_user_command("TranslateTo", M.select_language_and_translate, { range = true })

  -- Setup keymap for direct translation
  local keymap = config.opts.keymap
  if keymap and keymap ~= false then
    vim.api.nvim_set_keymap("v", keymap, ":Translate<CR>", { noremap = true, silent = true })
  end

  -- Setup keymap for translation with language selection
  local keymap_to = config.opts.keymap_to
  if keymap_to and keymap_to ~= false then
    vim.api.nvim_set_keymap("v", keymap_to, ":TranslateTo<CR>", { noremap = true, silent = true })
  end
end

return M
