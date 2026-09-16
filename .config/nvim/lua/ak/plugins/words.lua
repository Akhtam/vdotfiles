-- lua/ak/plugins/words.lua
--
-- Jump between LSP references of the symbol under the cursor. The highlighting
-- is passive and configured in plugins/snacks.lua; this file is only the
-- navigation keymaps.
--
-- `]]`/`[[` override the built-in section motions (`:h ]]`), which mean
-- little outside C-style code. In :terminal buffers core's buffer-local
-- prompt jumps still win over these global maps. vim.v.count1 makes a count prefix
-- work (`3]]`), matching the built-in ]d/[d convention.

local map = vim.keymap.set

map('n', ']]', function()
  Snacks.words.jump(vim.v.count1)
end, { silent = true, desc = 'Next reference' })

map('n', '[[', function()
  Snacks.words.jump(-vim.v.count1)
end, { silent = true, desc = 'Prev reference' })
