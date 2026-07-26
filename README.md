# 🌌 Whipsmart.nvim

Whipsmart.nvim is a modular, native-first Neovim configuration built on top of the Neovim 0.12+ `vim.pack` system. It evolved from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) into a modular, machine-aware "Grand Unified" configuration.

## ✨ Features

- **Modular Architecture**: Plugin configurations are isolated in `lua/plugins/*.lua`.
- **Native-First**: Leverages Neovim 0.12's built-in `vim.pack` for plugin management and native LSP/Autocomplete improvements.
- **Runtime-Aware LSP**: Automatically detects available language runtimes (Go, Node, Python) and only installs corresponding LSP tools, preventing errors on minimal systems.
- **Ergonomic Dashboard**: Includes `pack-manager.nvim` to provide a polished, Lazy-like UI on top of native primitives.
- **Machine Awareness**: Built-in hostname detection in `init.lua` for machine-specific overrides.
- **Version Pinning**: Uses `nvim-pack-lock.json` for reproducible environments across all your hardware.

## 🚀 Quick Start

### 1. Prerequisites

Ensure you are running **Neovim 0.12+** (nightly or latest stable). You will also need:
- `git`, `make`, `unzip`, `gcc`
- `tree-sitter-cli` (Arch: `pacman -S tree-sitter-cli` | Others: `cargo install tree-sitter-cli`)
- [ripgrep](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd)
- A [Nerd Font](https://www.nerdfonts.com/) (recommended)

### 2. Installation

```sh
# Clone your fork (replace <your_username> with your GitHub handle)
git clone https://github.com/<your_username>/whipsmart.nvim.git ~/.config/nvim

# Start Neovim — plugins install automatically on first launch
nvim
```

On first launch, Mason will install the default LSP servers and formatters for the runtimes it detects on your system (e.g., Go, Node.js, Python). Once complete, verify your environment:

```vim
:checkhealth whipsmart
```

> **Tip:** Whipsmart is "runtime-aware." If you install a new language later (e.g., via `mise` or `asdf`), simply restart Neovim or run `:MasonToolsInstall` to pick up the corresponding tools automatically.

### 3. Register Your Machine

Open `init.lua` and add a branch for your hostname in the **Machine Specific Setup** block:

```lua
local hostname = vim.uv.os_gethostname()
if hostname == 'vera' then
  -- existing machine
elseif hostname == 'your-hostname' then
  -- machine-specific overrides (font size, LSP servers, etc.)
end
```

Also add the machine to the list in `UNIFIED.md` under **Machine Detection**. Then push so the other machines stay in sync.

## 🛠️ Package Management

Whipsmart provides two ways to manage your plugins:

### The "Lazy" Way (High-Level UI)
Press **`<leader>pm`** to open the **Package Manager Menu**. This dashboard allows you to:
- Check for updates
- Install new plugins
- Disable/Enable existing plugins
- Clean up unused packages

### The "Native" Way (Low-Level Access)
Whipsmart also exposes the raw `vim.pack` primitives:
- **`<leader>ps`**: **Sync** (`vim.pack.update()` — move plugins to the newest revision matching
  each spec's `version`, then rewrite the lockfile).
- **`<leader>pr`**: **Restore** (`vim.pack.update(nil, { target = 'lockfile' })` — move plugins to
  the revisions recorded in the lockfile. Use after pulling this config on another machine, or to
  revert a bad update).
- **`<leader>pi`**: **Inspect** (View current plugin status offline).
- **`:lua vim.pack.del { 'name' }`**: Remove a plugin from disk and from the lockfile. Removing a
  plugin's config leaves it on disk as *inactive* — see [CLAUDE.md](CLAUDE.md) under *Removing a
  plugin* for how to list orphans before deleting them.
- **`:w`**: Inside the update buffer, write to disk to apply changes. Then `:restart` to load the
  new plugin code.

Inside the update buffer, `gra` offers per-plugin code actions (update / skip / delete), `K` shows
details for the change under the cursor, `gO` lists the buffer structure, and `]]` / `[[` jump
between plugin sections.

### 🔒 Managing `nvim-pack-lock.json` Across Machines
Whipsmart tracks `nvim-pack-lock.json` to ensure reproducible environments. When you update plugins locally, the lockfile changes should be committed and pushed to keep all your machines in sync.

When pulling changes from upstream:
- If you have local lockfile changes you want to keep, commit them first before pulling.
- If you want to discard your local lockfile updates and accept the remote version:
```sh
git restore nvim-pack-lock.json
git pull
```

After pulling a lockfile someone else updated, run **`<leader>pr`** — not `<leader>ps`, which would
fetch the newest revisions and overwrite the lockfile you just pulled.

See [CLAUDE.md](CLAUDE.md) for full details on managing lockfile workflows and resolving conflicts.

## 🏗️ Project Layout

```text
~/.config/nvim/
├── init.lua                # Core options, keymaps, and plugin loader
├── UNIFIED.md              # The Grand Unified roadmap and local instructions
├── nvim-pack-lock.json     # Plugin lockfile (Tracked in Git)
└── lua/
    ├── plugins/            # Core plugin modules (explicit load order in init.lua)
    │   ├── pack_manager.lua # pack-manager.nvim UI setup
    │   ├── core_ui.lua     # Which-key, Colorscheme, Oil, Mini.nvim
    │   ├── telescope.lua   # Fuzzy Finding
    │   ├── lsp.lua         # LSP, Mason, and Tooling
    │   ├── cmp.lua         # Autocompletion and Snippets
    │   ├── treesitter.lua  # Syntax Highlighting
    │   ├── format.lua      # Conform.nvim Formatting
    │   └── python_tools.lua # Python indent/tooling
    ├── whipsmart/
    │   ├── health.lua      # :checkhealth whipsmart
    │   └── plugins/        # Opt-in extras (not loaded by default):
    │                       #   debug, lint, markdown, neo-tree
    └── custom/
        └── plugins/        # Your personal plugins — no merge conflicts here
```

## 💻 Customization

### Adding a Personal Plugin
Drop a `.lua` file in `lua/custom/plugins/` — it is loaded automatically on startup and will never conflict with upstream changes.

Example `lua/custom/plugins/harpoon.lua`:
```lua
vim.pack.add { 'https://github.com/ThePrimeagen/harpoon' }
require('harpoon').setup {}
```

### Adding a Core Plugin
To add a plugin to the core `lua/plugins/` layer, create the file and then register it in the explicit loader list in `init.lua` (Section 2):

```lua
for _, mod in ipairs {
  ...
  'plugins.my_new_plugin',  -- add here
} do
```

### Adding LSP Servers
LSP configuration lives in `lua/plugins/lsp.lua` and has two separate lists that must both be updated:

1. **`servers`** — uses **lspconfig names** (passed to `vim.lsp.config` / `vim.lsp.enable`):
   ```lua
   local servers = {
     lua_ls = { ... },   -- lspconfig name
     pyright = {},       -- lspconfig name
   }
   ```

2. **`mason_tools`** — uses **Mason registry names** (passed to `mason-tool-installer`):
   ```lua
   local mason_tools = {
     'lua-language-server',  -- Mason name for lua_ls
     'pyright',              -- Mason name (happens to match here)
     'stylua',               -- formatter, Mason name
   }
   ```

> **Note:** lspconfig names and Mason names often differ. Look up the correct Mason name at [mason-registry](https://mason-registry.dev/registry/list) and the lspconfig name in the [lspconfig server list](https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md).

### Format-on-Save
Format-on-save is **on for every filetype** — there is nothing to opt into. `lua/plugins/format.lua` sets:

```lua
format_on_save = { timeout_ms = 1000, lsp_format = 'fallback' },
```

`lsp_format = 'fallback'` means a buffer with no entry in `formatters_by_ft` is still formatted by its
language server, if one is attached. To add a dedicated formatter for a filetype, add it to
`formatters_by_ft` (and to `mason_tools` in `lsp.lua` if it needs installing).

To turn it off — globally, per buffer, or per filetype — swap the table for a function; conform skips
the save-format when it returns `nil`:

```lua
format_on_save = function(bufnr)
  if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
  return { timeout_ms = 1000, lsp_format = 'fallback' }
end,
```

### Machine-Specific Settings
Whipsmart uses hostname detection. Open `init.lua` and locate the **Machine Specific Setup** section to add overrides for your specific hardware.

## 📜 Credits
Whipsmart started as a fork of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) and maintains its spirit of being a starting point rather than a distribution.
