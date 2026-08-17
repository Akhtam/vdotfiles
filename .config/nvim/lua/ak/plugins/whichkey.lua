-- lua/ak/plugins/whichkey.lua
--
-- Shows a popup of possible completions after a partial keymap. With the
-- number of <leader> groups this config now has — fourteen, listed in the
-- add() call below — it's the difference between remembering them and
-- rediscovering them.

require('which-key').setup({
  -- Defaults are good. Group labels are added below rather than here, so they
  -- live next to the maps they describe.
})

-- ── timeoutlen ─────────────────────────────────────────────────────────────
-- Your config set `vim.o.timeout = true` and `vim.o.timeoutlen = 500` in an
-- `init` block. Both now live in options.lua instead — one source of truth, so
-- there's no question which file wins.
--
-- 'timeout' is already on by default. 'timeoutlen' was 300 in options.lua and
-- is now 500, per your config: which-key's popup only appears once the timeout
-- elapses, so a short value makes it flash open before you've finished typing
-- a two-key sequence you already know.

-- ── Group labels ───────────────────────────────────────────────────────────
-- Without these the popup shows bare prefixes; with them it names each group.
require('which-key').add({
  { '<leader>f', group = 'find (picker)' },
  { '<leader>e', group = 'explorer (snacks)' },
  -- <leader>d is debug, NOT diagnostics — diagnostics moved to <leader>x when
  -- nvim-dap arrived and wanted the conventional prefix. See the note in
  -- diagnostics.lua explaining the move.
  { '<leader>d', group = 'debug (dap)' },
  { '<leader>x', group = 'diagnostics' },
  { '<leader>T', group = 'tabs' },
  { '<leader>s', group = 'splits' },
  { '<leader>n', group = 'noice / numbers' },
  { '<leader>m', group = 'format' },
  { '<leader>t', group = 'test (neotest)' },
  { '<leader>g', group = 'git' },
  { '<leader>h', group = 'hunks (gitsigns)' },
  { '<leader>l', group = 'lazygit' },
  { '<leader>w', group = 'workspace' },
  { '<leader>u', group = 'ui' },
})

-- Yours, verbatim: show only the keymaps local to the current buffer. Useful
-- for seeing what LSP added on attach, which varies by filetype.
vim.keymap.set('n', '<leader>?', function()
  require('which-key').show({ global = false })
end, { desc = 'Buffer Local Keymaps (which-key)' })
