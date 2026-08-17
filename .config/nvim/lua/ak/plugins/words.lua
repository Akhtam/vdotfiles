-- lua/ak/plugins/words.lua
--
-- Jump between LSP references of the symbol under the cursor. The highlighting
-- is passive and configured in plugins/snacks.lua; this file is only the
-- navigation keymaps.
--
-- `]]`/`[[` are unbound by default — the built-in `]`/`[` family covers
-- diagnostics and folds, not references. vim.v.count1 makes a count prefix
-- work (`3]]`), matching the built-in ]d/[d convention.

local map = vim.keymap.set

map('n', ']]', function()
  Snacks.words.jump(vim.v.count1)
end, { noremap = true, silent = true, desc = 'Next reference' })

map('n', '[[', function()
  Snacks.words.jump(-vim.v.count1)
end, { noremap = true, silent = true, desc = 'Prev reference' })
