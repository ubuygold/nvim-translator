-- tests/nvim-translator/client_spec.lua
local client = require("nvim-translator.client")
local config = require("nvim-translator.config")
local util = require("nvim-translator.util")

describe("nvim-translator.client", function()
  local original_jobstart, original_chansend, original_chanclose
  local job_callbacks = {}
  local job_id_counter

  before_each(function()
    -- Reset configuration
    config.setup({
      source_lang = "auto",
      target_lang = "zh",
    })

    -- Mock vim.fn.jobstart
    original_jobstart = vim.fn.jobstart
    job_callbacks = {}
    job_id_counter = 0

    vim.fn.jobstart = function(command, opts)
      job_id_counter = job_id_counter + 1
      job_callbacks[job_id_counter] = { command = command, opts = opts }
      return job_id_counter
    end

    -- Mock channel functions to avoid "Invalid channel id" error
    original_chansend = vim.fn.chansend
    vim.fn.chansend = function(id, data) end

    original_chanclose = vim.fn.chanclose
    vim.fn.chanclose = function(id, stream) end
  end)

  after_each(function()
    -- Restore original function
    vim.fn.jobstart = original_jobstart
    vim.fn.chansend = original_chansend
    vim.fn.chanclose = original_chanclose
  end)

  describe("translate", function()
    it("should split text into paragraphs and translate each", function()
      local callback_called = false
      local final_text, has_errors

      client.translate("Paragraph one.\n\nParagraph two.", "en", "fr", function(result, err)
        callback_called = true
        final_text = result
        has_errors = err
      end)

      assert.are.equal(2, #job_callbacks) -- Two paragraphs

      -- Simulate successful responses
      local res1 = { code = 200, data = "Premier paragraphe." }
      local res2 = { code = 200, data = "Second paragraphe." }

      job_callbacks[1].opts.on_stdout(1, { vim.fn.json_encode(res1) }, "stdout")
      job_callbacks[1].opts.on_exit(1, 0, "exit")

      job_callbacks[2].opts.on_stdout(2, { vim.fn.json_encode(res2) }, "stdout")
      job_callbacks[2].opts.on_exit(2, 0, "exit")

      assert.is_true(callback_called)
      assert.are.equal("Premier paragraphe.\n\nSecond paragraphe.", final_text)
      assert.is_false(has_errors)
    end)

    it("should handle failure gracefully", function()
      local callback_called = false
      local final_text, has_errors

      client.translate("Good paragraph.\n\nBad paragraph.", "en", "fr", function(result, err)
        callback_called = true
        final_text = result
        has_errors = err
      end)

      assert.are.equal(2, #job_callbacks)

      -- First succeeds
      local res1 = { code = 200, data = "Bon paragraphe." }
      job_callbacks[1].opts.on_stdout(1, { vim.fn.json_encode(res1) }, "stdout")
      job_callbacks[1].opts.on_exit(1, 0, "exit")

      -- Second fails
      job_callbacks[2].opts.on_exit(2, 1, "exit") -- Network error

      assert.is_true(callback_called)
      assert.are.equal("Bon paragraphe.\n\nBad paragraph.", final_text)
      assert.is_true(has_errors)
    end)
  end)

  describe("util.split_paragraphs", function()
    it("should split by double newlines", function()
      local text = "Para 1\n\nPara 2\n\n\nPara 3"
      local paragraphs = util.split_paragraphs(text)
      assert.are.same({ "Para 1", "Para 2", "Para 3" }, paragraphs)
    end)
  end)
end)
