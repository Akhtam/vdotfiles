-- lua/ak/plugins/neotest.lua
--
-- Run tests from inside the buffer: sign-column pass/fail, output without
-- leaving Neovim, rerun the last test without retyping anything.
--
-- Three language adapters, one per stack this config's LSPs already cover
-- (see lsp/ruby_lsp.lua, lsp/eslint.lua):
--   neotest-rspec   Ruby/RSpec
--   neotest-jest    Jest
--   neotest-vitest  Vitest
--
-- jest and vitest both claim `*.test.{js,ts,jsx,tsx}`, which looks like a
-- conflict but isn't: each adapter's `root()` walks up for ITS OWN config and
-- returns nil otherwise, and neotest skips any adapter with a nil root. Only
-- one activates per project, so both can stay loaded.
--
-- All three need a treesitter PARSER to locate test blocks — ruby, javascript,
-- typescript and tsx come from the list in lua/ak/treesitter.lua.
--
-- <leader>td runs the nearest test under `strategy = 'dap'`, which resolves
-- through plugins/dap.lua. Which adapter each lands on is invisible from either
-- file and mismatches fail quietly:
--
--   neotest-jest    type = 'pwa-node' -> js-debug
--   neotest-vitest  type = 'pwa-node' -> js-debug
--   neotest-rspec   type = 'ruby'     -> rdbg
--
-- That last one is why nvim-dap-ruby isn't hand-rolled: neotest-rspec passes
-- that plugin's own config keys, which no other ruby adapter understands.
-- <leader>td therefore exercises both adapter families and is the best single
-- check that plugins/dap.lua is correct.

require('neotest').setup({
  adapters = {
    require('neotest-rspec'),
    require('neotest-jest'),
    require('neotest-vitest'),
  },

  -- Pass/fail markers in the sign column and at end-of-line, same spot
  -- gitsigns and diagnostics already draw in — one gutter to read for git,
  -- lint, and test state together.
  status = {
    virtual_text = true,
    signs = true,
  },

  -- Quickfix populated with failures after a run, off by default so a green
  -- run doesn't clear whatever quickfix list you were already using (lint
  -- results, a grep, LSP references).
  quickfix = {
    enabled = false,
  },
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- These claim the whole <leader>t namespace; tabs live under <leader>T in
-- keymaps.lua so they don't collide. Letters mirror LazyVim's neotest keymap
-- scheme, so muscle memory transfers if you've used neotest anywhere else.
local function map(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

map('<leader>tt', function()
  require('neotest').run.run()
end, 'Run nearest test')

-- Same nearest-test resolution as <leader>tt, but under the debugger. Opt-in
-- per invocation rather than a mode, so the plain maps stay fast.
map('<leader>td', function()
  require('neotest').run.run({ strategy = 'dap' })
end, 'Debug nearest test')

map('<leader>tf', function()
  require('neotest').run.run(vim.fn.expand('%'))
end, 'Run current file')

map('<leader>tl', function()
  require('neotest').run.run_last()
end, 'Run last test')

map('<leader>tS', function()
  require('neotest').run.stop()
end, 'Stop test')

-- Tree view of every test in the project and its last-known status. Persists
-- across runs, updates live.
map('<leader>ts', function()
  require('neotest').summary.toggle()
end, 'Toggle summary')

-- Float with the output of the test under the cursor.
map('<leader>to', function()
  require('neotest').output.open({ enter = true })
end, 'Show output (nearest)')

-- Bottom panel, streams output as tests run rather than showing it after the
-- fact — useful for a slow suite where you want to watch progress.
map('<leader>tO', function()
  require('neotest').output_panel.toggle()
end, 'Toggle output panel')

-- Reruns the current file's tests on every save. Off by default per file;
-- toggle it on while you're iterating on one spec, off again when you're done
-- so an unrelated save elsewhere doesn't trigger it.
map('<leader>tw', function()
  require('neotest').watch.toggle(vim.fn.expand('%'))
end, 'Toggle watch (current file)')
