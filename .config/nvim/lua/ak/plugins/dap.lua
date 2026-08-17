-- lua/ak/plugins/dap.lua
--
-- Breakpoints and stepping for the two stacks this config supports elsewhere:
-- Node/TypeScript (lsp/vtsls.lua) and Ruby (lsp/ruby_lsp.lua).
--
-- Four plugins, one file, because they are one feature and each spec entry
-- names this module:
--   nvim-dap                the client and DAP protocol implementation
--   nvim-dap-ui             the panes (scopes, stacks, breakpoints, repl)
--   nvim-dap-virtual-text   variable values inline at end-of-line
--   nvim-dap-ruby           the rdbg adapter + ruby configurations
--
-- ── The vocabulary, once ───────────────────────────────────────────────────
-- ADAPTER = how to start/reach a debugger process, keyed by `type`.
-- CONFIGURATION = what to debug, keyed by filetype; its `type` picks the adapter.
--
-- Both failure modes are quiet: a configuration whose `type` has no adapter
-- fails with a terse message, and a filetype with no configurations silently
-- offers nothing when <leader>dc opens the picker.

local dap = require('dap')
local dapui = require('dapui')

-- ── js-debug ───────────────────────────────────────────────────────────────
-- vscode-js-debug is the debugger VS Code uses for JavaScript, and it has NO
-- package: no Homebrew formula/cask/tap, and @vscode/js-debug,
-- vscode-js-debug and js-debug-adapter all 404 on npm (an unrelated
-- js-debug@0.1.1 squats the bare name). Microsoft ships a .vsix plus one
-- standalone tarball per release and defers install mechanics to the editor.
--
-- Installing that tarball is the only thing mason would have done here, and
-- every other tool in this config comes from brew, pnpm or asdf on $PATH — one
-- curl is cheaper than a second package manager. Pinned rather than "latest" so
-- a fresh machine gets the version this was tested against.
local JS_DEBUG_VERSION = '1.117.0'
local js_debug_root = vim.fs.joinpath(vim.fn.stdpath('data'), 'js-debug')

-- VERSION-SCOPED, which is what makes the constant above a real pin: bump it and
-- the path no longer exists, so the "run :DapJsDebugInstall" branch fires and
-- the bump announces itself.
--
-- Unscoped, the constant would govern only what gets DOWNLOADED, never what gets
-- LOADED — find_dap_server() asks whether dapDebugServer.js exists, not whether
-- it is 1.117.0. You would bump, restart, and keep debugging the old tree with
-- nothing to tell you, since the extracted tree carries no version marker.
local js_debug = vim.fs.joinpath(js_debug_root, JS_DEBUG_VERSION)

-- Where dapDebugServer.js might live, most-preferred first. Only the first is
-- ours; the others mean an install done some other way is still found without
-- editing anything below. This function is the only place in the config where
-- the install method is visible at all.
local function find_dap_server()
  for _, path in ipairs({
    vim.fs.joinpath(js_debug, 'src', 'dapDebugServer.js'), -- :DapJsDebugInstall
    vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'js-debug-adapter', 'js-debug', 'src', 'dapDebugServer.js'),
    '/opt/homebrew/opt/js-debug/js-debug/src/dapDebugServer.js', -- if a formula ever lands
  }) do
    if vim.uv.fs_stat(path) then
      return path
    end
  end
end

