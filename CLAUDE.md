# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Overview

This is **whipsmart.nvim** — a modular, native-first Neovim configuration built on the
Neovim 0.12+ `vim.pack` system. It replaced a kickstart.nvim + Lazy.nvim setup on all machines.

- Core plugin modules live in `lua/plugins/`.
- Opt-in extras live in `lua/whipsmart/plugins/` (not loaded by default).
- Per-machine overrides live in `lua/local.lua` (gitignored, never committed).
- Personal plugins go in `lua/custom/plugins/` (auto-loaded, gitignored-friendly).
- The roadmap and architecture notes are in `UNIFIED.md`.

## Plugin Management (inside Neovim)

- `<leader>pm` — open the **Package Manager Menu** (pack-manager.nvim UI)
- `<leader>ps` — sync packages to newest (`vim.pack.update()`)
- `<leader>pr` — restore packages to lockfile revisions (`vim.pack.update(nil, { target = 'lockfile' })`)
- `<leader>pi` — inspect package status (offline)
- `:checkhealth whipsmart` — diagnose config/plugin issues
- `:Mason` — manage LSP servers, linters, formatters
- `:TSUpdate` — update treesitter parsers
- `:ConformInfo` — show active formatters for current buffer

### Managing `nvim-pack-lock.json` Across Machines

The `nvim-pack-lock.json` lockfile ensures all machines install the exact same version of Neovim plugins. It is fully tracked in Git without workarounds. It is written by Neovim itself
(`:help vim.pack-lockfile`), not by pack-manager.nvim.

**`<leader>ps` and `<leader>pr` are not interchangeable.** `vim.pack.update()` defaults to
`target = 'version'`: it fetches the newest revision matching each spec's `version` constraint and
then *rewrites* the lockfile. `<leader>pr` passes `target = 'lockfile'`, moving plugins to the
revisions already recorded there. Use `<leader>ps` when you intend to bump plugins, and
`<leader>pr` after pulling this config elsewhere or to revert a bad update.

Plugins that are in the lockfile but missing from disk are installed at the locked revision on
startup, so `<leader>pr` is only needed for plugins already present at a different revision.
After confirming an update, `:restart` to load the new code.

If you update plugins locally:
1. Stage and commit the updated `nvim-pack-lock.json`:
   ```bash
   git add nvim-pack-lock.json
   git commit -m "Update package lockfile"
   ```
2. Push your changes so your other machines stay in sync:
   ```bash
   git push origin master
   ```

If you want to pull changes but have local lockfile changes you do not want to keep:
1. Discard the local lockfile changes:
   ```bash
   git restore nvim-pack-lock.json
   ```
2. Pull the changes:
   ```bash
   git pull
   ```

If a merge conflict occurs on the lockfile during a pull:
1. Accept the upstream lockfile:
   ```bash
   git checkout --theirs nvim-pack-lock.json
   ```
2. Open Neovim and run `<leader>pr` (**not** `<leader>ps`, which would fetch newest and overwrite
   the lockfile you just accepted), confirm with `:write`, then `:restart`.
3. Commit the resolved lockfile.

## Architecture

### Adding an LSP server

Add **one row** to `lsp_servers` in `lua/plugins/lsp.lua`. Everything else — the Mason install
list, the runtime gate, the opt-out filter, and the post-install retry — is derived from it:

```lua
local lsp_servers = {
  lua_ls = {
    mason = 'lua-language-server',   -- Mason name for lua_ls (differs!)
    config = { ... },                -- passed to vim.lsp.config
  },
  gopls = { mason = 'gopls', runtime = 'go', config = {} },
}
```

| Field | Meaning |
| --- | --- |
| key | **lspconfig name** — passed to `vim.lsp.config` / `vim.lsp.enable` |
| `mason` | **Mason registry name** — passed to `mason-tool-installer` |
| `runtime` | key into `runtimes`; omit when the server needs no language runtime |
| `config` | the server's `vim.lsp.config` table |

