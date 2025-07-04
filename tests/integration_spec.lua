-- tests/integration_spec.lua
-- Integration testing: Testing the complete translation workflow

describe("nvim-translator integration", function()
  local translator = require("nvim-translator")
  local config = require("nvim-translator.config")
  local client = require("nvim-translator.client")

  local original_jobstart, original_notify, original_schedule, original_chansend, original_chanclose
  local original_getpos, original_buf_get_text, original_snacks_win, original_snacks_picker
  local job_callbacks = {}
  local notifications = {}
  local snacks_win_opts = {} -- To capture snacks.win options
  local snacks_picker_opts = {} -- To capture snacks.picker options
  local job_id_counter

  before_each(function()
    -- Reset state
    job_callbacks = {}
    notifications = {}
    snacks_win_opts = {}
    snacks_picker_opts = {}
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

    -- Mock channel functions
    original_chansend = vim.fn.chansend
    vim.fn.chansend = function(id, data) end

    original_chanclose = vim.fn.chanclose
    vim.fn.chanclose = function(id, stream) end

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
      elseif mark == "'>" then -- 修正了这里，从 ">'" 改为 "'>"
        return { 0, 3, 1, 0 } -- 3 lines
      end
      return {0,0,0,0}
    end

    original_buf_get_text = vim.api.nvim_buf_get_text
    vim.api.nvim_buf_get_text = function(buffer, start_row, start_col, end_row, end_col, opts)
      return { "First paragraph.", "", "Second paragraph." }
    end

    -- Mock snacks.win
    original_snacks_win = package.loaded["snacks.win"]
    package.loaded["snacks.win"] = function(opts)
      snacks_win_opts = opts
    end

    -- Mock snacks.picker
    original_snacks_picker = package.loaded["snacks.picker"]
    package.loaded["snacks.picker"] = function(opts)
      snacks_picker_opts = opts
    end

    vim.api.nvim_get_option = function(name)
      if name == "columns" then
        return 80
      elseif name == "lines" then
        return 24
      end
    end

    vim.bo = { filetype = "lua" } -- Mock the filetype
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.jobstart = original_jobstart
    vim.notify = original_notify
    vim.schedule = original_schedule
    vim.fn.getpos = original_getpos
    vim.api.nvim_buf_get_text = original_buf_get_text
    -- Restore snacks.win and snacks.picker
    package.loaded["snacks.win"] = original_snacks_win
    package.loaded["snacks.picker"] = original_snacks_picker
    vim.fn.chansend = original_chansend
    vim.fn.chanclose = original_chanclose
    vim.bo = nil -- Cleanup the mock
  end)

  describe("complete translation workflow", function()
    it("should translate a single chunk successfully", function()
      -- Arrange
      translator.setup() -- Uses default max_chunk_size, so text becomes one chunk

      -- Act
      translator.translate()

      -- Assert
      assert.are.equal(1, #job_callbacks, "Expected 1 API call for a single chunk")

      -- Simulate successful API response
      local res = { code = 200, data = "Premier paragraphe.\n\nSecond paragraphe." }
      job_callbacks[1].on_stdout(1, { vim.fn.json_encode(res) }, "stdout")
      job_callbacks[1].on_exit(1, 0, "exit")

      assert.are.same({ "Premier paragraphe.", "", "Second paragraphe." }, snacks_win_opts.text)
      assert.are.equal(0, #notifications)
    end)

    it("should handle multiple chunks and partial failure", function()
      -- Arrange
      translator.setup({ max_chunk_size = 20 }) -- Force two chunks
      vim.api.nvim_buf_get_text = function()
        return { "Good chunk.", "", "Bad chunk." }
      end

      -- Act
      translator.translate()

      -- Assert
      assert.are.equal(2, #job_callbacks, "Expected 2 API calls for two chunks")

      -- First chunk succeeds
      local res1 = { code = 200, data = "Translated: Good chunk." }
      job_callbacks[1].on_stdout(1, { vim.fn.json_encode(res1) }, "stdout")
      job_callbacks[1].on_exit(1, 0, "exit")

      -- Second chunk fails
      job_callbacks[2].on_exit(2, 1, "exit") -- Network error

      assert.are.same({ "Translated: Good chunk.", "", "Bad chunk." }, snacks_win_opts.text)
      assert.are.equal(1, #notifications)
      assert.is_true(string.find(notifications[1].msg, "Some paragraphs could not be translated") ~= nil)
    end)
  end)

  describe("language selection workflow", function()
    it("should open picker and translate with selected language", function()
      -- Arrange
      translator.setup()

      -- Act
      translator.select_language_and_translate()

      -- Assert: Check if picker was called
      assert.is_not_nil(snacks_picker_opts.items)
      assert.are.equal("Select Target Language", snacks_picker_opts.title)

      -- Act: Simulate user selecting a language
      local selected_item = { code = "FR", name = "French" }
      snacks_picker_opts.confirm({ close = function() end }, selected_item) -- Mock picker instance

      -- Assert: Check if translate was called for one chunk
      assert.are.equal(1, #job_callbacks)

      -- Act: Simulate successful API response
      local res = { code = 200, data = "Premier paragraphe.\n\nSecond paragraphe." }
      job_callbacks[1].on_stdout(1, { vim.fn.json_encode(res) }, "stdout")
      job_callbacks[1].on_exit(1, 0, "exit")

      -- Assert: Check if result is displayed
      assert.are.same({ "Premier paragraphe.", "", "Second paragraphe." }, snacks_win_opts.text)
      assert.are.equal(0, #notifications)
    end)
  end)

  describe("syntax highlighting", function()
    it("should pass current filetype to the result window", function()
      -- Arrange
      translator.setup()
      vim.bo.filetype = "markdown" -- Set a specific filetype for this test

      -- Act
      translator.translate()

      -- Assert
      assert.are.equal(1, #job_callbacks)

      -- Simulate API response
      local res = { code = 200, data = "# Translated Markdown" }
      job_callbacks[1].on_stdout(1, { vim.fn.json_encode(res) }, "stdout")
      job_callbacks[1].on_exit(1, 0, "exit")

      -- Assert that the filetype was passed to snacks.win
      assert.are.equal("markdown", snacks_win_opts.ft)
    end)
  end)
end)