-- Idempotent and deliberately DESTRUCTIVE: the whole js-debug root goes, not
-- just the target version. A re-run is then a clean reinstall rather than an
-- overlay, and old version directories don't accumulate as you upgrade.
-- Upgrading is: bump JS_DEBUG_VERSION, restart, get told it's missing, run this.
--
-- The tarball has one top-level `js-debug/`, so --strip-components=1 puts
-- src/dapDebugServer.js directly under js_debug. Piped through `sh -c` because
-- vim.system() takes an argv, and there is no pipe without a shell.
vim.api.nvim_create_user_command('DapJsDebugInstall', function()
  local url = ('https://github.com/microsoft/vscode-js-debug/releases/download/v%s/js-debug-dap-v%s.tar.gz'):format(
    JS_DEBUG_VERSION,
    JS_DEBUG_VERSION
  )
  vim.fn.delete(js_debug_root, 'rf')
  vim.fn.mkdir(js_debug, 'p')
  vim.notify('js-debug: downloading v' .. JS_DEBUG_VERSION .. '…')

  local cmd = ('curl -fsSL %s | tar -xz --strip-components=1 -C %s'):format(
    vim.fn.shellescape(url),
    vim.fn.shellescape(js_debug)
  )
  vim.system({ 'sh', '-c', cmd }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify('js-debug install failed:\n' .. (res.stderr or ''), vim.log.levels.ERROR)
        return
      end
      -- Check OUR path specifically, not find_dap_server(): that scans all three
      -- candidates, so a copy installed elsewhere would report this install as a
      -- success even when it extracted nothing usable.
      if vim.uv.fs_stat(vim.fs.joinpath(js_debug, 'src', 'dapDebugServer.js')) then
        vim.notify('js-debug v' .. JS_DEBUG_VERSION .. ' installed')
      else
        vim.notify('js-debug: extracted, but src/dapDebugServer.js is missing — archive layout changed?', vim.log.levels.WARN)
      end
    end)
  end)
end, { desc = 'Download and extract vscode-js-debug' })

-- ── The pwa-node / pwa-chrome adapter ──────────────────────────────────────
-- Both types are served by the SAME dapDebugServer.js — it multiplexes
-- vscode-js-debug's sub-debuggers and the configuration's `type` picks one, so
-- one definition registered under both names.
--
-- `pwa-` is vestigial and has nothing to do with progressive web apps, but the
-- strings must be spelled exactly this way: they are how nvim-dap matches a
-- configuration to an adapter, and neotest-jest/neotest-vitest both emit
-- `type = 'pwa-node'` so their `strategy = 'dap'` resolves here.
--
-- A FUNCTION rather than a table so the install check happens when you debug,
-- not at startup — one clear message when it matters, rather than a warning on
-- every launch. (Not for mutation safety: nvim-dap does rewrite `adapter.port`
-- and `executable.args`, but new_session deepcopies the adapter first, so a
-- plain table would also be safe.)
for _, type_name in ipairs({ 'pwa-node', 'pwa-chrome' }) do
  dap.adapters[type_name] = function(callback, _config)
    local server = find_dap_server()
    if not server then
      vim.notify('js-debug not installed — run :DapJsDebugInstall', vim.log.levels.ERROR)
      return -- no callback: nvim-dap simply doesn't start a session
    end

    callback({
      type = 'server',
      -- MUST NOT be "hardened" into 127.0.0.1. dapDebugServer.js binds IPv6
      -- loopback ONLY. Measured against v1.117.0: 127.0.0.1 is REFUSED, ::1
      -- connects. nvim-dap's own default host is 127.0.0.1, hence setting this.
      --
      -- '::1' rather than the wiki's 'localhost' because nvim-dap does NOT try
      -- each resolved address — it takes addresses[1] and its retry loop reuses
      -- the same list, hammering one address up to 14 times. 'localhost' works
      -- only while getaddrinfo returns ::1 first, and the failure mode is a bare
      -- connect error after ~3.5s with nothing pointing at name resolution.
      --
      -- If a future js-debug binds IPv4, its startup log names the address and
      -- this is the line to change.
      host = '::1',
      port = '${port}', -- literal: nvim-dap swaps in a free port, see above
      executable = {
        command = 'node',
        args = { server, '${port}' },
      },
    })
  end
end

