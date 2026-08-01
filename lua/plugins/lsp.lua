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

-- Mason-managed language servers. One row per server:
--   key      lspconfig name, passed to vim.lsp.config / vim.lsp.enable
--   mason    Mason registry package name (often differs from the lspconfig name)
--   runtime  key into `runtimes` below; omit when the server needs no language runtime
--   config   the table passed to vim.lsp.config
-- A server is installed AND enabled only when its runtime is present and neither of its names
-- appears in vim.g.disabled_lsp_servers. See CLAUDE.md "Adding an LSP server".
local lsp_servers = {
  lua_ls = {
    mason = 'lua-language-server',
    config = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end
        local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
        client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua, {
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
  },
  gopls = { mason = 'gopls', runtime = 'go', config = {} },
  basedpyright = {
    mason = 'basedpyright',
    runtime = 'python',
    config = {
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
  },
  ts_ls = { mason = 'typescript-language-server', runtime = 'node', config = {} },
}

-- Mason packages that are not language servers configured here: formatters, linters, and
-- rust-analyzer (driven by rustaceanvim in lua/custom/plugins/rust.lua). Each row is a list of
-- package names plus an optional `runtime` gate, using the same keys as `lsp_servers` above.
--
-- lspconfig ships a `stylua` server (`stylua --lsp`), but it is deliberately not enabled here:
-- conform already runs the stylua binary for lua via formatters_by_ft, so enabling it would attach
-- a second stylua process to every Lua buffer to do work that is already done. It lives here
-- instead — conform needs the executable, just not the language server.
local extra_tools = {
  { 'stylua' },
  { 'goimports', runtime = 'go' },
  { 'ruff', runtime = 'python' },
  { 'prettierd', 'prettier', runtime = 'node' },
  { 'rust-analyzer', runtime = 'rust' },
}

vim.pack.add {
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
}

local function has(bin) return vim.fn.executable(bin) == 1 end

-- A runtime is available when ANY of its binaries is on PATH. Both `lsp_servers` and
-- `extra_tools` key off these names, so the install gate and the activation gate cannot drift.
local runtimes = {
  go = { 'go' },
  python = { 'python3' },
  node = { 'npm', 'pnpm', 'yarn', 'bun' },
  rust = { 'cargo' },
}

local available = {}
for name, bins in pairs(runtimes) do
  available[name] = vim.iter(bins):any(has)
end

-- Opt-out list (vim.g.disabled_lsp_servers). A server may be named by either its lspconfig name
-- ('ts_ls') or its Mason package name ('typescript-language-server'); either skips both the
-- install and the activation. Standalone tools are named by their Mason package ('stylua').
local disabled_servers = vim.g.disabled_lsp_servers or {}
local function is_disabled(name) return vim.tbl_contains(disabled_servers, name) end
local function runtime_ok(spec) return spec.runtime == nil or available[spec.runtime] end

local mason_tools = {}
local active_servers = {} -- lspconfig name -> config
local mason_to_server = {} -- Mason package name -> lspconfig name

-- vim.spairs keeps the install order stable across launches.
for name, spec in vim.spairs(lsp_servers) do
  if runtime_ok(spec) and not is_disabled(name) and not is_disabled(spec.mason) then
    table.insert(mason_tools, spec.mason)
    mason_to_server[spec.mason] = name
    active_servers[name] = spec.config
  end
end

for _, group in ipairs(extra_tools) do
  if runtime_ok(group) then
    for _, tool in ipairs(group) do
      if not is_disabled(tool) then table.insert(mason_tools, tool) end
    end
  end
end

-- mason.setup puts Mason's bin/ on PATH, so it must precede the vim.lsp.enable loop.
require('mason').setup {}
require('mason-tool-installer').setup { ensure_installed = mason_tools }

for name, config in pairs(active_servers) do
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

-- Buffers opened before Mason finished installing a server never got a client. Re-run activation
-- when a server package lands; vim.lsp.enable re-scans every loaded buffer (:h vim.lsp.enable).
vim.api.nvim_create_autocmd('User', {
  group = vim.api.nvim_create_augroup('whipsmart-mason-lsp-retry', { clear = true }),
  pattern = 'MasonToolsUpdateCompleted',
  callback = function(event)
    for _, package in ipairs(event.data or {}) do
      if mason_to_server[package] then
        vim.schedule(function() vim.lsp.enable(vim.tbl_keys(active_servers)) end)
        return
      end
    end
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
