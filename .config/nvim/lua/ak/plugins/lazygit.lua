-- lua/ak/plugins/lazygit.lua
--
-- The `lazygit` TUI in a floating window, sharing the buffer's repo and cwd.
--
-- The plugin is a thin wrapper: it opens a terminal buffer in a float and runs
-- the lazygit binary in it. Everything you see inside the window is lazygit
-- itself (0.64.0, installed via Homebrew), so its own config at
-- ~/Library/Application Support/lazygit/config.yml still applies.
--
-- Complements gitsigns rather than overlapping with it: gitsigns is per-hunk
-- work inside the buffer you're editing (<leader>h…), lazygit is repo-level
-- work — staging across files, branches, rebases, stashes, log browsing.

-- ── Options ────────────────────────────────────────────────────────────────
-- Read by the plugin at command time, not at load time, so setting them here
-- is fine regardless of when plugin/ gets sourced.

-- Window size as a fraction of the editor. The plugin's default is 0.9; 0.9
-- leaves a thin frame of your buffer visible around the edges, which is what
-- makes the float read as "on top of" the file rather than a mode switch.
vim.g.lazygit_floating_window_scaling_factor = 0.9

-- 0 = fully opaque. lazygit draws its own panel borders and colors, and any
-- transparency makes the text underneath bleed through them into mush.
vim.g.lazygit_floating_window_winblend = 0

-- Use plenary's floating window rather than the plugin's hand-rolled one.
-- plenary is already installed (telescope/neotest need it), and its
-- implementation is the better-maintained of the two.
vim.g.lazygit_floating_window_use_plenary = 1

-- NOT SET: vim.g.lazygit_use_neovim_remote. It defaults to 1 and only takes
-- effect if `nvr` (neovim-remote) is on $PATH — it exists so that lazygit's
-- "edit file" and commit-message actions open in your CURRENT nvim instead of
-- nesting a second one inside the terminal buffer. nvr isn't installed here,
-- so lazygit falls back to $EDITOR. If nested nvim ever bothers you:
--   pipx install neovim-remote
-- and it starts working with no config change.

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Your spec used lazy.nvim's `keys = {…}` table, which is a lazy-LOADING
-- declaration: it defines the map and defers the plugin until the map is hit.
-- vim.pack has no lazy-loading, so the equivalent is plain vim.keymap.set with
-- the same lhs/rhs/desc. Behaviour is identical; only startup differs, and the
-- plugin is a few hundred lines with no work at load time.
local map = vim.keymap.set

-- Repo-wide. Opens on lazygit's status panel, rooted at the current file's
-- repo (the plugin passes -p <dir>), so it works from anywhere in the tree.
map('n', '<leader>lg', '<cmd>LazyGit<cr>', { desc = 'LazyGit' })

-- Commits touching the current file only — lazygit's filtered log view. The
-- fast way to answer "when did this file last change and why".
map('n', '<leader>lc', '<cmd>LazyGitFilterCurrentFile<cr>', { desc = 'LazyGitFilterCurrentFile' })

-- Two more commands ship with the plugin and are left unbound, since you
-- didn't ask for them — :LazyGitFilter (log filtered to the cwd) and
-- :LazyGitConfig (edit lazygit's own config.yml).
