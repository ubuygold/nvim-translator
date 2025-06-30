-- tests/integration_spec.lua
-- Integration testing: Testing the complete translation workflow

describe("nvim-translator integration", function()
  local translator = require("nvim-translator")
  local config = require("nvim-translator.config")
  local client = require("nvim-translator.client")
  
  local original_jobstart, original_notify, original_schedule
  local original_getpos, original_buf_get_lines, original_create_buf, original_open_win
  local job_callbacks = {}
  local notifications = {}
  local popup_content = ""

  before_each(function()
    -- Reset state
    job_callbacks = {}
    notifications = {}
    popup_content = ""

    -- Reset configuration state
    local config = require("nvim-translator.config")
    config.opts = {}
    
    -- Mock vim.fn.jobstart
    original_jobstart = vim.fn.jobstart
    vim.fn.jobstart = function(command, opts)
      local job_id = 1
      job_callbacks[job_id] = opts
      return job_id
    end

    -- Mock vim.notify
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, {msg = msg, level = level})
    end

    -- Mock vim.schedule
    original_schedule = vim.schedule
    vim.schedule = function(fn)
      fn()
    end

    -- Mock selection-related APIs
    original_getpos = vim.fn.getpos
    vim.fn.getpos = function(mark)
      if mark == "'<" then
        return {0, 1, 1, 0}
      elseif mark == "'>" then
        return {0, 1, 5, 0}
      end
    end

    original_buf_get_lines = vim.api.nvim_buf_get_lines
    vim.api.nvim_buf_get_lines = function(buffer, start, end_line, strict_indexing)
      return {"Hello"}
    end

    -- Mock popup-related APIs
    original_create_buf = vim.api.nvim_create_buf
    vim.api.nvim_create_buf = function(listed, scratch)
      return 1
    end

    original_open_win = vim.api.nvim_open_win
    vim.api.nvim_open_win = function(buffer, enter, config)
      return 1
    end

    vim.api.nvim_buf_set_lines = function(buffer, start, end_line, strict_indexing, replacement)
      popup_content = table.concat(replacement, "\n")
    end

    vim.api.nvim_get_option = function(name)
      if name == "columns" then return 80
      elseif name == "lines" then return 24
      end
    end
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.jobstart = original_jobstart
    vim.notify = original_notify
    vim.schedule = original_schedule
    vim.fn.getpos = original_getpos
    vim.api.nvim_buf_get_lines = original_buf_get_lines
    vim.api.nvim_create_buf = original_create_buf
    vim.api.nvim_open_win = original_open_win
  end)

  describe("complete translation workflow", function()
    it("should translate text successfully with default config", function()
      -- Setup plugin
      translator.setup()
      
      -- Execute translation
      translator.translate()
      
      -- Verify HTTP request was sent
      assert.is_not_nil(job_callbacks[1])
      
      -- Simulate successful API response
      local mock_response = {
        code = 200,
        data = "你好"
      }
      
      local opts = job_callbacks[1]
      opts.on_stdout(1, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(1, 0, "exit")
      
      -- Verify translation result displayed in popup
      assert.are.equal("你好", popup_content)
      assert.are.equal(0, #notifications)  -- No error notifications
    end)

    it("should handle translation with custom config", function()
      -- Use custom configuration
      translator.setup({
        source_lang = "en",
        target_lang = "fr",
        keymap = "<leader>tr"
      })
      
      translator.translate()
      
      -- Verify request was sent
      assert.is_not_nil(job_callbacks[1])
      
      -- Simulate French translation response
      local mock_response = {
        code = 200,
        data = "Bonjour"
      }
      
      local opts = job_callbacks[1]
      opts.on_stdout(1, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(1, 0, "exit")
      
      assert.are.equal("Bonjour", popup_content)
    end)

    it("should handle API error gracefully", function()
      translator.setup()
      translator.translate()
      
      -- Simulate API error response
      local mock_response = {
        code = 400,
        message = "Bad request"
      }
      
      local opts = job_callbacks[1]
      opts.on_stdout(1, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(1, 0, "exit")
      
      -- Verify error notifications (two expected: one from client, one from translate function)
      assert.are.equal(2, #notifications)
      -- First notification from client.lua
      assert.is_true(string.find(notifications[1].msg, "Bad request") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
      -- Second notification from translate() function
      assert.is_true(string.find(notifications[2].msg, "Translation failed") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, notifications[2].level)
      assert.are.equal("", popup_content)  -- No content displayed in popup
    end)

    it("should handle network error", function()
      translator.setup()
      translator.translate()
      
      -- Simulate network error (curl command failure)
      local opts = job_callbacks[1]
      opts.on_exit(1, 1, "exit")  -- Non-zero exit code
      
      -- Verify error notifications (two expected: one from client, one from translate function)
      assert.are.equal(2, #notifications)
      -- First notification from client.lua
      assert.is_true(string.find(notifications[1].msg, "Exit code: 1") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
      -- Second notification from translate() function
      assert.is_true(string.find(notifications[2].msg, "Translation failed") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, notifications[2].level)
    end)

    it("should handle empty selection", function()
      translator.setup()
      
      -- Simulate empty selection
      vim.api.nvim_buf_get_lines = function(buffer, start, end_line, strict_indexing)
        return {}
      end
      
      translator.translate()
      
      -- Verify warning notification
      assert.are.equal(1, #notifications)
      assert.are.equal("No text selected", notifications[1].msg)
      assert.are.equal(vim.log.levels.WARN, notifications[1].level)
      
      -- Verify no HTTP request was sent
      assert.is_nil(next(job_callbacks))
    end)

    it("should handle multi-line text translation", function()
      translator.setup()
      
      -- Simulate multi-line selection
      vim.fn.getpos = function(mark)
        if mark == "'<" then
          return {0, 1, 1, 0}
        elseif mark == "'>" then
          return {0, 3, 5, 0}
        end
      end
      
      vim.api.nvim_buf_get_lines = function(buffer, start, end_line, strict_indexing)
        return {"Hello", "world", "test"}
      end
      
      translator.translate()
      
      -- Verify request was sent
      assert.is_not_nil(job_callbacks[1])
      
      -- Simulate translation response for multi-line text
      local mock_response = {
        code = 200,
        data = "你好\n世界\n测试"
      }
      
      local opts = job_callbacks[1]
      opts.on_stdout(1, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(1, 0, "exit")
      
      assert.are.equal("你好\n世界\n测试", popup_content)
    end)

    it("should handle partial JSON responses", function()
      translator.setup()
      translator.translate()
      
      -- Simulate chunked JSON response
      local mock_response = {
        code = 200,
        data = "你好世界"
      }
      local json_str = vim.fn.json_encode(mock_response)
      local mid = math.floor(#json_str / 2)
      
      local opts = job_callbacks[1]
      opts.on_stdout(1, {string.sub(json_str, 1, mid)}, "stdout")
      opts.on_stdout(1, {string.sub(json_str, mid + 1)}, "stdout")
      opts.on_exit(1, 0, "exit")
      
      assert.are.equal("你好世界", popup_content)
    end)
  end)

  describe("configuration integration", function()
    it("should use fallback config when not initialized", function()
      -- Skip setup and translate directly
      translator.translate()
      
      -- Verify request was sent (using default config)
      assert.is_not_nil(job_callbacks[1])
      
      local mock_response = {
        code = 200,
        data = "你好"
      }
      
      local opts = job_callbacks[1]
      opts.on_stdout(1, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(1, 0, "exit")
      
      assert.are.equal("你好", popup_content)
    end)
  end)
end)
