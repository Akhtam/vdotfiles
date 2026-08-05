-- lua/ak/plugins/tmux.lua
--
-- Seamless <C-h/j/k/l> movement between Neovim splits and tmux panes.
--
-- This is one half of a PAIRED plugin. The other half is already installed on
-- the tmux side via TPM (~/.tmux/plugins/vim-tmux-navigator, declared in
-- ~/.dotfiles/.tmux.conf). Both halves ship from the same repo, so they stay
-- version-matched.
--
-- How it works, in one paragraph, because the behaviour is otherwise mystifying:
-- tmux binds C-h/j/k/l globally and, on each press, runs a `ps` check on the
-- pane's tty to decide whether the pane is running (n)vim. If it is, tmux
-- FORWARDS the keystroke instead of switching panes. Neovim then tries
-- `wincmd h`; if the window number didn't change, it was already at the edge,
-- so it shells out to `tmux select-pane -L`. That is the entire protocol.
--
-- Practical consequence: if <C-h> ever stops switching, the `ps`-based
-- detection misfired. `:TmuxNavigatorProcessList` shows tmux exactly what it
-- sees, which is the fastest way to diagnose it.

-- ── Options ────────────────────────────────────────────────────────────────
-- These are read by the plugin's plugin/ file at source time. Setting them
-- here works because vim.pack defers plugin/ sourcing until after init.lua
-- finishes — the same timing that makes the netrw flags in nvim_tree.lua work.

-- Your `disable_when_zoomed = true`. When a tmux pane is zoomed, don't
-- navigate out of it — zoom means "I want only this pane", and silently
-- leaving it is disorienting.
vim.g.tmux_navigator_disable_when_zoomed = 1

-- Write the current buffer when leaving Neovim for a tmux pane.
--
-- Worth having in your workflow specifically: you jump to a pane to run
-- `bin/rspec` or `pnpm test` against the file you just edited, and without
-- this you'd be running the previous version of it. 1 = write the current
-- buffer; 2 = :wall (write every modified buffer).
--
-- Note this is one of the options alexghergh's rewrite doesn't expose.
vim.g.tmux_navigator_save_on_switch = 1

-- Don't wrap around from the rightmost pane to the leftmost. Wrapping means a
-- <C-l> too many teleports you across the screen instead of doing nothing.
vim.g.tmux_navigator_no_wrap = 1

-- Define our own mappings rather than take the plugin's defaults. The defaults
-- are the same four keys plus <C-\> for "previous pane"; being explicit means
-- every key this config binds is greppable in lua/ak/.
vim.g.tmux_navigator_no_mappings = 1

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- These REPLACE the four plain <C-w>h/j/k/l maps that were in keymaps.lua.
-- They're a strict superset: identical behaviour between Neovim splits, and
-- they additionally fall through to tmux panes at the edge.
local map = vim.keymap.set

map('n', '<C-h>', '<cmd>TmuxNavigateLeft<CR>', { desc = 'Navigate left (split or tmux pane)' })
map('n', '<C-j>', '<cmd>TmuxNavigateDown<CR>', { desc = 'Navigate down (split or tmux pane)' })
map('n', '<C-k>', '<cmd>TmuxNavigateUp<CR>', { desc = 'Navigate up (split or tmux pane)' })
map('n', '<C-l>', '<cmd>TmuxNavigateRight<CR>', { desc = 'Navigate right (split or tmux pane)' })

-- No conflicts with these, checked:
--   blink.cmp binds <C-h>/<C-l> for snippet jumps — INSERT mode only.
--   telescope binds <C-h> to file_split — buffer-local inside the picker,
--   which correctly shadows navigation while a picker is open.
