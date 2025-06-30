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

1.  Enter visual mode in Neovim (press `v` or `V`).
2.  Select the text you want to translate.
3.  Press `<leader>lt` (default keymap) or execute the `:Translate` command.

The translation result will be displayed in a floating window.

## Configuration

You can configure `source_lang` and `target_lang` in the `setup` function.

```lua
require('nvim-translator').setup({
  source_lang = 'auto', -- e.g., translate from auto-detected language
  target_lang = 'FR',   -- e.g., translate to French
})
```
