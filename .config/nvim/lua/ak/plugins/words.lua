-- lua/ak/plugins/words.lua
--
-- Jump between LSP references of the symbol under the cursor. The
-- highlighting itself is passive (config in plugins/snacks.lua, `words`
-- module) — this file is only the navigation keymaps, same split as
-- lazygit.lua/explorer.lua keeping keymaps out of their module's setup call.
--
-- `]]`/`[[` were unbound (checked against `nvim --clean`: not among the
-- built-in `]`/`[` family, which is diagnostics/folds/etc., not references).
-- vim.v.count1 makes a count prefix work, e.g. `3]]` jumps 3 references
-- forward, same convention as the built-in ]d/[d.

local map = vim.keymap.set

map('n', ']]', function()
  Snacks.words.jump(vim.v.count1)
end, { noremap = true, silent = true, desc = 'Next reference' })

map('n', '[[', function()
  Snacks.words.jump(-vim.v.count1)
end, { noremap = true, silent = true, desc = 'Prev reference' })
