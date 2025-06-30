-- lua/nvim-translator/init.lua
local M = {}

local config = require("nvim-translator.config")
local client = require("nvim-translator.client")

local function get_visual_selection()
  local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  if #lines == 0 then
    return ""
  end
  if #lines == 1 then
    return string.sub(lines[1], start_col, end_col)
  else
    local first_line = string.sub(lines[1], start_col)
    local last_line = string.sub(lines[#lines], 1, end_col)
    local middle_lines = {}
    if #lines > 2 then
      for i = 2, #lines - 1 do
        table.insert(middle_lines, lines[i])
      end
    end
    table.insert(middle_lines, 1, first_line)
    table.insert(middle_lines, last_line)
    return table.concat(middle_lines, "\n")
  end
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
  local lines = {}
  if text then
    for line in text:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    -- If text is empty or contains only line breaks, add at least one empty line
    if #lines == 0 then
      lines = {""}
    end
  else
    lines = {""}
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
    vim.api.nvim_set_keymap(
      "v",
      keymap,
      ":Translate<CR>",
      { noremap = true, silent = true }
    )
  end
end

return M
