local function gh(repo) return 'https://github.com/' .. repo end

-- ── render-markdown (always loaded) ─────────────────────────────────────────
-- nvim-treesitter is a dependency but is deliberately not re-declared here. plugins/treesitter.lua
-- pins it to `version = 'main'`; vim.pack keeps the first spec it sees for a given plugin and
-- silently ignores later ones, so an unpinned duplicate is at best redundant and at worst — if this
-- module ever ran first — would resolve treesitter to its default branch, whose older API has no
-- `.install()`. Extras load in Section 3, after the core modules, so it is already on the rtp.
vim.pack.add {
  gh 'MeanderingProgrammer/render-markdown.nvim',
}

require('render-markdown').setup {
  render_modes = { 'n', 'c' },
  heading = { enabled = true },
  bullet = { enabled = true },
  checkbox = { enabled = true },
  code = { enabled = true },
}

vim.api.nvim_create_autocmd('FileType', {
  desc = 'Markdown editing options',
  group = vim.api.nvim_create_augroup('whipsmart-markdown', { clear = true }),
  pattern = 'markdown',
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = 'en_us'
    vim.opt_local.conceallevel = 2
  end,
})

-- ── obsidian (opt-in — requires vim.g.obsidian_vaults to be set in local.lua) ─
-- Example local.lua entry:
--   vim.g.obsidian_vaults = { { name = 'personal', path = '~/Obsidian/Main' } }
if not vim.g.obsidian_vaults then return end

-- blink.compat must be unversioned (HEAD) — released tags lack cmp.get_config()
vim.pack.add {
  { src = gh 'epwalsh/obsidian.nvim', version = vim.version.range '*' },
  gh 'nvim-lua/plenary.nvim',
  gh 'saghen/blink.compat',
}

require('blink.compat').setup {}

require('obsidian').setup {
  workspaces = vim.g.obsidian_vaults,
  completion = { nvim_cmp = false, min_chars = 2 },
}

-- Register obsidian nvim-cmp sources via blink.compat shim
local cmp = require 'cmp'
cmp.register_source('obsidian', require('cmp_obsidian').new())
cmp.register_source('obsidian_new', require('cmp_obsidian_new').new())
cmp.register_source('obsidian_tags', require('cmp_obsidian_tags').new())

-- Extend blink.cmp config post-setup via the v1 merge_with API.
-- Called from custom/plugins/ (Section 3), so plugins.cmp has already run setup().
require('blink.cmp.config').merge_with {
  completion = {
    trigger = {
      -- Remove '[' so [[ wikilinks trigger the completion menu
      show_on_x_blocked_trigger_characters = { "'", '"', '(', '{' },
    },
    menu = {
      -- Suppress auto-popup in markdown/text except when '[' was the trigger
      auto_show = function(ctx)
        if vim.tbl_contains({ 'markdown', 'text' }, vim.bo.filetype) then
          return ctx.trigger.initial_kind == 'trigger_character' and ctx.trigger.initial_character == '['
        end
        return true
      end,
    },
  },
  sources = {
    per_filetype = {
      markdown = { 'obsidian', 'obsidian_new', 'obsidian_tags', 'lsp', 'path', 'snippets', 'buffer' },
    },
    providers = {
      obsidian = { name = 'obsidian', module = 'blink.compat.source' },
      obsidian_new = { name = 'obsidian_new', module = 'blink.compat.source' },
      obsidian_tags = { name = 'obsidian_tags', module = 'blink.compat.source' },
    },
  },
}
