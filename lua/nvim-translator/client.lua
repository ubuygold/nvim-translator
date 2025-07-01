-- lua/nvim-translator/client.lua
local M = {}
local util = require("nvim-translator.util")

local function translate_paragraph(text, source_lang, target_lang, callback)
  if vim.fn.executable("curl") == 0 then
    local err_msg = "nvim-translator: `curl` is not installed. Please install it to use this plugin."
    vim.notify(err_msg, vim.log.levels.ERROR)
    if callback then
      callback(nil, err_msg)
    end
    return
  end

  local config = require("nvim-translator.config")
  local url = config.opts.api_url
  local body = {
    text = text,
    source_lang = source_lang,
    target_lang = target_lang,
  }
  local command = {
    "curl",
    "-s",
    "-X",
    "POST",
    url,
    "-H",
    "Content-Type: application/json",
    "-d",
    vim.fn.json_encode(body),
  }

  local stdout_chunks = {}
  local stderr_chunks = {}

  vim.fn.jobstart(command, {
    on_stdout = function(_, data, _)
      if data then
        if type(data) == "table" then
          for _, line in ipairs(data) do
            table.insert(stdout_chunks, line)
          end
        else
          table.insert(stdout_chunks, data)
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        if type(data) == "table" then
          for _, line in ipairs(data) do
            table.insert(stderr_chunks, line)
          end
        else
          table.insert(stderr_chunks, data)
        end
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        if callback then
          callback(nil, "API request failed with exit code: " .. code)
        end
        return
      end

      local response_body = table.concat(stdout_chunks, "")
      local ok, response = pcall(vim.fn.json_decode, response_body)

      if not ok or (response and response.code ~= 200) then
        if callback then
          local err_msg = "Failed to parse response or API error."
          if response and response.message then
            err_msg = err_msg .. " Message: " .. response.message
          end
          callback(nil, err_msg)
        end
        return
      end

      if callback then
        callback(response.data)
      end
    end,
  })
end

function M.translate(text, source_lang, target_lang, callback)
  local config = require("nvim-translator.config")
  if not source_lang or source_lang == "" then
    source_lang = config.opts.source_lang
  end
  if not target_lang or target_lang == "" then
    target_lang = config.opts.target_lang
  end

  local paragraphs = util.split_paragraphs(text)
  local translated_paragraphs = {}
  local completed_requests = 0
  local has_errors = false

  if #paragraphs == 0 then
    if callback then
      callback(text) -- Return original text if no paragraphs found
    end
    return
  end

  for i, p in ipairs(paragraphs) do
    translate_paragraph(p, source_lang, target_lang, function(translated, err)
      completed_requests = completed_requests + 1
      if err then
        translated_paragraphs[i] = p -- Use original paragraph on failure
        has_errors = true
      else
        translated_paragraphs[i] = translated
      end

      if completed_requests == #paragraphs then
        local final_text = table.concat(translated_paragraphs, "\n\n")
        if callback then
          callback(final_text, has_errors)
        end
      end
    end)
  end
end

return M
