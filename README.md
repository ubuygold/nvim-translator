# nvim-translator

A Neovim plugin for word translation using the DeeplX API.

## Features

*   Word translation in visual mode.
*   Configurable source and target languages.
*   Translation results displayed in a floating window.
*   Using the DeeplX API.

## Installation

Install with your favorite plugin manager. For example, using `lazy`:

```lua
return {
  'ubuygold/nvim-translator', -- Replace with your GitHub username and repository name
  dependencies = {'folke/snacks.nvim'},
  config = function()
    require('nvim-translator').setup({
      -- Optional configuration
      source_lang = 'auto', -- Default 'auto'
      target_lang = 'EN',   -- Default 'EN'
    })
  end
}
```

## Usage

There are two ways to translate:

1.  **Direct Translation**:
    *   Enter visual mode (`v` or `V`) and select text.
    *   Press `<leader>lt` (default) or run `:Translate`.
    *   This translates to your default `target_lang`.

2.  **Translate to a Specific Language**:
    *   Enter visual mode and select text.
    *   Press `<leader>lT` (default) or run `:TranslateTo`.
    *   A window will pop up allowing you to select the target language for this translation.

The translation result will be displayed in a floating window.

## Configuration

You can configure the plugin in the `setup` function.

```lua
require('nvim-translator').setup({
  source_lang = 'auto', -- e.g., translate from auto-detected language
  target_lang = 'FR',   -- e.g., translate to French
  keymap = '<leader>lt', -- Keymap for direct translation
  keymap_to = '<leader>lT', -- Keymap for selecting a language before translating
  max_chunk_size = 1000, -- Max characters per API request
  -- You can also override the list of languages for the picker
  -- languages = {
  --   { code = "EN", name = "English", text = "English (EN)" },
  --   { code = "ES", name = "Spanish", text = "Spanish (ES)" },
  -- }
})
```
