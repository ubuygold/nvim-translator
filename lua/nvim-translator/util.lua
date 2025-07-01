-- lua/nvim-translator/util.lua
local M = {}

-- Splits text into paragraphs based on one or more empty lines.
function M.split_paragraphs(text)
  local paragraphs = {}
  -- Normalize CRLF to LF and trim leading/trailing whitespace from the whole text.
  text = text:gsub("\r\n", "\n"):match("^%s*(.-)%s*$")
  
  for p in text:gmatch("([^\n]+)") do
    -- This will capture any non-empty line as a paragraph.
    -- To split by empty lines, we can do this differently.
    table.insert(paragraphs, p)
  end

  -- A better approach for splitting by empty lines:
  local paragraphs_temp = {}
  local current_paragraph = {}

  for line in text:gmatch("([^\n]*)") do
    if line:match("^%s*$") then
      if #current_paragraph > 0 then
        table.insert(paragraphs_temp, table.concat(current_paragraph, "\n"))
        current_paragraph = {}
      end
    else
      table.insert(current_paragraph, line)
    end
  end
  if #current_paragraph > 0 then
    table.insert(paragraphs_temp, table.concat(current_paragraph, "\n"))
  end
  
  return paragraphs_temp
end

return M

