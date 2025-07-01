-- tests/integration_spec.lua
-- Integration testing: Testing the complete translation workflow

describe("nvim-translator integration", function()
  local translator = require("nvim-translator")
  local config = require("nvim-translator.config")
  local client = require("nvim-translator.client")

  local original_jobstart, original_notify, original_schedule
  local original_getpos, original_buf_get_text, original_create_buf, original_open_win
  local job_callbacks = {}
  local notifications = {}
  local popup_content = ""
  local job_id_counter

  before_each(function()
    -- Reset state
    job_callbacks = {}
    notifications = {}
    popup_content = ""
    job_id_counter = 0

    -- Reset configuration state
    local config_module = require("nvim-translator.config")
    config_module.opts = {}

    -- Mock vim.fn.jobstart
    original_jobstart = vim.fn.jobstart
    vim.fn.jobstart = function(command, opts)
      job_id_counter = job_id_counter + 1
      job_callbacks[job_id_counter] = opts
      return job_id_counter
    end

    -- Mock vim.notify
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
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
        return { 0, 1, 1, 0 }
      elseif mark == ">'" then
        return { 0, 3, 1, 0 } -- 3 lines
      end
      return {0,0,0,0}
    end

    original_buf_get_text = vim.api.nvim_buf_get_text
    vim.api.nvim_buf_get_text = function(buffer, start_row, start_col, end_row, end_col, opts)
      return { "First paragraph.", "", "Second paragraph." }
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
      if name == "columns" then
        return 80
      elseif name == "lines" then
        return 24
      end
    end
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.jobstart = original_jobstart
    vim.notify = original_notify
    vim.schedule = original_schedule
    vim.fn.getpos = original_getpos
    vim.api.nvim_buf_get_text = original_buf_get_text
    vim.api.nvim_create_buf = original_create_buf
    vim.api.nvim_open_win = original_open_win
  end)

  describe("complete translation workflow", function()
    it("should translate paragraphs successfully", function()
      translator.setup()
      translator.translate()

      assert.are.equal(2, #job_callbacks) -- Two paragraphs

      -- Simulate successful API responses
      local res1 = { code = 200, data = "Premier paragraphe." }
      local res2 = { code = 200, data = "Second paragraphe." }

      job_callbacks[1].on_stdout(1, { vim.fn.json_encode(res1) }, "stdout")
      job_callbacks[1].on_exit(1, 0, "exit")

      job_callbacks[2].on_stdout(2, { vim.fn.json_encode(res2) }, "stdout")
      job_callbacks[2].on_exit(2, 0, "exit")

      assert.are.equal("Premier paragraphe.\n\nSecond paragraphe.", popup_content)
      assert.are.equal(0, #notifications)
    end)

    it("should handle partial failure", function()
      translator.setup()
      translator.translate()

      assert.are.equal(2, #job_callbacks)

      -- First paragraph succeeds
      local res1 = { code = 200, data = "Premier paragraphe." }
      job_callbacks[1].on_stdout(1, { vim.fn.json_encode(res1) }, "stdout")
      job_callbacks[1].on_exit(1, 0, "exit")

      -- Second paragraph fails
      job_callbacks[2].on_exit(2, 1, "exit") -- Network error

      assert.are.equal("Premier paragraphe.\n\nSecond paragraph.", popup_content)
      assert.are.equal(1, #notifications)
      assert.is_true(string.find(notifications[1].msg, "Some paragraphs could not be translated") ~= nil)
    end)
  end)
end)
