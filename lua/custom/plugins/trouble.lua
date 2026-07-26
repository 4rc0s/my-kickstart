-- Trouble is loaded on first use — see lua/whipsmart/lazy.lua.
-- Nothing observable changes by deferring it: the `:Trouble` command is created by
-- `trouble.setup`, and these keymaps are the only other entry point.
local T = require('whipsmart.lazy').new({ 'https://github.com/folke/trouble.nvim' }, function() require('trouble').setup {} end)

T.cmd 'Trouble'

T.map('n', '<leader>xx', 'Trouble diagnostics toggle', { desc = 'Diagnostics (Trouble)' })
T.map('n', '<leader>xX', 'Trouble diagnostics toggle filter.buf=0', { desc = 'Buffer Diagnostics (Trouble)' })
T.map('n', '<leader>cs', 'Trouble symbols toggle focus=false', { desc = 'Symbols (Trouble)' })
T.map('n', '<leader>cl', 'Trouble lsp toggle focus=false win.position=right', { desc = 'LSP Definitions/References (Trouble)' })
T.map('n', '<leader>xL', 'Trouble loclist toggle', { desc = 'Location List (Trouble)' })
T.map('n', '<leader>xQ', 'Trouble qflist toggle', { desc = 'Quickfix List (Trouble)' })
