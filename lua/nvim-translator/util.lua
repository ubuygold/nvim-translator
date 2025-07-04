-- lua/nvim-translator/util.lua
local M = {}

-- Splits text into paragraphs based on one or more empty lines.
function M.split_paragraphs(text)
  -- Normalize CRLF to LF and trim leading/trailing whitespace from the whole text.
  text = text:gsub("\r\n", "\n"):match("^%s*(.-)%s*$") or ""

  local paragraphs = {}
  local current_paragraph = {}

  for line in text:gmatch("([^\n]*)") do
    if line:match("^%s*$") then
      -- When an empty line is found, finalize the current paragraph.
      if #current_paragraph > 0 then
        table.insert(paragraphs, table.concat(current_paragraph, "\n"))
        current_paragraph = {}
      end
    else
      -- Otherwise, add the line to the current paragraph.
      table.insert(current_paragraph, line)
    end
  end

  -- Add the last paragraph if it exists.
  if #current_paragraph > 0 then
    table.insert(paragraphs, table.concat(current_paragraph, "\n"))
  end

  return paragraphs
end

-- New function to group paragraphs into chunks of a maximum size.
function M.chunk_paragraphs(paragraphs, max_size)
  local chunks = {}
  if not paragraphs or #paragraphs == 0 then
    return chunks
  end

  local current_chunk = ""
  local separator = "\n\n"

  for _, p in ipairs(paragraphs) do
    -- If the paragraph itself is larger than max_size, it becomes its own chunk.
    if #p > max_size then
      if #current_chunk > 0 then
        table.insert(chunks, current_chunk)
      end
      table.insert(chunks, p)
      current_chunk = ""
    -- If adding the new paragraph (plus a separator) exceeds the max size...
    elseif #current_chunk + #separator + #p > max_size and #current_chunk > 0 then
      table.insert(chunks, current_chunk)
      current_chunk = p
    else
      -- Otherwise, add the paragraph to the current chunk.
      if #current_chunk == 0 then
        current_chunk = p
      else
        current_chunk = current_chunk .. separator .. p
      end
    end
  end

  -- Add the last chunk if it's not empty.
  if #current_chunk > 0 then
    table.insert(chunks, current_chunk)
  end

  return chunks
end

return M

