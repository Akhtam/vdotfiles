-- lua/ak/plugins/whichkey.lua
--
-- Shows a popup of possible completions after a partial keymap. With the
-- number of <leader> groups this config now has (f, e, d, t, s, n, m, T),
-- it's the difference between remembering them and rediscovering them.

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
  { '<leader>f', group = 'find (telescope)' },
  { '<leader>e', group = 'explorer (nvim-tree)' },
  { '<leader>d', group = 'diagnostics' },
  { '<leader>t', group = 'tabs' },
  { '<leader>s', group = 'splits' },
  { '<leader>n', group = 'noice / numbers' },
  { '<leader>m', group = 'format' },
  { '<leader>T', group = 'test (neotest)' },
  { '<leader>g', group = 'git' },
  { '<leader>w', group = 'workspace' },
})

-- Yours, verbatim: show only the keymaps local to the current buffer. Useful
-- for seeing what LSP added on attach, which varies by filetype.
vim.keymap.set('n', '<leader>?', function()
  require('which-key').show({ global = false })
end, { desc = 'Buffer Local Keymaps (which-key)' })
