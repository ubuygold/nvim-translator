-- tests/nvim-translator/config_spec.lua
local config = require("nvim-translator.config")

describe("nvim-translator.config", function()
  before_each(function()
    -- Reset configuration state
    config.opts = {}
  end)

  describe("default_config", function()
    it("should have correct default values", function()
      assert.are.equal("https://deeplx.vercel.app/translate", config.default_config.api_url)
      assert.are.equal("auto", config.default_config.source_lang)
      assert.are.equal("EN", config.default_config.target_lang)
      assert.are.equal("<leader>lt", config.default_config.keymap)
      assert.are.equal("<leader>lT", config.default_config.keymap_to)
    end)
  end)

  describe("setup", function()
    it("should use default config when no options provided", function()
      config.setup()
      
      assert.are.equal("auto", config.opts.source_lang)
      assert.are.equal("EN", config.opts.target_lang)
      assert.are.equal("<leader>lt", config.opts.keymap)
      assert.are.equal("https://deeplx.vercel.app/translate", config.opts.api_url)
      assert.are.equal("<leader>lT", config.opts.keymap_to)
    end)

    it("should merge custom options with defaults", function()
      local custom_opts = {
        source_lang = "en",
        target_lang = "fr",
      }
      
      config.setup(custom_opts)
      
      assert.are.equal("en", config.opts.source_lang)
      assert.are.equal("fr", config.opts.target_lang)
      assert.are.equal("<leader>lt", config.opts.keymap) -- Should keep default value
      assert.are.equal("<leader>lT", config.opts.keymap_to)
    end)

    it("should override all options when provided", function()
      local custom_opts = {
        source_lang = "ja",
        target_lang = "ko",
        keymap = "<leader>tr",
      }
      
      config.setup(custom_opts)
      
      assert.are.equal("ja", config.opts.source_lang)
      assert.are.equal("ko", config.opts.target_lang)
      assert.are.equal("<leader>tr", config.opts.keymap)
    end)

    it("should handle nil options gracefully", function()
      config.setup(nil)
      
      assert.are.equal("auto", config.opts.source_lang)
      assert.are.equal("EN", config.opts.target_lang)
      assert.are.equal("<leader>lt", config.opts.keymap)
    end)

    it("should handle empty table", function()
      config.setup({})
      
      assert.are.equal("auto", config.opts.source_lang)
      assert.are.equal("EN", config.opts.target_lang)
      assert.are.equal("<leader>lt", config.opts.keymap)
      assert.are.equal("<leader>lT", config.opts.keymap_to)
    end)

    it("should preserve nested table structure", function()
      local custom_opts = {
        source_lang = "en",
        custom_field = {
          nested_value = "test"
        }
      }
      
      config.setup(custom_opts)
      
      assert.are.equal("en", config.opts.source_lang)
      assert.are.equal("EN", config.opts.target_lang) -- Should keep default value
      assert.are.equal("test", config.opts.custom_field.nested_value)
    end)
  end)

  describe("opts persistence", function()
    it("should maintain opts between calls", function()
      config.setup({ source_lang = "de" })
      local first_call_opts = config.opts
      
      -- Second call should override previous settings
      config.setup({ target_lang = "es" })
      
      assert.are.equal("auto", config.opts.source_lang) -- Should keep default value
      assert.are.equal("es", config.opts.target_lang)
    end)
  end)
end)
