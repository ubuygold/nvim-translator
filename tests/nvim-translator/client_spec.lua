-- tests/nvim-translator/client_spec.lua
local client = require("nvim-translator.client")
local config = require("nvim-translator.config")

describe("nvim-translator.client", function()
  local original_jobstart
  local job_callbacks = {}
  local job_id_counter = 1

  before_each(function()
    -- Reset configuration
    config.setup({
      source_lang = "auto",
      target_lang = "zh"
    })
    
    -- Mock vim.fn.jobstart
    original_jobstart = vim.fn.jobstart
    job_callbacks = {}
    job_id_counter = 1
    
    vim.fn.jobstart = function(command, opts)
      local job_id = job_id_counter
      job_id_counter = job_id_counter + 1
      job_callbacks[job_id] = { command = command, opts = opts }
      return job_id
    end
  end)

  after_each(function()
    -- Restore original function
    vim.fn.jobstart = original_jobstart
  end)

  describe("pre-flight checks", function()
    it("should notify and callback with error if curl is not executable", function()
      -- Mock vim.fn.executable to simulate curl not being found
      local original_executable = vim.fn.executable
      vim.fn.executable = function(cmd)
        if cmd == "curl" then return 0 end
        return 1
      end

      -- Mock vim.notify
      local original_notify = vim.notify
      local notifications = {}
      vim.notify = function(msg, level)
        table.insert(notifications, {msg = msg, level = level})
      end

      local callback_called = false
      local callback_error = nil
      client.translate("test", "", "", function(result, err)
        callback_called = true
        callback_error = err
      end)

      assert.is_true(callback_called)
      assert.is_not_nil(callback_error)
      assert.are.equal(1, #notifications)
      assert.is_true(string.find(notifications[1].msg, "curl` is not installed") ~= nil)

      -- Restore mocks
      vim.fn.executable = original_executable
      vim.notify = original_notify
    end)
  end)

  describe("translate", function()
    it("should use the api_url from config", function()
      config.setup({ api_url = "https://my.custom.api/translate" })

      client.translate("Hello", "en", "fr", function() end)

      assert.is_not_nil(job_callbacks[1])
      local command_table = job_callbacks[1].command
      local url_found = false
      for _, part in ipairs(command_table) do
        if part == "https://my.custom.api/translate" then
          url_found = true
          break
        end
      end
      assert.is_true(url_found, "Custom API URL was not used in the command")
    end)

    it("should use default config when parameters are empty", function()
      local callback_called = false
      local callback_result = nil
      local callback_error = nil

      client.translate("Hello", "", "", function(result, err)
        callback_called = true
        callback_result = result
        callback_error = err
      end)

      -- Verify jobstart was called
      assert.is_true(next(job_callbacks) ~= nil)
      
      local job_id = next(job_callbacks)
      local opts = job_callbacks[job_id].opts
      
      -- Simulate successful response
      local mock_response = {
        code = 200,
        data = "你好"
      }
      
      opts.on_stdout(job_id, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(job_id, 0, "exit")
      
      assert.is_true(callback_called)
      assert.are.equal("你好", callback_result)
      assert.is_nil(callback_error)
    end)

    it("should use provided parameters", function()
      local callback_called = false
      
      client.translate("Hello", "en", "fr", function(result, err)
        callback_called = true
      end)

      -- Verify jobstart was called
      assert.is_true(next(job_callbacks) ~= nil)
      
      -- Here we mainly verify the function was called, actual parameter validation requires more complex mocking
      local job_id = next(job_callbacks)
      local opts = job_callbacks[job_id].opts
      
      -- Simulate successful response
      local mock_response = {
        code = 200,
        data = "Bonjour"
      }
      
      opts.on_stdout(job_id, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(job_id, 0, "exit")
      
      assert.is_true(callback_called)
    end)

    it("should handle API error response", function()
      local callback_called = false
      local callback_result = nil
      local callback_error = nil

      client.translate("Hello", "en", "zh", function(result, err)
        callback_called = true
        callback_result = result
        callback_error = err
      end)

      local job_id = next(job_callbacks)
      local opts = job_callbacks[job_id].opts
      
      -- Simulate API error response
      local mock_response = {
        code = 400,
        message = "Invalid request"
      }
      
      opts.on_stdout(job_id, {vim.fn.json_encode(mock_response)}, "stdout")
      opts.on_exit(job_id, 0, "exit")
      
      assert.is_true(callback_called)
      assert.is_nil(callback_result)
      assert.is_not_nil(callback_error)
      assert.is_true(string.find(callback_error, "Invalid request") ~= nil)
    end)

    it("should handle curl command failure", function()
      local callback_called = false
      local callback_result = nil
      local callback_error = nil

      client.translate("Hello", "en", "zh", function(result, err)
        callback_called = true
        callback_result = result
        callback_error = err
      end)

      local job_id = next(job_callbacks)
      local opts = job_callbacks[job_id].opts
      
      -- Simulate curl command failure
      opts.on_exit(job_id, 1, "exit")
      
      assert.is_true(callback_called)
      assert.is_nil(callback_result)
      assert.are.equal("API request failed", callback_error)
    end)

    it("should handle invalid JSON response", function()
      local callback_called = false
      local callback_result = nil
      local callback_error = nil

      client.translate("Hello", "en", "zh", function(result, err)
        callback_called = true
        callback_result = result
        callback_error = err
      end)

      local job_id = next(job_callbacks)
      local opts = job_callbacks[job_id].opts
      
      -- Simulate invalid JSON response
      opts.on_stdout(job_id, {"invalid json"}, "stdout")
      opts.on_exit(job_id, 0, "exit")
      
      assert.is_true(callback_called)
      assert.is_nil(callback_result)
      assert.is_not_nil(callback_error)
    end)

    it("should handle multiple stdout chunks", function()
      local callback_called = false
      local callback_result = nil

      client.translate("Hello", "en", "zh", function(result, err)
        callback_called = true
        callback_result = result
      end)

      local job_id = next(job_callbacks)
      local opts = job_callbacks[job_id].opts
      
      -- Simulate chunked response
      local mock_response = {
        code = 200,
        data = "你好"
      }
      local json_str = vim.fn.json_encode(mock_response)
      local mid = math.floor(#json_str / 2)
      
      opts.on_stdout(job_id, {string.sub(json_str, 1, mid)}, "stdout")
      opts.on_stdout(job_id, {string.sub(json_str, mid + 1)}, "stdout")
      opts.on_exit(job_id, 0, "exit")
      
      assert.is_true(callback_called)
      assert.are.equal("你好", callback_result)
    end)
  end)
end)
