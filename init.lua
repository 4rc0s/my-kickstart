--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   WHIPSMART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Whipsmart?

  Whipsmart.nvim is a modular, native-first Neovim configuration 
  built on top of the Neovim 0.12+ `vim.pack` system.

  It is designed to be:
  - Modular: Plugin configs are split into `lua/plugins/*.lua`.
  - Native: Uses built-in `vim.pack` and 0.12+ features.
  - Ergonomic: Includes `pack-manager.nvim` for a Lazy-like UI.

  See UNIFIED.md for the Grand Unified roadmap and local instructions.

--]]

-- ============================================================
-- SECTION 1: FOUNDATION
-- Core Neovim settings, leaders, options, basic keymaps, basic autocmds
-- ============================================================
do
  -- Enable faster startup by caching compiled Lua modules
  vim.loader.enable()

  -- Set <space> as the leader key
  -- See `:help mapleader`
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Set to true if you have a Nerd Font installed and selected in the terminal
  vim.g.have_nerd_font = true

  -- Colorscheme to apply. Whichever module owns the matching name prefix installs and applies it;
  -- every other colorscheme module skips itself, so exactly one scheme is ever downloaded and
  -- sourced. 'tokyonight-*' is owned by plugins/core_ui.lua, 'catppuccin-*' by
  -- custom/plugins/catppuccin.lua. Override per machine in lua/local.lua.
  vim.g.whipsmart_colorscheme = 'catppuccin-mocha'

  -- [[ Setting options ]]
  --  See `:help vim.o`
  vim.o.number = true
  vim.o.relativenumber = true
  vim.o.mouse = 'a'
  vim.o.showmode = false
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)
  vim.o.breakindent = true
  vim.o.undofile = true
  vim.o.ignorecase = true
  vim.o.smartcase = true
  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 300
  vim.o.splitright = true
  vim.o.splitbelow = true
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
  vim.o.inccommand = 'split'
  vim.o.cursorline = true
  vim.o.scrolloff = 8
  vim.opt.mousescroll = 'ver:1,hor:6'
  vim.o.confirm = true
  vim.o.colorcolumn = '120'
  vim.o.expandtab = false
  vim.o.tabstop = 4
  vim.o.shiftwidth = 4
  vim.opt.isfname:append '@-@'

  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    virtual_text = true,
    virtual_lines = false,
    jump = {
      on_jump = function(_, bufnr) vim.diagnostic.open_float { bufnr = bufnr, scope = 'cursor', focus = false } end,
    },
  }

  vim.keymap.set('n', '<leader>dq', vim.diagnostic.setloclist, { desc = 'Open [D]iagnostic [Q]uickfix list' })
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
  vim.keymap.set('n', '[d', function() vim.diagnostic.jump { count = -1 } end, { desc = 'Go to previous [D]iagnostic' })
  vim.keymap.set('n', ']d', function() vim.diagnostic.jump { count = 1 } end, { desc = 'Go to next [D]iagnostic' })
  -- Relative line numbers toggle
  vim.keymap.set('n', '<leader>tr', function() vim.o.relativenumber = not vim.o.relativenumber end, { desc = '[T]oggle [R]elative numbers' })
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- File/Buffer/Window Management
  -- Save-and-quit is <leader>W, not <leader>wq: a mapping that is a prefix of another waits out
  -- 'timeoutlen' before firing, which made every <leader>w save feel sluggish. The native `ZZ`
  -- does the same thing and is untouched.
  vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Save current file' })
  vim.keymap.set('n', '<leader>W', ':wq<CR>', { desc = 'Save and quit current file' })
  vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = 'Close current window/buffer' })
  vim.keymap.set('n', '<leader>Q', ':qa!<CR>', { desc = 'Quit Neovim without saving' })
  vim.keymap.set('n', '<leader>bd', ':bd<CR>', { desc = 'Close current buffer' })
  vim.keymap.set('n', '<leader>bn', ':bn<CR>', { desc = 'Next buffer' })
  vim.keymap.set('n', '<leader>bp', ':bp<CR>', { desc = 'Previous buffer' })
  vim.keymap.set('n', '<leader>bl', ':ls<CR>', { desc = 'List buffers' })

  -- Lua Execution
  -- Under <leader>l rather than <leader><leader>: any mapping that is a prefix of another waits out
  -- 'timeoutlen' before firing, and <leader><leader> itself is the buffer picker (plugins/telescope.lua).
  vim.keymap.set('n', '<leader>le', '<cmd>.lua<CR>', { desc = '[L]ua execute current lin[e]' })
  vim.keymap.set('n', '<leader>lx', '<cmd>source %<CR>', { desc = '[L]ua e[x]ecute current file' })

  -- Split Resizing
  vim.keymap.set('n', '<M-,>', '<c-w>5<')
  vim.keymap.set('n', '<M-.>', '<c-w>5>')
  vim.keymap.set('n', '<M-t>', '<C-W>+')
  vim.keymap.set('n', '<M-s>', '<C-W>-')

  -- Split navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Highlight when yanking
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('whipsmart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })

  -- Go indentation (Tabs, width 4)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'go',
    group = vim.api.nvim_create_augroup('whipsmart-go-indent', { clear = true }),
    callback = function()
      vim.bo.expandtab = false
      vim.bo.tabstop = 4
      vim.bo.shiftwidth = 4
    end,
  })

  -- Python indentation (Spaces, width 4, Black/Ruff textwidth)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'python',
    group = vim.api.nvim_create_augroup('whipsmart-python-indent', { clear = true }),
    callback = function()
      vim.bo.expandtab = true
      vim.bo.tabstop = 4
      vim.bo.shiftwidth = 4
      vim.bo.textwidth = 88
    end,
  })

  -- Rust indentation (Spaces, width 4)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'rust',
    group = vim.api.nvim_create_augroup('whipsmart-rust-indent', { clear = true }),
    callback = function()
      vim.bo.expandtab = true
      vim.bo.tabstop = 4
      vim.bo.shiftwidth = 4
    end,
  })

  -- Function to remove trailing whitespace
  local function TrimWhitespace()
    local save = vim.fn.winsaveview()
    vim.cmd [[keeppatterns %s/\s\+$//e]]
    vim.fn.winrestview(save)
  end
  vim.api.nvim_create_user_command('TrimWhitespace', TrimWhitespace, {})

  -- [[ Machine Specific Setup ]]
  local hostname = vim.uv.os_gethostname()
  if hostname == 'orca' then
    -- Specific to this machine if needed in the future
  elseif hostname == 'cygnus' then
    -- Local development machine
  end

  -- lua/local.lua is gitignored — each machine maintains its own copy.
  -- Loaded last so it can override any default set above.
  -- See lua/local.lua.example for available options.
  pcall(require, 'local')
end

-- ============================================================
-- SECTION 2: PLUGIN LOADER
-- vim.pack events and modular plugin loading
-- ============================================================
do
  -- Built-in vim.pack keymaps for low-level access
  --  <leader>ps fetches the newest revision matching each spec's `version` and rewrites the lockfile.
  --  <leader>pr goes the other way: it moves plugins to the revisions already recorded in the
  --  lockfile. Use it after pulling this config on another machine, or to revert a bad update.
  vim.keymap.set('n', '<leader>ps', vim.pack.update, { desc = '[P]ackage [S]ync (update to newest)' })
  vim.keymap.set('n', '<leader>pr', function() vim.pack.update(nil, { target = 'lockfile' }) end, { desc = '[P]ackage [R]estore (sync to lockfile)' })
  vim.keymap.set('n', '<leader>pi', function() vim.pack.update(nil, { offline = true }) end, { desc = '[P]ackage [I]nspect' })

  -- Build steps logic
  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then vim.notify(('Build failed for %s:\n%s'):format(name, result.stderr or result.stdout or 'No output'), vim.log.levels.ERROR) end
  end

  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
      elseif name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
      elseif name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
      elseif name == 'blink.cmp' and vim.fn.executable 'cargo' == 1 then
        run_build(name, { 'cargo', 'build', '--release' }, ev.data.path)
      end
    end,
  })

  -- Load plugin modules in explicit order
  for _, mod in ipairs {
    'plugins.pack_manager',
    'plugins.core_ui',
    'plugins.telescope',
    'plugins.lsp',
    'plugins.cmp',
    'plugins.treesitter',
    'plugins.format',
    'plugins.python_tools',
  } do
    require(mod)
  end
end

-- ============================================================
-- SECTION 3: USER CUSTOMIZATION
-- Personal plugins and opt-in extras, loaded after the core modules so they can
-- depend on anything Section 2 set up (blink.cmp, LSP, telescope, ...).
-- ============================================================
do
  -- Every .lua file in lua/custom/plugins/ is loaded automatically
  require 'custom.plugins'
end

-- vim: ts=2 sts=2 sw=2 et
