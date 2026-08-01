local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================

vim.pack.add { gh 'j-hui/fidget.nvim' }
require('fidget').setup {}

local highlight_augroup = vim.api.nvim_create_augroup('whipsmart-lsp-highlight', { clear = true })

local function supports_document_highlight(client, bufnr) return client:supports_method('textDocument/documentHighlight', bufnr) end

local function has_document_highlight_client(bufnr, excluded_client_id)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if client.id ~= excluded_client_id and supports_document_highlight(client, bufnr) then return true end
  end
  return false
end

vim.api.nvim_create_autocmd('LspDetach', {
  group = vim.api.nvim_create_augroup('whipsmart-lsp-detach', { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and supports_document_highlight(client, event.buf) and not has_document_highlight_client(event.buf, client.id) then
      vim.lsp.util.buf_clear_references(event.buf)
      vim.api.nvim_clear_autocmds { group = highlight_augroup, buffer = event.buf }
      vim.b[event.buf].whipsmart_lsp_highlights = nil
    end
  end,
})

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
    if client and supports_document_highlight(client, event.buf) and not vim.b[event.buf].whipsmart_lsp_highlights then
      vim.b[event.buf].whipsmart_lsp_highlights = true
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
    end

    if client and client:supports_method('textDocument/inlayHint', event.buf) then
      map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
    end
  end,
})

-- lspconfig ships a `stylua` server (`stylua --lsp`), but it is deliberately not enabled here:
-- conform already runs the stylua binary for lua via formatters_by_ft, so enabling it would attach
-- a second stylua process to every Lua buffer to do work that is already done. It stays in
-- mason_tools below — conform needs the executable, just not the language server.
local servers = {
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

-- Do not activate an LSP whose runtime is unavailable on this machine.
local server_runtime_available = {
  gopls = has 'go',
  basedpyright = has 'python3',
  ts_ls = has 'npm' or has 'pnpm' or has 'yarn' or has 'bun',
}

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

local enabled_servers = {}
for name, server in pairs(servers) do
  if not is_disabled(name) and server_runtime_available[name] ~= false then
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
    enabled_servers[name] = true
  end
end

-- Retry buffers opened before Mason finished installing their language server.
local mason_lsp_servers = {
  ['lua-language-server'] = 'lua_ls',
  gopls = 'gopls',
  basedpyright = 'basedpyright',
  ['typescript-language-server'] = 'ts_ls',
}
vim.api.nvim_create_autocmd('User', {
  group = vim.api.nvim_create_augroup('whipsmart-mason-lsp-retry', { clear = true }),
  pattern = 'MasonToolsUpdateCompleted',
  callback = function(event)
    local retry = {}
    for _, package in ipairs(event.data or {}) do
      local name = mason_lsp_servers[package]
      if name and enabled_servers[name] then table.insert(retry, name) end
    end
    if #retry > 0 then vim.schedule(function() vim.lsp.enable(retry) end) end
  end,
})

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
