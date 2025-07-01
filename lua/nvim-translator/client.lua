-- lua/nvim-translator/client.lua
local M = {}

function M.translate(text, source_lang, target_lang, callback)
  if vim.fn.executable("curl") == 0 then
    local err_msg = "nvim-translator: `curl` is not installed. Please install it to use this plugin."
    vim.notify(err_msg, vim.log.levels.ERROR)
    if callback then
      callback(nil, err_msg)
    end
    return
  end

  -- Add configuration fallback logic
  local config = require("nvim-translator.config")
  if not source_lang or source_lang == "" then
    source_lang = config.opts.source_lang
  end
  if not target_lang or target_lang == "" then
    target_lang = config.opts.target_lang
  end
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
        if type(data) == "table" then -- Check if data is a table (multiple lines)
          for _, line in ipairs(data) do
            table.insert(stdout_chunks, line)
          end
        else -- data is a string (single line)
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
    on_exit = function(job_id, code, event)
      if code ~= 0 then
        vim.notify("Error calling translation API. Exit code: " .. code, vim.log.levels.ERROR)
        if callback then
          callback(nil, "API request failed")
        end
        return
      end

      -- Explicitly filter out nil values from stdout_chunks (though on_stdout should prevent this now)
      local filtered_stdout_chunks = {}
      for _, chunk in ipairs(stdout_chunks) do
        if chunk ~= nil then
          table.insert(filtered_stdout_chunks, chunk)
        end
      end

      local response_body = table.concat(filtered_stdout_chunks, "")

      local ok, response = pcall(vim.fn.json_decode, response_body)

      if not ok or (response and response.code ~= 200) then
        local error_message = "Failed to parse translation response or API returned an error."
        if response and response.message then
          error_message = error_message .. " API message: " .. response.message
        end
        vim.notify(error_message, vim.log.levels.ERROR)
        if callback then
          callback(nil, error_message)
        end
        return
      end

      if callback then
        callback(response.data)
      end
    end,
  })
end

return M
