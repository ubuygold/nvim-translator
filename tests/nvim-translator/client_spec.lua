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

  describe("translate with chunking", function()
    local captured_chunks
    local original_translate_paragraph

    before_each(function()
      captured_chunks = {}
      -- Mock the internal function that sends requests
      original_translate_paragraph = client.translate_paragraph
      client.translate_paragraph = function(text, _, _, callback)
        table.insert(captured_chunks, text)
        -- Simulate successful translation by returning a modified version of the chunk
        callback("Translated: " .. text, false)
      end
    end)

    after_each(function()
      client.translate_paragraph = original_translate_paragraph
    end)

    it("should not chunk if text is smaller than max_chunk_size", function()
      config.setup({ max_chunk_size = 1000 })
      local text = "Paragraph one.\n\nParagraph two."
      local final_text
      client.translate(text, "auto", "en", function(result)
        final_text = result
      end)
      assert.are.equal(1, #captured_chunks)
      assert.are.equal(text, captured_chunks[1])
      assert.are.equal("Translated: " .. text, final_text)
    end)

    it("should split text into multiple chunks if it exceeds max_chunk_size", function()
      config.setup({ max_chunk_size = 25 })
      local text = "This is the first paragraph.\n\nThis is the second one."
      local final_text
      client.translate(text, "auto", "en", function(result)
        final_text = result
      end)

      assert.are.equal(2, #captured_chunks)
      assert.are.equal("This is the first paragraph.", captured_chunks[1])
      assert.are.equal("This is the second one.", captured_chunks[2])
      assert.are.equal("Translated: This is the first paragraph.\n\nTranslated: This is the second one.", final_text)
    end)

    it("should handle a single paragraph larger than max_chunk_size as one chunk", function()
      config.setup({ max_chunk_size = 15 })
      local text = "This single paragraph is very long."
      client.translate(text, "auto", "en", function() end)

      assert.are.equal(1, #captured_chunks)
      assert.are.equal(text, captured_chunks[1])
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