-- ── JavaScript / TypeScript configurations ─────────────────────────────────
-- Shared by all four filetypes. Applied in a loop rather than written out four
-- times so they can't drift — the same reason lsp.lua has one '*' block.
local js_config = {
  {
    type = 'pwa-node',
    request = 'launch',
    name = 'Launch current file',
    program = '${file}',
    cwd = '${workspaceFolder}',
    -- No tsx/ts-node wrapper, deliberately: Node strips TypeScript types
    -- natively (default since 23.6; this machine runs 26.x), so `node foo.ts`
    -- works. Configs that set runtimeExecutable to a tsx shim predate that.
    --
    -- Stripping ERASES types rather than checking them, and TS syntax needing
    -- codegen (enums, namespaces, decorators, parameter properties) still
    -- fails. vtsls type-checks; this only runs the file.
  },
  {
    type = 'pwa-node',
    request = 'attach',
    name = 'Attach to process',
    processId = require('dap.utils').pick_process,
    cwd = '${workspaceFolder}',
  },
  {
    type = 'pwa-node',
    request = 'attach',
    name = 'Attach to port 9229',
    -- For a process already started with --inspect: a dev server, a container,
    -- anything you didn't launch from here. 9229 is Node's default.
    address = '127.0.0.1',
    port = 9229,
    cwd = '${workspaceFolder}',
  },
  {
    type = 'pwa-chrome',
    request = 'launch',
    name = 'Launch Chrome (localhost:3000)',
    url = 'http://localhost:3000',
    -- Maps URLs the browser reports back to files on disk. Wrong webRoot is the
    -- usual cause of "breakpoint set but never hit" in browser debugging: the
    -- breakpoint lands in a file the debugger can't match to the served source.
    webRoot = '${workspaceFolder}',
  },
  {
    type = 'pwa-chrome',
    request = 'attach',
    name = 'Attach to Chrome (port 9222)',
    -- Needs a browser started with --remote-debugging-port=9222. Attaching
    -- keeps your real profile and open tabs, which launching does not.
    port = 9222,
    webRoot = '${workspaceFolder}',
  },
}

-- Applied to every config above rather than repeated in each.
for _, config in ipairs(js_config) do
  config.sourceMaps = true
  -- Without this, a single step into any library call drops you into bundled or
  -- transpiled vendor code and you spend the session stepping back out.
  config.skipFiles = { '<node_internals>/**', '**/node_modules/**' }
end

for _, ft in ipairs({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }) do
  dap.configurations[ft] = js_config
end

-- ── Ruby ───────────────────────────────────────────────────────────────────
-- One call supplying both adapter and configurations: debug current file, rails,
-- rspec (file / file:line / all), minitest, bin/dev, and two attach entries. It
-- drives `rdbg` from the `debug` gem, already on $PATH via asdf, so unlike
-- js-debug there is nothing to download.
--
-- Kept rather than hand-rolled because neotest-rspec's dap strategy is written
-- against THIS plugin's private config keys — error_on_failure, random_port,
-- current_line, waiting — which mean nothing to any other ruby adapter.
--
-- NOTE setup() ASSIGNS dap.configurations.ruby rather than extending it, so
-- additions must come after this line.
require('dap-ruby').setup()

-- Expect one EXTRA stop in Ruby: rdbg halts at program entry, so the first stop
-- is `reason = 'pause'` on line 1, not your breakpoint. Continue once and it
-- runs on to the real one. This is rdbg's behaviour, and it does NOT happen with
-- js-debug — worth knowing, because "it stopped on the wrong line" is otherwise
-- the first thing you'd go debug.

-- ── UI ─────────────────────────────────────────────────────────────────────
dapui.setup()

-- Variable values inline at end of line while stopped. `eol` rather than the
-- default inline position so values don't shift the code horizontally as you
-- step — same reasoning as diagnostics keeping virtual_lines off by default.
require('nvim-dap-virtual-text').setup({ virt_text_pos = 'eol' })

-- Open the panes when a session actually starts, not when this file loads.
-- Keys are namespaced 'ak_dapui' because listeners are a shared table — an
-- unnamespaced key would collide with any other listener on the same event.
dap.listeners.after.event_initialized['ak_dapui'] = function()
  dapui.open()
end

