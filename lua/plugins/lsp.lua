local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================

vim.pack.add { gh 'j-hui/fidget.nvim' }
require('fidget').setup {}

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('whipsmart-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
    map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method('textDocument/documentHighlight', event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('whipsmart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('whipsmart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'whipsmart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end

    if client and client:supports_method('textDocument/inlayHint', event.buf) then
      map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
    end
  end,
})

local servers = {
  stylua = {},
  lua_ls = {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false
      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
      end
      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
        workspace = {
          checkThirdParty = false,
          library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
            '${3rd}/luv/library',
            '${3rd}/busted/library',
          }),
        },
      })
    end,
    settings = { Lua = { format = { enable = false } } },
  },
  gopls = {},
  basedpyright = {
    settings = {
      basedpyright = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = 'openFilesOnly',
        },
      },
    },
    before_init = function(_, config)
      local root_dir = config.root_dir
      if root_dir then
        local venv_path = root_dir .. '/.venv'
        if vim.fn.isdirectory(venv_path) == 1 then
          local python_path = venv_path .. '/bin/python'
          if vim.fn.filereadable(python_path) == 1 then
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = python_path
          end
        end
      end
    end,
  },
  ts_ls = {},
}

vim.pack.add {
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
}

-- Mason package names (may differ from lspconfig server names, e.g. lua_ls -> lua-language-server)
local mason_tools = {
  'lua-language-server',
  'stylua',
}

local function has(bin) return vim.fn.executable(bin) == 1 end

if has 'go' then vim.list_extend(mason_tools, { 'gopls', 'goimports' }) end

if has 'python3' then vim.list_extend(mason_tools, { 'basedpyright', 'ruff' }) end

if has 'npm' or has 'pnpm' or has 'yarn' or has 'bun' then vim.list_extend(mason_tools, { 'typescript-language-server', 'prettierd', 'prettier' }) end

if has 'cargo' then table.insert(mason_tools, 'rust-analyzer') end

-- Filter out disabled tools/servers (opt-out)
local disabled_servers = vim.g.disabled_lsp_servers or {}
local function is_disabled(name)
  for _, disabled in ipairs(disabled_servers) do
    if name == disabled then return true end
  end
  return false
end

local filtered_mason_tools = {}
for _, tool in ipairs(mason_tools) do
  -- Map common lspconfig names to mason names for filtering
  local check_name = tool
  if tool == 'lua-language-server' then check_name = 'lua_ls' end

  if not is_disabled(check_name) then table.insert(filtered_mason_tools, tool) end
end

require('mason').setup {}
require('mason-tool-installer').setup { ensure_installed = filtered_mason_tools }

for name, server in pairs(servers) do
  if not is_disabled(name) then
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
end

-- System-installed LSPs (not managed by Mason)
if vim.fn.executable 'nimls' == 1 then
  vim.lsp.config('nimls', {})
  vim.lsp.enable 'nimls'
end

if vim.fn.executable 'gleam' == 1 then
  vim.lsp.config('gleam', {})
  vim.lsp.enable 'gleam'
end

-- Gleam indentation
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('whipsmart-gleam-indent', { clear = true }),
  pattern = 'gleam',
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})
