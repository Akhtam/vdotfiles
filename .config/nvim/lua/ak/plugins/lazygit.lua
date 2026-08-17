-- lua/ak/plugins/lazygit.lua
--
-- The `lazygit` TUI in a float, sharing the buffer's repo and cwd. From
-- snacks.nvim's `lazygit` module (config in plugins/snacks.lua); the binary
-- itself comes from Homebrew and is declared in .config/Brewfile.
--
-- Complements gitsigns rather than overlapping: gitsigns is per-hunk work in
-- the buffer you're editing (<leader>h…), lazygit is repo-level — staging
-- across files, branches, rebases, stashes, log browsing.

local map = vim.keymap.set

-- Repo-wide status panel, rooted wherever lazygit's cwd detection lands.
map('n', '<leader>lg', function()
  Snacks.lazygit()
end, { desc = 'LazyGit' })

-- Commits touching the current file only — the fast way to answer "when did
-- this file last change and why".
map('n', '<leader>lc', function()
  Snacks.lazygit.log_file()
end, { desc = 'LazyGit: current file log' })

-- Left unbound: Snacks.lazygit.log() — log filtered to cwd.
