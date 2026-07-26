# Whipsmart Architecture

Unified Neovim configuration for all machines.

## Core Philosophy

1.  **Universal Core:** Every machine runs the same core `init.lua` and `lua/plugins/*.lua`.
2.  **Explicit Extras:** Functionality like LSP, Debugging, and Linting are handled by a thin wrapper (`lua/whipsmart/plugins/*.lua`) that only initializes if the underlying plugin is present in `nvim-pack-lock.json`.
3.  **Machine Overrides:** Machine-specific settings (background color, UI toggles, custom keymaps) live in `lua/local.lua` (git-ignored).
4.  **Lockfile Driven:** The `nvim-pack-lock.json` file is the source of truth for installed plugins and their versions.

## Directory Structure

```text
~/.config/nvim/
├── init.lua                # Main entry point (Section 1: Options, Section 2: Plugins, Section 3: LSP/Extra Config)
├── nvim-pack-lock.json     # Plugin manifest and lockfile
├── lua/
│   ├── local.lua           # (Git-ignored) Machine-specific overrides
│   ├── plugins/            # Universal plugin specifications
│   │   ├── core_ui.lua     # basic UI, icons, statusline
│   │   ├── telescope.lua   # fuzzy finder
│   │   └── ...
│   ├── custom/             # Custom plugin specs or opt-in extras
│   │   └── ...
│   └── whipsmart/          # Internal framework
│       ├── health.lua      # :checkhealth whipsmart
│       └── plugins/        # Conditional wrappers for LSP, DAP, Lint, etc.
│           ├── lsp.lua     # only runs if 'neovim/nvim-lspconfig' is in lockfile
│           └── ...
└── doc/
    └── whipsmart.txt       # Vim help doc
```

## Adding a Plugin

1.  Add the plugin to `nvim-pack-lock.json`.
2.  Add a configuration file in `lua/plugins/` (for universal plugins) or `lua/custom/plugins/` (for extras).
3.  Restart Neovim and run `:Pack install`.

## Migration Guide (Hecate -> Whipsmart)

The goal is to move all machine-specific logic out of the main config and into `lua/local.lua`.

### Step 1: Initialize local.lua
```bash
cp ~/.config/nvim/lua/local.lua.example ~/.config/nvim/lua/local.lua
```

### Step 2: LSP Configuration
LSP configuration requires two entries in `lua/local.lua`:
1.  `vim.g.lsp_servers`: A list of LSP servers to ensure are installed via Mason.
2.  `vim.g.lsp_config`: A table mapping server names to their `lspconfig` setup tables.

### Step 3: Low-Resource / ARM Optimization (Opt-Out)
For machines with limited resources (such as older hardware or ARM devices), you can disable heavy LSP servers or tools globally defined in the core.

Add this to `lua/local.lua`:
```lua
-- Disable heavy LSPs for performance
vim.g.disabled_lsp_servers = { 'lua_ls', 'stylua' }
```
This prevents Mason from installing them and Neovim from initializing them on this specific machine.

Example:
```lua
vim.g.lsp_servers = { 'pyright', 'rust_analyzer' }
vim.g.lsp_config = {
  pyright = {
    settings = {
      python = {
        analysis = { autoSearchPaths = true }
      }
    }
  }
}
```

## Pending per-machine step: catppuccin rename (2026-07-25)

Catppuccin is now installed with an explicit `name = 'catppuccin'`. Previously vim.pack derived
its name from the last path segment of `catppuccin/nvim` and installed it as a plugin called
`nvim`. On first launch after pulling this change, each machine clones catppuccin fresh under the
new name and leaves the old directory orphaned:

```vim
:lua vim.pack.del { 'nvim' }
```

The lockfile already carries the corrected entry, so nothing else is needed. Delete this section
once every machine below is done.

- [x] hecate
- [ ] roci
- [ ] orca
- [ ] cygnus
- [ ] tau

Machines that never had catppuccin installed have nothing to clean up. Running the command there
is harmless: `vim.pack.del` resolves every name up front and aborts with
``Plugin `nvim` is not installed`` before deleting anything, so a bad name in the list can't take
a good one with it.

While you're there: `tokyonight.nvim` is now inactive on every machine (the colorscheme default
moved into `init.lua`). Leave it installed unless you want the disk back — see
[CLAUDE.md](CLAUDE.md) under *Removing a plugin*.

## Status / Roadmap

- [x] Initial structure and Section 1-3 implementation.
- [x] Port core plugins (telescope, treesitter, etc.).
- [x] Implement `whipsmart.plugins` conditional loading.
- [x] Move per-machine overrides to `local.lua`.
- [x] Fix `local.lua` load order — `pcall(require, 'local')` moved to end of Section 1 so it can override defaults.
- [x] Add markdown opt-in extra (render-markdown, obsidian, blink.compat).
- [x] Migrate roci to whipsmart.
- [x] Migrate orca to whipsmart (machine-specific scrolloff and catppuccin in local.lua).
- [x] Migrate cygnus to whipsmart (machine-specific keymaps and plugins mainlined).
- [x] Unify Go configuration (Tabs, width 4) as a global standard in init.lua.
- [x] Unify Python configuration (Spaces, width 4, textwidth 88) in init.lua.
- [x] Migrate tau to whipsmart (create lua/local.lua).
- [ ] Migrate vera to whipsmart (create lua/local.lua).
- [ ] Add machine-specific UI toggles for terminal vs. GUI Neovim (via local.lua).
- [ ] Centralize snippet collections.
