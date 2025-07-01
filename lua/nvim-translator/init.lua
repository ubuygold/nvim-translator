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
  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")
  local win_width = math.floor(width * 0.8)
  local win_height = math.floor(height * 0.8)
  local row = math.floor((height - win_height) / 2)
  local col = math.floor((width - win_width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)

  -- Split text by newline characters into an array of lines
  local lines = vim.split(text or "", "\n")
  if vim.tbl_isempty(lines) then
    lines = { "" }
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, true, win_opts)
end

function M.translate()
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

  client.translate(selection, config.opts.source_lang, config.opts.target_lang, function(translated_text, err)
    if err then
      vim.notify("Translation failed: " .. err, vim.log.levels.ERROR)
      return
    end
    if translated_text then
      vim.schedule(function()
        show_translation(translated_text)
      end)
    end
  end)
end

function M.setup(opts)
  config.setup(opts)

  -- Get keymap setting from configuration
  local keymap = config.opts.keymap
  if keymap and keymap ~= false then
    vim.api.nvim_set_keymap("v", keymap, ":Translate<CR>", { noremap = true, silent = true })
  end
end

return M
