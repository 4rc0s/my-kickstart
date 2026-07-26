# Whipsmart Architecture

Unified Neovim configuration for all machines.

## Core Philosophy

1.  **Universal Core:** Every machine runs the same core `init.lua` and `lua/plugins/*.lua`. LSP, completion, treesitter and formatting live here and are always loaded.
2.  **Opt-In Extras:** Heavier or situational features (`lua/whipsmart/plugins/*.lua` — debug, lint, markdown, neo-tree) are **not** loaded by default. A machine enables one by `require`-ing it from a file in `lua/custom/plugins/`.
3.  **Machine Overrides:** Machine-specific settings (colorscheme, UI toggles, Python path, custom keymaps) live in `lua/local.lua` (git-ignored), loaded at the end of Section 1 so it can override any default.
4.  **Lockfile Driven:** Plugins are declared by `vim.pack.add` calls in Lua; `nvim-pack-lock.json` is the source of truth for the **revision** each one sits at, and is written by Neovim itself.

## Directory Structure

```text
~/.config/nvim/
├── init.lua                # Entry point (1: Foundation, 2: Plugin loader, 3: User customization)
├── nvim-pack-lock.json     # Generated lockfile — plugin revisions
├── lua/
│   ├── local.lua           # (Git-ignored) Machine-specific overrides
│   ├── plugins/            # Universal core — always loaded, explicit order in init.lua
│   │   ├── core_ui.lua     # basic UI, icons, statusline, gitsigns, colorscheme
│   │   ├── telescope.lua   # fuzzy finder
│   │   └── ...
│   ├── custom/
│   │   └── plugins/        # Personal plugins — every .lua here is auto-loaded
│   └── whipsmart/          # Internal framework
│       ├── health.lua      # :checkhealth whipsmart
│       └── plugins/        # Opt-in extras — loaded only when required explicitly
│           ├── debug.lua   # DAP / Go debugging
│           └── ...         # lint, markdown, neo-tree
└── doc/
    └── whipsmart.txt       # Vim help doc
```

## Adding a Plugin

The lockfile is **generated, never hand-edited**. Plugins are declared in Lua by calling
`vim.pack.add`, and `nvim-pack-lock.json` records the revision each one resolved to.

1.  Write the config, including its `vim.pack.add` call:
    - **Personal / machine-optional** — a new file in `lua/custom/plugins/`. Loaded automatically,
      no registration needed.
    - **Universal core** — a new file in `lua/plugins/`, then add its module name to the explicit
      loader list in `init.lua` (Section 2). Order matters there.
2.  Restart Neovim. `vim.pack.add` clones anything missing on the spot and asks you to confirm the
    install; there is no separate install command.
3.  Commit the resulting `nvim-pack-lock.json` change so the other machines pin the same revision.

```lua
-- lua/custom/plugins/harpoon.lua
vim.pack.add { 'https://github.com/ThePrimeagen/harpoon' }
require('harpoon').setup {}
```

Pin a version with a spec table instead of a bare URL — `{ src = ..., version = vim.version.range '2.*' }`
for a semver range, or `version = 'main'` for a branch. Pass an explicit `name` when the URL's last
path segment is generic. See [CLAUDE.md](CLAUDE.md) for LSP servers, formatters, and treesitter
parsers, which have their own registration lists, and for how to remove a plugin again.

## Migration Guide (Hecate -> Whipsmart)

The goal is to move all machine-specific logic out of the main config and into `lua/local.lua`.

### Step 1: Initialize local.lua
```bash
cp ~/.config/nvim/lua/local.lua.example ~/.config/nvim/lua/local.lua
```

### Step 2: LSP Configuration
LSP is **not** configured per machine. Servers are declared centrally in `lua/plugins/lsp.lua`,
which keeps two lists that must both be updated: `servers` (lspconfig names, passed to
`vim.lsp.config` / `vim.lsp.enable`) and `mason_tools` (Mason registry names). The two naming
schemes often differ — see [CLAUDE.md](CLAUDE.md) for the full procedure.

The core is also runtime-aware: it only installs servers for languages found on `PATH`, so a
machine without Go simply never installs `gopls`.

### Step 3: Low-Resource / ARM Optimization (Opt-Out)
The one per-machine LSP knob is opting **out**. For machines with limited resources (older
hardware, ARM devices), disable servers or tools the core would otherwise install:

```lua
-- lua/local.lua — disable heavy LSPs for performance
vim.g.disabled_lsp_servers = { 'lua_ls', 'stylua' }
```

This filters both the Mason install list and the `vim.lsp.enable` loop, so the server is neither
downloaded nor started on that machine. Use lspconfig names for servers (`lua_ls`, not
`lua-language-server`) and Mason names for standalone tools (`stylua`).

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