lspconfig names and Mason names often differ. Look up the Mason name at
[mason-registry.dev](https://mason-registry.dev/registry/list) and the lspconfig name in the
[lspconfig server list](https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md).

A server is installed **and** enabled only when its `runtime` is present on the machine and
neither of its names appears in `vim.g.disabled_lsp_servers`. A new `runtime` key needs a row in
the `runtimes` table above it — a runtime counts as available when **any** of its binaries is on
`PATH` (that is how `node` accepts npm/pnpm/yarn/bun):

```lua
local runtimes = {
  go = { 'go' },
  node = { 'npm', 'pnpm', 'yarn', 'bun' },
}
```

Because `runtimes` is evaluated once at startup, installing a new language runtime needs a
Neovim restart, not just `:MasonToolsInstall`.

System-installed LSPs (not managed by Mason) are added at the bottom of `lsp.lua` with an
`executable` guard — see `nimls` and `gleam` as examples.

### Adding a formatter

Add to `formatters_by_ft` in `lua/plugins/format.lua`. If it needs auto-installation, add the
Mason package name to `extra_tools` in `lsp.lua` — the list for Mason packages that are *not*
language servers configured here (formatters, linters, and rust-analyzer, which rustaceanvim
drives). Each row is package names plus an optional `runtime` gate, using the same keys as
`lsp_servers`:

```lua
local extra_tools = {
  { 'stylua' },                              -- no runtime gate
  { 'prettierd', 'prettier', runtime = 'node' },
}
```

Format-on-save needs no registration: `format_on_save = { timeout_ms = 1000, lsp_format = 'fallback' }`
applies to **every** filetype, and falls back to the LSP formatter when conform has none configured
for the buffer. There is no per-filetype opt-in list.

To make it conditional, replace that table with a function — conform skips the save-format when it
returns `nil`:

```lua
format_on_save = function(bufnr)
  if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
  return { timeout_ms = 1000, lsp_format = 'fallback' }
end,
```

### Adding treesitter parsers

Add the language name to the `parsers` list in `lua/plugins/treesitter.lua`. Only parsers
not already installed will be fetched on the next launch.

### Adding a plugin

**Personal plugin** — drop a `.lua` file in `lua/custom/plugins/`. It is loaded automatically
and will never conflict with upstream changes:
```lua
-- lua/custom/plugins/harpoon.lua
vim.pack.add { 'https://github.com/ThePrimeagen/harpoon' }
require('harpoon').setup {}
```

**Core plugin** — create `lua/plugins/my_plugin.lua` and register it in the explicit loader
list in `init.lua` (Section 2):
```lua
for _, mod in ipairs {
  ...
  'plugins.my_plugin',  -- add here
} do
```

### Lazy-loading a plugin

`vim.pack.add` puts a plugin on the runtimepath immediately. Passing a `load` callback makes the
caller fully responsible for loading, which `lua/whipsmart/lazy.lua` wraps:

```lua
local T = require('whipsmart.lazy').new({ 'https://github.com/folke/trouble.nvim' }, function()
  require('trouble').setup {}
end)

T.cmd 'Trouble'                                      -- stub command; loads, then re-runs for real
T.map('n', '<leader>xx', 'Trouble diagnostics toggle', { desc = '...' })
T.load()                                             -- or force it directly
```

Notes:

- The `rhs` given to `T.map` is a **plain Ex command**, not keymap notation. `'<cmd>Foo<cr>'` would
  be passed to `vim.cmd` and fail with `E488: Trailing characters`; the helper raises an error
  rather than let that happen silently.
- Only stub a command the plugin creates in its own `plugin/` directory (Telescope does; Trouble
  creates `:Trouble` from `setup`, so the stub only matters before the first load).
- Deferred plugins still count as **active** to `vim.pack.get`, because `vim.pack` registers them
  before invoking `load`. They will not show up as orphans in the inactive list.
- `vim.cmd.packadd` at runtime does not source `after/plugin/`. None of the currently deferred
  plugins ship one; check before deferring a plugin that does.

**When not to.** A plugin that must register autocmds at startup to do its job cannot be deferred
without re-implementing those triggers. `oil.nvim` is the standing example: its `setup` sets
`vim.g.loaded_netrw`, and installs the `BufNew` / `BufEnter` / `BufReadCmd` handlers that make
`nvim <dir>` open oil instead of netrw. Deferring it would mean owning that hijack, to save ~5ms.
It is loaded eagerly on purpose — don't "optimize" it without reading this paragraph.

### Removing a plugin (and cleaning up orphans)

Deleting a plugin's config does **not** remove it from disk. vim.pack keeps it as an *inactive*
plugin — still in `~/.local/share/nvim/site/pack/core/opt/` and still in the lockfile. The same
happens when a plugin's `name` changes: the old directory is orphaned and a fresh clone appears
under the new name.

List what is currently inactive:

```vim
:lua vim.print(vim.iter(vim.pack.get(nil, { info = false })):filter(function(p) return not p.active end):map(function(p) return p.spec.name end):totable())
```

Delete by name — this removes the directory **and** the lockfile entry:

```vim
:lua vim.pack.del { 'name1', 'name2' }
```

pack-manager.nvim's `:PackListInactive` / `:PackDelInactive` do the same thing.

**Inactive does not always mean unwanted.** A plugin gated behind an opt-in extra or a `local.lua`
flag is legitimately inactive on machines that don't enable it — `obsidian.nvim` and `blink.compat`
without `vim.g.obsidian_vaults`, `tokyonight.nvim` when another colorscheme is selected,
`nvim-web-devicons` where mini.icons mocks it. Deleting those just means re-downloading later, and
unpinned, since the lockfile entry goes too. Read the list before acting on it.

### Enabling opt-in extras

Extras in `lua/whipsmart/plugins/` are not loaded by default. Enable one from a file in
`lua/custom/plugins/`:
```lua
-- lua/custom/plugins/debug.lua
require 'whipsmart.plugins.debug'
```

Available extras: `debug` (DAP/Go), `lint`, `markdown` (render-markdown + obsidian), `neo-tree`.

(autopairs, indent-blankline and the gitsigns hunk keymaps used to be extras; they are all
unconditional in core now — see `plugins/cmp.lua` and `plugins/core_ui.lua`.)

### Per-machine configuration (`lua/local.lua`)

`lua/local.lua` is gitignored and loaded at the **end** of Section 1 in `init.lua`, after
all defaults are set, so it can override anything. Copy `lua/local.lua.example` on each
new machine.

Common uses: Nerd Font toggle, colorscheme, GUI font, Python path, enabling opt-in extras,
setting `vim.g.obsidian_vaults` for the markdown extra.

### Colorscheme

`vim.g.whipsmart_colorscheme` (set in `init.lua` Section 1, overridable in `local.lua`) names the
scheme to apply. Each colorscheme module **owns a name prefix** and returns early unless the
variable matches it:

| Prefix | Owner |
| --- | --- |
| `tokyonight-*` | `lua/plugins/core_ui.lua` |
| `catppuccin-*` | `lua/custom/plugins/catppuccin.lua` |

The `vim.pack.add` call sits inside the guard, so a scheme that isn't in use is never downloaded,
never added to the runtimepath, and never sourced. Sourcing two colorschemes costs ~30ms and makes
the winner order-dependent.

To add a third scheme, create `lua/custom/plugins/<name>.lua` following the same shape — guard on
the prefix, then `vim.pack.add` and `vim.cmd.colorscheme(scheme)`. The `colorscheme` call must live
in `lua/custom/plugins/` (Section 3) rather than `local.lua` (Section 1), because the plugin isn't
on disk until its module runs.

The default is deliberately tracked in `init.lua` rather than left to each machine's `local.lua` —
a gitignored file can't carry a decision that applies to every machine, and the machine that
forgets it silently loads two colorschemes.

## Markdown / Obsidian setup (`lua/whipsmart/plugins/markdown.lua`)

The markdown opt-in bundles render-markdown.nvim (always) and obsidian.nvim + blink.compat
(gated on `vim.g.obsidian_vaults`).

**To enable on a machine:**

In `lua/local.lua`:
```lua
vim.g.obsidian_vaults = { { name = 'personal', path = '~/Obsidian/Main' } }
```

In `lua/custom/plugins/markdown.lua`:
```lua
require 'whipsmart.plugins.markdown'
```

**Why `require` goes in `custom/plugins/` not `local.lua`:**
`local.lua` runs in Section 1, before `plugins.cmp` loads blink.cmp. The markdown opt-in
calls `require('blink.cmp.config').merge_with(...)` which needs blink.cmp already set up
(Section 2). `custom/plugins/` loads in Section 3, so the timing is correct.

**blink.compat** is added without a version pin (HEAD/main) — released tags lack
`cmp.get_config()` that obsidian.nvim calls internally.

**Completion trigger behaviour in markdown:**

- `[` is removed from `show_on_x_blocked_trigger_characters` so `[[` wikilinks trigger completion.
- `completion.menu.auto_show` suppresses the popup for regular word typing in markdown/text;
  the menu only auto-opens when the trigger character was `[`. Ctrl-Space always works.
- `min_chars = 2` means the menu appears after the second character of a wikilink query.

```lua
-- ctx fields available in auto_show:
--   ctx.trigger.initial_kind      → 'manual' | 'trigger_character' | 'insert_enter'
--   ctx.trigger.initial_character → the character that opened the context (or nil)
```

## Git Remotes

- `origin` → `https://github.com/4rc0s/whipsmart.nvim.git` (Grand Unified config)

whipsmart.nvim is its own project — there is no automatic upstream syncing from
kickstart.nvim. However, we occasionally review upstream changes and port the ones that
make sense as fresh commits (citing the upstream hash in the commit message).

### Reviewing upstream kickstart.nvim

**Last reviewed:** kickstart commit `267fb6a` (2026-07-25). Start the next review from
this watermark — because ports are fresh commits (never merges), `git merge-base` stays
frozen at the original fork point (`cfdc17b`) and would re-surface already-ported commits.

Workflow:
```bash
git remote add kickstart-upstream https://github.com/nvim-lua/kickstart.nvim.git
git fetch kickstart-upstream master
git log --oneline <last-reviewed>..kickstart-upstream/master   # candidates
git remote remove kickstart-upstream                           # clean up when done
```

Kickstart is a single-file `init.lua`; our config is split into `lua/plugins/*.lua`
modules, so port changes by hand rather than cherry-picking. Purely structural upstream
changes (section renumbering, comment reflows) usually don't map onto our layout.
After a review, update the **Last reviewed** watermark above.

## Key Conventions

- `vim.g.have_nerd_font` — gates icon usage throughout the config; defaults to `true`.
  Override in `local.lua` on terminals without a Nerd Font.
- `mason-lspconfig` is **not installed**. `mason-tool-installer` would use it for lspconfig↔Mason
  name translation, but that integration is `pcall`-guarded and simply goes unused — which is why
  each `lsp_servers` row in `lsp.lua` carries its own `mason` field spelling the Mason name out
  directly (`lua-language-server`, not `lua_ls`). Adding it back would also mean calling
  `setup { automatic_enable = false }`: its default auto-enables every Mason-installed server,
  fighting the explicit `vim.lsp.enable` loop.
- `blink.cmp` sources use `sources.default`; per-filetype overrides go in `sources.per_filetype`.
- vim.pack derives a plugin's name from the **last path segment of `src`**. When that segment is
  generic, pass an explicit `name` — `catppuccin/nvim` would otherwise install as a plugin called
  `nvim` in both the lockfile and the pack UI. See `lua/custom/plugins/catppuccin.lua`.
- `gitsigns.setup` (and most plugin `setup` calls) do not merge across calls — a second call
  re-applies defaults over the first. Keep one `setup` per plugin.
- LSP is configured with Neovim's native `vim.lsp.config` / `vim.lsp.enable` API (0.11+),
  not through `lspconfig.server.setup()`.
