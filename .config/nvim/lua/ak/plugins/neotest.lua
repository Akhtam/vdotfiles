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
-- jest and vitest both claim `*.test.{js,ts,jsx,tsx}` — that looks like a
-- conflict, but each adapter's `root()` walks up looking for ITS OWN config
-- (jest.config.* / a "jest" key in package.json vs. vite.config.* /
-- vitest.config.*) and returns nil when it can't find one. Neotest skips any
-- adapter whose root comes back nil, so on a Vitest project only
-- neotest-vitest activates, and vice versa. Safe to keep both loaded.
--
-- All three need a treesitter PARSER for the language to locate test blocks;
-- ruby, javascript, typescript, and tsx are installed via the list in
-- lua/ak/treesitter.lua.
--
-- NOT wired up: the `strategy = 'dap'` option that would step into a failing
-- test with a debugger. That needs lua/ak/plugins/dap.lua, which doesn't
-- exist yet (nvim-dap is on the vim.pack list but its require is commented
-- out in plugins/init.lua, same as this file was). Add `strategy = 'dap'` to
-- the run.run() calls below once that file exists.

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
