local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================

vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
require('luasnip').setup {}

vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }

local is_arm32 = jit.arch == 'arm' or vim.uv.os_uname().machine:match 'armv7'
local has_cargo = vim.fn.executable 'cargo' == 1

require('blink.cmp').setup {
  keymap = { preset = 'default' },
  appearance = { nerd_font_variant = 'mono' },
  completion = { documentation = { auto_show = false, auto_show_delay_ms = 500 } },
  -- lazydev (set up in plugins/lsp.lua) completes module names in `require` statements. Its
  -- source reports itself disabled outside lazydev-attached buffers, so listing it in `default`
  -- costs nothing in other filetypes. score_offset floats modules above lua_ls's own results.
  sources = {
    default = { 'lazydev', 'lsp', 'path', 'snippets' },
    providers = {
      lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
    },
  },
  snippets = { preset = 'luasnip' },
  fuzzy = {
    -- Fallback to Lua on 32-bit ARM if Rust is not buildable
    implementation = (is_arm32 and not has_cargo) and 'lua' or 'prefer_rust',
  },
  signature = { enabled = true },
}

-- Autopairs
vim.pack.add { gh 'windwp/nvim-autopairs' }
require('nvim-autopairs').setup {}
