local function gh(repo) return 'https://github.com/' .. repo end
local lazy = require 'whipsmart.lazy'

-- ============================================================
-- SEARCH & NAVIGATION
-- Telescope setup, keymaps, LSP picker mappings
--
-- Telescope is loaded on first use (a keymap, `:Telescope`, or anything calling `vim.ui.select`)
-- rather than at startup — see lua/whipsmart/lazy.lua.
-- ============================================================

local telescope_plugins = {
  gh 'nvim-lua/plenary.nvim',
  gh 'nvim-telescope/telescope.nvim',
  gh 'nvim-telescope/telescope-ui-select.nvim',
}
if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end

local T = lazy.new(telescope_plugins, function()
  require('telescope').setup {
    defaults = {
      file_ignore_patterns = { 'Obsidian%-Syncthing', '%.bz2' },
    },
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }

  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')
end)

-- `:Telescope` is created by the plugin's own plugin/ file, so it does not exist until Telescope
-- is on the runtimepath. Stand in for it until then.
T.cmd 'Telescope'

--- Keymap rhs: load Telescope, then run one of its builtin pickers.
--- @param name string A `telescope.builtin` picker name.
--- @param opts? table Options forwarded to the picker.
local function pick(name, opts)
  return function()
    T.load()
    require('telescope.builtin')[name](opts)
  end
end

vim.keymap.set('n', '<leader>sh', pick 'help_tags', { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', pick 'keymaps', { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', pick 'find_files', { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ss', pick 'builtin', { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set({ 'n', 'v' }, '<leader>sw', pick 'grep_string', { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', pick 'live_grep', { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', pick 'diagnostics', { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', pick 'resume', { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', pick 'oldfiles', { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set('n', '<leader>sc', pick 'commands', { desc = '[S]earch [C]ommands' })
vim.keymap.set('n', '<leader><leader>', pick 'buffers', { desc = '[ ] Find existing buffers' })

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('whipsmart-telescope-lsp-attach', { clear = true }),
  callback = function(event)
    local buf = event.buf
    local function map(lhs, picker, desc) vim.keymap.set('n', lhs, pick(picker), { buffer = buf, desc = desc }) end

    map('grr', 'lsp_references', '[G]oto [R]eferences')
    map('gri', 'lsp_implementations', '[G]oto [I]mplementation')
    map('grd', 'lsp_definitions', '[G]oto [D]efinition')
    map('gO', 'lsp_document_symbols', 'Open Document Symbols')
    map('gW', 'lsp_dynamic_workspace_symbols', 'Open Workspace Symbols')
    map('grt', 'lsp_type_definitions', '[G]oto [T]ype Definition')
  end,
})

vim.keymap.set('n', '<leader>/', function()
  T.load()
  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })

vim.keymap.set(
  'n',
  '<leader>s/',
  pick('live_grep', {
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  }),
  { desc = '[S]earch [/] in Open Files' }
)

vim.keymap.set('n', '<leader>sn', pick('find_files', { cwd = vim.fn.stdpath 'config', follow = true }), { desc = '[S]earch [N]eovim files' })
vim.keymap.set('n', '<C-p>', pick 'git_files', { desc = 'Search Git Files' })
vim.keymap.set('n', '<leader>pf', function()
  T.load()
  require('telescope.builtin').grep_string { search = vim.fn.input 'Grep > ' }
end, { desc = '[P]roject [F]ind (grep with input)' })

-- The ui-select extension replaces `vim.ui.select` when Telescope loads. Until then, stand in for
-- it so the first caller (LSP code actions, for example) still gets the Telescope picker rather
-- than the built-in prompt. Falls back to the original if the extension did not take over.
local builtin_select = vim.ui.select
local shim
shim = function(...)
  T.load()
  if vim.ui.select == shim then vim.ui.select = builtin_select end
  return vim.ui.select(...)
end
vim.ui.select = shim
