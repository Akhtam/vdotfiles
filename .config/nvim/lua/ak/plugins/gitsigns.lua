-- lua/ak/plugins/gitsigns.lua
--
-- Git decorations in the sign column, plus staging/resetting individual hunks
-- without leaving the buffer.
--
-- This also feeds the statusline: gitsigns publishes b:gitsigns_status_dict per
-- buffer, and lualine.lua's `diff_source` reads it directly rather than
-- shelling out to git a second time. So the diff counts up top and the signs in
-- the gutter can never disagree.
--
-- options.lua already sets signcolumn = 'yes', so the column is permanently
-- reserved — text never shifts sideways when the first hunk appears.

require('gitsigns').setup({
  -- Signs are left at their defaults (┃ for add/change, ▁/▔ for deletes).
  -- Two non-defaults worth having:

  -- Dimmer glyphs for staged-but-uncommitted lines. Without this, staging a
  -- hunk makes it vanish from the gutter and you lose track of what's staged —
  -- which matters given the stage/unstage keymaps below.
  signs_staged_enable = true,

  -- Untracked files show as one big add rather than nothing at all.
  attach_to_untracked = true,

  -- Inline blame OFF by default, toggled with <leader>hB: a permanent
  -- distraction when always on, useful on demand.
  current_line_blame = false,
  current_line_blame_opts = {
    -- Explicit so it does NOT inherit updatetime = 250 from options.lua; at
    -- that delay the blame text flickers as you move through a file.
    delay = 500,
    virt_text_pos = 'eol',
  },
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Deliberately NOT in gitsigns' `on_attach`: buffer-local maps would silently
-- not exist in scratch buffers or outside a repo, and `<leader>h` would appear
-- in which-key only sometimes. Global maps that no-op outside a repo are more
-- predictable, and keep every keymap greppable at module scope.
local gs = require('gitsigns')

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

-- ── Navigation ─────────────────────────────────────────────────────────────
-- ]h / [h rather than the ]c / [c in gitsigns' README: ]c and [c are built-in
-- diff-mode motions ("next/previous change"), which you'd be shadowing every
-- time you open :Gdiff or `nvim -d`. ]h / [h also lines up with the ]d / [d
-- and ]q / [q pairs already in keymaps.lua.
--
-- CHANGED from the spec you handed me: gs.next_hunk / gs.prev_hunk are marked
-- @deprecated in the installed revision (31d6fb2) in favour of nav_hunk. They
-- still work — they're one-line wrappers around exactly this call — but they
-- can disappear at any update, so the maps call the current API directly.
map('n', ']h', function()
  gs.nav_hunk('next')
end, 'Next Hunk')
map('n', '[h', function()
  gs.nav_hunk('prev')
end, 'Prev Hunk')

-- ── Actions ────────────────────────────────────────────────────────────────
map('n', '<leader>hs', gs.stage_hunk, 'Stage hunk')
map('n', '<leader>hr', gs.reset_hunk, 'Reset hunk')

-- The visual-mode variants stage/reset only the selected lines. The range is
-- { line('.'), line('v') } — cursor and selection anchor, in whichever order
-- you dragged; gitsigns sorts them itself.
map('v', '<leader>hs', function()
  gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
end, 'Stage hunk')
map('v', '<leader>hr', function()
  gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
end, 'Reset hunk')

map('n', '<leader>hS', gs.stage_buffer, 'Stage buffer')
map('n', '<leader>hR', gs.reset_buffer, 'Reset buffer')

map('n', '<leader>hp', gs.preview_hunk, 'Preview hunk')

-- full = true shows the whole commit message and body in the popup, not just
-- the one-line summary.
map('n', '<leader>hb', function()
  gs.blame_line({ full = true })
end, 'Blame line')
map('n', '<leader>hB', gs.toggle_current_line_blame, 'Toggle line blame')

-- diffthis opens a real vertical diff split against the index; with '~' it
-- diffs against the previous commit instead. Note this is where ]c / [c earn
-- their keep — see the navigation comment above.
map('n', '<leader>hd', gs.diffthis, 'Diff this')
map('n', '<leader>hD', function()
  gs.diffthis('~')
end, 'Diff this ~')

-- ── Text object ────────────────────────────────────────────────────────────
-- `ih` = "inner hunk", so `dih` deletes the hunk under the cursor and `vih`
-- selects it. The `:<C-U>` strips the '<,'> range Neovim inserts when you
-- start a command from visual mode, which the command doesn't want.
map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'Gitsigns select hunk')
