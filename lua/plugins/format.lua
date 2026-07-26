local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- FORMATTING
-- conform.nvim setup and keymap
-- ============================================================

vim.pack.add { gh 'stevearc/conform.nvim' }

require('conform').setup {
  notify_on_error = true,
  format_on_save = { timeout_ms = 1000, lsp_format = 'fallback' },
  formatters_by_ft = {
    lua = { 'stylua' },
    python = { 'ruff_format', 'ruff_organize_imports' },
    rust = { 'rustfmt' },
    go = { 'goimports', 'gofmt' },
    javascript = { 'prettierd', 'prettier', stop_after_first = true },
    typescript = { 'prettierd', 'prettier', stop_after_first = true },
    javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
    typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
    json = { 'prettierd', 'prettier', stop_after_first = true },
    html = { 'prettierd', 'prettier', stop_after_first = true },
    css = { 'prettierd', 'prettier', stop_after_first = true },
    markdown = { 'prettierd', 'prettier', stop_after_first = true },
    yaml = { 'prettierd', 'prettier', stop_after_first = true },
  },
}

vim.api.nvim_create_user_command('Format', function(args)
  local range = nil
  if args.count ~= -1 then
    local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = { start = { args.line1, 0 }, ['end'] = { args.line2, end_line:len() } }
  end
  require('conform').format { async = true, lsp_format = 'fallback', range = range }
end, { range = true })

vim.keymap.set(
  { 'n', 'v' },
  '<leader>cf',
  function() require('conform').format { async = false, lsp_format = 'fallback', timeout_ms = 1000 } end,
  { desc = '[C]ode [F]ormat file or range' }
)
