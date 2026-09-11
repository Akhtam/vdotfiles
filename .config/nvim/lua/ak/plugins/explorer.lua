-- lua/ak/plugins/explorer.lua
--
-- snacks.nvim's `explorer` — "a file explorer (picker in disguise)": a tree UI
-- on the picker machinery, so fuzzy-filtering, git status and diagnostics come
-- free rather than needing separate plugins.
--
-- Its actual config lives in plugins/snacks.lua (the `explorer` settings plus
-- the `explorer` picker source). This file is only mini.icons setup — a global,
-- so any file could call it, but the explorer is its main consumer — and the
-- two keymaps. netrw needs nothing here: `replace_netrw` handles it.

require('mini.icons').setup()
require('mini.icons').mock_nvim_web_devicons()

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- No collapse/refresh maps: 'Z' inside the explorer collapses, and `watch =
-- true` auto-refreshes on filesystem changes ('u' forces one).

--- Toggle: close if one is open on this tab, otherwise open. `Snacks.explorer()`
--- has no toggle of its own — calling it again just refocuses — so the
--- close-if-open check has to happen out here.
---
--- `opts` picks the layout variant; both variants are the same `explorer`
--- source (same tree, same state), so only one can be open at a time and
--- toggling either key closes whichever is currently showing.
local function toggle_explorer(opts)
  local existing = Snacks.picker.get({ source = 'explorer' })[1]
  if existing then
    existing:close()
  else
    Snacks.explorer(opts)
  end
end

--- VSCode/nvim-tree-style: a fixed-width panel pinned to the left edge
--- instead of a centred float, and it stays open after opening a file
--- (`jump.close = false`) rather than getting out of the way — the point of
--- a sidebar is that it's still there afterwards.
local sidebar_opts = {
  layout = { preset = 'left' },
  jump = { close = false },
}

vim.keymap.set('n', '<leader>ee', toggle_explorer, { desc = 'Toggle file explorer (float)' })
vim.keymap.set('n', '<leader>et', function()
  toggle_explorer(sidebar_opts)
end, { desc = 'Toggle file explorer (sidebar)' })
