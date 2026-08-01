--[[
--
-- This file is not required for your own configuration,
-- but helps people determine if their system is setup correctly.
-- Run :checkhealth whipsmart to use it.
--
--]]

local check_version = function()
  local verstr = tostring(vim.version())
  if not vim.version.ge then
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
    return
  end

  if vim.version.ge(vim.version(), '0.12') then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
  end
end

local check_external_reqs = function()
  -- Basic utils: `git`, `make`, `unzip`
  for _, exe in ipairs { 'git', 'make', 'unzip', 'rg', 'fd' } do
    local is_executable = vim.fn.executable(exe) == 1
    if is_executable then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s'. Some features may be limited.", exe))
    end
  end

  return true
end

local check_runtimes = function()
  local runtimes = {
    { bin = 'go', name = 'Go' },
    { bin = 'node', name = 'Node.js' },
    { bin = 'python3', name = 'Python 3' },
    { bin = 'cargo', name = 'Rust/Cargo' },
    { bin = 'gcc', name = 'C Compiler' },
    { bin = 'mise', name = 'Mise (Tool Manager)' },
  }
  for _, rt in ipairs(runtimes) do
    if vim.fn.executable(rt.bin) == 1 then
      vim.health.ok(string.format('Found runtime: %s', rt.name))
    else
      vim.health.info(string.format('Optional runtime missing: %s', rt.name))
    end
  end
end

return {
  check = function()
    vim.health.start 'whipsmart.nvim'

    vim.health.info [[NOTE: Not every warning is a 'must-fix'.
    
    Whipsmart is runtime-aware: it only attempts to install LSPs for languages
    found in your PATH. Detection runs once at startup, so after installing a new
    language (e.g. via 'mise') you must restart Neovim to pick up its tools --
    :MasonToolsInstall alone will not notice it.]]

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
    check_runtimes()
  end,
}
