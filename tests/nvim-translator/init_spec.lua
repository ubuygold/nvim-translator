-- tests/nvim-translator/init_spec.lua
local translator = require("nvim-translator")

describe("nvim-translator", function()
  local original_getpos, original_buf_get_text, original_create_buf, original_open_win
  local original_notify, original_set_keymap, original_schedule, original_snacks_win
  local mock_text_lines = {}
  local notifications = {}
  local keymaps = {}

  before_each(function()
    -- Reset state
    mock_text_lines = {}
    notifications = {}
    keymaps = {}

    -- Mock vim.fn.getpos
    original_getpos = vim.fn.getpos
    vim.fn.getpos = function(mark)
      if mark == "'<" then
        return { 0, 1, 1, 0 } -- Start position
      elseif mark == "'>" then
        return { 0, 1, 10, 0 } -- End position
      end
      return {0,0,0,0}
    end

    -- Mock vim.api.nvim_buf_get_text
    original_buf_get_text = vim.api.nvim_buf_get_text
    vim.api.nvim_buf_get_text = function(buffer, start_row, start_col, end_row, end_col, opts)
      return mock_text_lines
    end

    -- Mock vim.api.nvim_create_buf
    original_create_buf = vim.api.nvim_create_buf
    vim.api.nvim_create_buf = function(listed, scratch)
      return 1 -- Return mock buffer ID
    end

    -- Mock vim.api.nvim_open_win
    original_open_win = vim.api.nvim_open_win
    vim.api.nvim_open_win = function(buffer, enter, config)
      return 1 -- Return mock window ID
    end

    -- Mock snacks.win to prevent module not found error
    original_snacks_win = package.loaded["snacks.win"]
    package.loaded["snacks.win"] = function(opts) end

    -- Mock vim.notify
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    -- Mock vim.api.nvim_set_keymap
    original_set_keymap = vim.api.nvim_set_keymap
    vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
      table.insert(keymaps, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
    end

    -- Mock vim.schedule
    original_schedule = vim.schedule
    vim.schedule = function(fn)
      fn() -- Execute immediately
    end

    -- Mock vim.api.nvim_get_option
    vim.api.nvim_get_option = function(name)
      if name == "columns" then
        return 80
      elseif name == "lines" then
        return 24
      end
    end
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.getpos = original_getpos
    vim.api.nvim_buf_get_text = original_buf_get_text
    vim.api.nvim_create_buf = original_create_buf
    vim.api.nvim_open_win = original_open_win
    vim.notify = original_notify
    vim.api.nvim_set_keymap = original_set_keymap
    vim.schedule = original_schedule
    package.loaded["snacks.win"] = original_snacks_win
  end)

  describe("setup", function()
    it("should setup with default configuration", function()
      translator.setup()
      assert.are.equal(1, #keymaps)
    end)
  end)

  describe("translate", function()
    before_each(function()
      translator.setup()
    end)

    it("should handle paragraph translation", function()
      mock_text_lines = { "Paragraph one.", "", "Paragraph two." }
      
      local client = require("nvim-translator.client")
      local original_translate = client.translate
      local captured_text = ""

      client.translate = function(text, source_lang, target_lang, callback)
        captured_text = text
        callback("Translated text", false)
      end

      translator.translate()

      assert.are.equal("Paragraph one.\n\nParagraph two.", captured_text)

      client.translate = original_translate
    end)

    it("should show warning on partial failure", function()
      mock_text_lines = { "Paragraph one." }

      local client = require("nvim-translator.client")
      local original_translate = client.translate

      client.translate = function(text, source_lang, target_lang, callback)
        callback("Translated text", true) -- has_errors = true
      end

      translator.translate()

      assert.are.equal(1, #notifications)
      assert.is_true(string.find(notifications[1].msg, "Some paragraphs could not be translated") ~= nil)

      client.translate = original_translate
    end)
  end)
end)
