--- Minimal lazy-loading helpers for `vim.pack`.
---
--- `vim.pack.add` puts a plugin on the runtimepath as soon as it is called. Passing a `load`
--- callback makes the caller "fully responsible for loading" (`:help vim.pack.add`), which lets a
--- plugin be declared — installed, version-pinned, recorded in the lockfile, and still counted as
--- *active* so it is never mistaken for an orphan — without paying for it at startup.
---
--- Usage:
--- ```lua
---   local P = require('whipsmart.lazy').new({ 'https://github.com/folke/trouble.nvim' }, function()
---     require('trouble').setup {}
---   end)
---   P.cmd 'Trouble'                                          -- stub command that loads on first use
---   P.map('n', '<leader>xx', 'Trouble diagnostics toggle', {}) -- keymap that loads, then runs the Ex command
--- ```

local M = {}

--- @param specs (string|table)[] Plugin specs, as passed to `vim.pack.add`.
--- @param setup? fun() Runs once, immediately after the plugins are added to the runtimepath.
function M.new(specs, setup)
  local names = {} --- @type string[]
  vim.pack.add(specs, {
    -- Deliberately does not `packadd`: it only records the resolved names so `load` can do it
    -- later. Returning without loading is what keeps the plugin off the runtimepath.
    load = function(plug) names[#names + 1] = plug.spec.name end,
  })

  local stubs = {} --- @type string[]
  local loaded = false

  local P = {}

  --- Load the plugins now. Safe to call repeatedly; only the first call does work.
  function P.load()
    if loaded then return end
    loaded = true
    -- Drop the placeholder commands first so the real ones can take their names.
    for _, name in ipairs(stubs) do
      pcall(vim.api.nvim_del_user_command, name)
    end
    for _, name in ipairs(names) do
      vim.cmd.packadd(name)
    end
    if setup then setup() end
  end

  --- Placeholder for a command the plugin defines itself. Loads, then re-runs the real command
  --- with the original arguments, range and bang.
  --- @param name string
  --- @param opts? table Extra options for `nvim_create_user_command`.
  function P.cmd(name, opts)
    stubs[#stubs + 1] = name
    opts = vim.tbl_extend('keep', opts or {}, { nargs = '*', bang = true, range = true })
    vim.api.nvim_create_user_command(name, function(cmd)
      P.load()
      vim.cmd {
        cmd = name,
        args = cmd.fargs,
        bang = cmd.bang,
        range = cmd.range > 0 and { cmd.line1, cmd.line2 } or nil,
      }
    end, opts)
  end

  --- Keymap that loads the plugins, then performs `rhs`.
  --- @param mode string|string[]
  --- @param lhs string
  --- @param rhs string|fun() A function, or a plain **Ex command** ('Trouble diagnostics toggle').
  --- Keymap notation ('<cmd>Trouble ...<cr>') is not accepted — the rhs runs from a Lua callback,
  --- where it is executed rather than typed.
  --- @param opts? table
  function P.map(mode, lhs, rhs, opts)
    if type(rhs) == 'string' and rhs:match '^%s*<' then
      error(("whipsmart.lazy: rhs for '%s' must be an Ex command, not keymap notation: %s"):format(lhs, rhs))
    end
    vim.keymap.set(mode, lhs, function()
      P.load()
      if type(rhs) == 'function' then return rhs() end
      vim.cmd(rhs)
    end, opts)
  end

  return P
end

return M
