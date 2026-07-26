-- Catppuccin colorscheme — this module owns the 'catppuccin-*' schemes.
-- Skipped entirely (including the download) unless `vim.g.whipsmart_colorscheme` names one, so
-- only the scheme actually in use is ever installed and sourced. Set the flavour in init.lua, or
-- per machine in lua/local.lua: 'catppuccin-latte' | '-frappe' | '-macchiato' | '-mocha'.
local scheme = vim.g.whipsmart_colorscheme or 'catppuccin-mocha'
if not vim.startswith(scheme, 'catppuccin') then return end

-- `name` is set explicitly: vim.pack derives the plugin name from the last path segment of `src`,
-- which for catppuccin/nvim would install it as a plugin literally called "nvim" (in the lockfile
-- and the pack UI).
vim.pack.add { { src = 'https://github.com/catppuccin/nvim', name = 'catppuccin' } }
vim.cmd.colorscheme(scheme)
