-- lua/ak/plugins/explorer.lua
--
-- Replaces nvim-tree with snacks.nvim's `explorer` — "a file explorer (picker
-- in disguise)" per its own doc comment: same tree UI, but built on the
-- picker machinery, so it gets fuzzy-filtering, git status, and diagnostics
-- for free instead of needing separate plugins wired in.
--
-- Module config lives in plugins/snacks.lua (general `explorer` settings plus
-- the `explorer` picker source under `picker.sources`), same split as every
-- other snacks module here. This file only does two things: `mini.icons`
-- setup (moved from the old nvim_tree.lua — `MiniIcons` is a global, so it
-- doesn't matter which file calls `.setup()`, but explorer is now its main
-- consumer) and the <leader>ee/<leader>ef keymaps.

require('mini.icons').setup()
require('mini.icons').mock_nvim_web_devicons()

-- ── netrw ──────────────────────────────────────────────────────────────────
-- nvim-tree needed `vim.g.loaded_netrw = 1` set by hand. The explorer module
-- does this itself (`replace_netrw = true`, the default — see snacks.lua),
-- via an autocmd rather than a startup flag, so nothing to do here.

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- nvim-tree's <leader>ee/ef restored as-is; ec/er are dropped because the
-- explorer doesn't need them:
--   ec  collapse  -> 'Z' inside the explorer (explorer_close_all)
--   er  refresh   -> `watch = true` (default) auto-refreshes on filesystem
--                    changes; 'u' inside forces one

--- ee: toggle. Close the explorer if one's open on this tab, otherwise open
--- it. `Snacks.explorer()` alone has no such toggle — calling it again just
--- refocuses/reopens, so the close-if-open check has to happen out here.
local function toggle_explorer()
  local existing = Snacks.picker.get({ source = 'explorer' })[1]
  if existing then
    existing:close()
  else
    Snacks.explorer()
  end
end

--- ef: open (if closed) and reveal the current buffer's file; if already
--- open, just reveal it there without closing. `Snacks.explorer.reveal()`
--- handles both cases itself — see snacks/explorer/init.lua's `M.reveal`.
local function reveal_in_explorer()
  Snacks.explorer.reveal()
end

vim.keymap.set('n', '<leader>ee', toggle_explorer, { desc = 'Toggle file explorer' })
vim.keymap.set('n', '<leader>ef', reveal_in_explorer, { desc = 'Toggle file explorer on current file' })
