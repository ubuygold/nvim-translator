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
  local json_body = vim.fn.json_encode(body)

  local command = {
    "curl",
    "-s",
    "-X",
    "POST",
    url,
    "-H",
    "Content-Type: application/json",
    "--data-binary",
    "@-",
  }

  local stdout_chunks = {}
  local stderr_chunks = {}
  local job_id

  job_id = vim.fn.jobstart(command, {
    stdin = "pipe",
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_chunks, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_chunks, line)
          end
        end
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        if callback then
          local stderr = table.concat(stderr_chunks, "\n")
          callback(nil, "API request failed with exit code: " .. code .. "\n" .. stderr)
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
          elseif not ok then
            err_msg = err_msg .. " Raw response: " .. response_body
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

  if job_id and job_id > 0 then
    vim.fn.chansend(job_id, json_body)
    vim.fn.chanclose(job_id, "stdin")
  else
    if callback then
      callback(nil, "Failed to start curl job. ID: " .. tostring(job_id))
    end
  end
end

function M.translate(text, source_lang, target_lang, callback)
  local config = require("nvim-translator.config")
  if not source_lang or source_lang == "" then
    source_lang = config.opts.source_lang
  end
  if not target_lang or target_lang == "" then
    target_lang = config.opts.target_lang
  end

  -- 1. Split text into paragraphs
  local paragraphs = util.split_paragraphs(text)
  if #paragraphs == 0 then
    if callback then
      callback(text, false) -- Return original text if no paragraphs
    end
    return
  end

  -- 2. Group paragraphs into chunks
  local chunks = util.chunk_paragraphs(paragraphs, config.opts.max_chunk_size)
  local translated_chunks = {}
  local completed_requests = 0
  local has_errors = false

  if #chunks == 0 then
    if callback then
      callback(text, false) -- Safeguard
    end
    return
  end

  -- 3. Translate each chunk
  for i, chunk in ipairs(chunks) do
    translate_paragraph(chunk, source_lang, target_lang, function(translated, err)
      completed_requests = completed_requests + 1
      if err then
        -- On failure, use the original chunk text
        translated_chunks[i] = chunk
        has_errors = true
      else
        translated_chunks[i] = translated
      end

      -- 4. When all chunks are translated, join them and call the final callback
      if completed_requests == #chunks then
        local final_text = table.concat(translated_chunks, "\n\n")
        if callback then
          callback(final_text, has_errors)
        end
      end
    end)
  end
end

return M
