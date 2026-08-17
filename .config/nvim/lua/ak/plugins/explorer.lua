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
local function toggle_explorer()
  local existing = Snacks.picker.get({ source = 'explorer' })[1]
  if existing then
    existing:close()
  else
    Snacks.explorer()
  end
end

--- Reveal the current buffer's file, opening the explorer first if needed.
--- `Snacks.explorer.reveal()` handles both cases itself.
local function reveal_in_explorer()
  Snacks.explorer.reveal()
end

vim.keymap.set('n', '<leader>ee', toggle_explorer, { desc = 'Toggle file explorer' })
vim.keymap.set('n', '<leader>ef', reveal_in_explorer, { desc = 'Toggle file explorer on current file' })
