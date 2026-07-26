local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================

vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

local parsers = {
  'bash',
  'c',
  'diff',
  'html',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'query',
  'vim',
  'vimdoc',
  'rust',
  'go',
  'javascript',
  'typescript',
  'python',
  'json',
  'yaml',
  'toml',
  'gleam',
  'nim',
}
require('nvim-treesitter').install(parsers)

-- Called from the FileType autocmd below, and again from the install callback for a parser that
-- was not on disk yet. That second path lands seconds later, by which time `buf` may be gone and
-- is almost never the current buffer — so validate it, and set options on `buf` rather than on
-- whatever the user has since switched to.
local function treesitter_try_attach(buf, language)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.treesitter.language.add(language) then return end
  vim.treesitter.start(buf, language)
  local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
  if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
end

local available_parsers = require('nvim-treesitter').get_available()
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local buf, filetype = args.buf, args.match
    local language = vim.treesitter.language.get_lang(filetype)
    if not language then return end
    local installed_parsers = require('nvim-treesitter').get_installed 'parsers'
    if vim.tbl_contains(installed_parsers, language) then
      treesitter_try_attach(buf, language)
    elseif vim.tbl_contains(available_parsers, language) then
      require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
    else
      treesitter_try_attach(buf, language)
    end
  end,
})

-- Rainbow delimiters
vim.pack.add { gh 'HiPhish/rainbow-delimiters.nvim' }