-- Close on session end. Remove these two if you'd rather read the final scopes
-- and stack after the program exits — <leader>du toggles the panes either way,
-- so nothing is lost except the automatic tidy-up.
dap.listeners.before.event_terminated['ak_dapui'] = function()
  dapui.close()
end
dap.listeners.before.event_exited['ak_dapui'] = function()
  dapui.close()
end

-- ── Gutter signs ───────────────────────────────────────────────────────────
-- Replacing nvim-dap's unstyled `B` and `→`, which read as text rather than
-- state. Standard-Unicode geometric shapes, NOT nerd-font private-use glyphs,
-- so they render in any font — the same constraint diagnostics.lua sets.
--
-- Colours borrow the Diagnostic* groups so the sign column reads as one
-- vocabulary across gitsigns, diagnostics, neotest and breakpoints:
-- filled/red means stop, hollow means won't.
for name, sign in pairs({
  DapBreakpoint = { '●', 'DiagnosticError' },
  DapBreakpointCondition = { '◆', 'DiagnosticWarn' },
  DapLogPoint = { '■', 'DiagnosticInfo' },
  -- Rejected = the adapter could not bind it (no source map, line isn't
  -- executable). Hollow, because it looks like a breakpoint but isn't one.
  DapBreakpointRejected = { '○', 'DiagnosticHint' },
}) do
  vim.fn.sign_define(name, { text = sign[1], texthl = sign[2], numhl = '' })
end

-- The stopped line gets a line highlight as well as a sign: when execution
-- halts, where you are matters more than any other information on screen.
vim.fn.sign_define('DapStopped', {
  text = '▶',
  texthl = 'DiagnosticWarn',
  linehl = 'Visual',
  numhl = 'DiagnosticWarn',
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- <leader>d is DEBUG here; diagnostics moved to <leader>x to free it.
--
-- Stepping is deliberately NOT under <leader>d: you press step-over thirty
-- times in a row, and a <leader> sequence pays the 500ms 'timeoutlen'
-- (options.lua) every press. Chords have no timeout.
--
-- NOT the F-keys either, despite F5/F10/F11/F12 being the VS Code convention:
-- macOS has com.apple.keyboard.fnState = 0 here, so bare F10/F11/F12 are
-- volume/mute and never reach the terminal.
--
-- Left Option sends Alt (ghostty: macos-option-as-alt = left). h/j/k/l avoided
-- — mux.lua owns <M-h/j/k/l> for pane navigation.
-- Mnemonic: (c)ontinue, step (o)ver, step (i)nto, step o(u)t.
local function map(lhs, rhs, desc, mode)
  vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc })
end

map('<leader>db', dap.toggle_breakpoint, 'Toggle breakpoint')

-- A breakpoint that only fires when the expression is true — the difference
-- between debugging iteration 4000 and pressing continue 4000 times.
map('<leader>dB', function()
  vim.ui.input({ prompt = 'Breakpoint condition: ' }, function(cond)
    if cond and cond ~= '' then
      dap.set_breakpoint(cond)
    end
  end)
end, 'Conditional breakpoint')

-- Starts a session (showing the configuration picker) when none is running,
-- resumes when one is. One key for both because that's how it reads in use.
map('<leader>dc', dap.continue, 'Continue / start')
map('<leader>dC', dap.run_to_cursor, 'Run to cursor')
map('<leader>dr', dap.repl.toggle, 'Toggle REPL')
map('<leader>dl', dap.run_last, 'Run last configuration')
map('<leader>du', dapui.toggle, 'Toggle debug UI')
map('<leader>dt', dap.terminate, 'Terminate session')

-- Evaluate under the cursor, or the visual selection — which is the one that
-- matters for anything more complex than a bare identifier.
map('<leader>de', function()
  dapui.eval(nil, { enter = true })
end, 'Eval expression', { 'n', 'v' })

map('<M-c>', dap.continue, 'Continue / start')
map('<M-o>', dap.step_over, 'Step over')
map('<M-i>', dap.step_into, 'Step into')
map('<M-u>', dap.step_out, 'Step out')
