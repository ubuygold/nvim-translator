-- tests/nvim-translator/init_spec.lua
local translator = require("nvim-translator")

describe("nvim-translator", function()
  local original_getpos, original_buf_get_text, original_create_buf, original_open_win
  local original_notify, original_set_keymap, original_schedule
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
  end)

  describe("setup", function()
    it("should setup with default configuration", function()
      translator.setup()

      -- Verify default keymap is set
      assert.are.equal(1, #keymaps)
      assert.are.equal("v", keymaps[1].mode)
      assert.are.equal("<leader>lt", keymaps[1].lhs)
      assert.are.equal(":Translate<CR>", keymaps[1].rhs)
    end)

    it("should setup with custom keymap", function()
      translator.setup({
        keymap = "<leader>tr",
      })

      assert.are.equal(1, #keymaps)
      assert.are.equal("<leader>tr", keymaps[1].lhs)
    end)

    it("should not set keymap when keymap is false", function()
      translator.setup({
        keymap = false,
      })

      -- Verify no keymap is set
      assert.are.equal(0, #keymaps)
    end)
  end)

  describe("translate", function()
    before_each(function()
      -- Setup default configuration
      translator.setup()
    end)

    it("should notify when no text is selected", function()
      mock_text_lines = {} -- Empty selection

      translator.translate()

      assert.are.equal(1, #notifications)
      assert.are.equal("No text selected", notifications[1].msg)
      assert.are.equal(vim.log.levels.WARN, notifications[1].level)
    end)

    it("should handle single line selection", function()
      mock_text_lines = { "Hello worl" }

      -- Mock successful client translation
      local client = require("nvim-translator.client")
      local original_translate = client.translate
      client.translate = function(text, source_lang, target_lang, callback)
        assert.are.equal("Hello worl", text) -- Based on the mocked position from getpos
        callback("你好世界")
      end

      translator.translate()

      -- Restore original function
      client.translate = original_translate
    end)

    it("should handle multi-line selection", function()
      mock_text_lines = { "Hello", "world", "test" }

      -- Adjust getpos to mock multi-line selection
      vim.fn.getpos = function(mark)
        if mark == "'<" then
          return { 0, 1, 1, 0 } -- Start of the first line
        elseif mark == "'>" then
          return { 0, 3, 4, 0 } -- End of the third line
        end
      end

      local client = require("nvim-translator.client")
      local original_translate = client.translate
      local captured_text = ""

      client.translate = function(text, source_lang, target_lang, callback)
        captured_text = text
        callback("翻译结果")
      end

      translator.translate()

      -- Verify multi-line text is correctly concatenated
      assert.are.equal("Hello\nworld\ntest", captured_text)

      client.translate = original_translate
    end)

    it("should handle translation error", function()
      mock_text_lines = { "Hello" }

      local client = require("nvim-translator.client")
      local original_translate = client.translate

      client.translate = function(text, source_lang, target_lang, callback)
        callback(nil, "Translation failed")
      end

      translator.translate()

      assert.are.equal(1, #notifications)
      assert.is_true(string.find(notifications[1].msg, "Translation failed") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, notifications[1].level)

      client.translate = original_translate
    end)

    it("should show translation result in popup", function()
      mock_text_lines = { "Hello" }

      local client = require("nvim-translator.client")
      local original_translate = client.translate
      local original_buf_set_lines = vim.api.nvim_buf_set_lines
      local popup_content = ""

      vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
        popup_content = table.concat(replacement, "\n")
      end

      client.translate = function(text, source_lang, target_lang, callback)
        callback("你好")
      end

      translator.translate()

      assert.are.equal("你好", popup_content)

      -- Restore original function
      client.translate = original_translate
      vim.api.nvim_buf_set_lines = original_buf_set_lines
    end)

    it("should handle multi-line translation result", function()
      mock_text_lines = {"Hello"}

      local client = require("nvim-translator.client")
      local original_translate = client.translate
      local original_buf_set_lines = vim.api.nvim_buf_set_lines
      local popup_content = ""

      vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
        popup_content = table.concat(replacement, "\n")
      end

      client.translate = function(text, source_lang, target_lang, callback)
        callback("你好\n世界\n测试")  -- 多行翻译结果
      end

      translator.translate()

      assert.are.equal("你好\n世界\n测试", popup_content)

      -- 恢复原始函数
      client.translate = original_translate
      vim.api.nvim_buf_set_lines = original_buf_set_lines
    end)
  end)
end)
