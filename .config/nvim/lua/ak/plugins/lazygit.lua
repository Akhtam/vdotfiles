-- lua/ak/plugins/lazygit.lua
--
-- The `lazygit` TUI in a floating window, sharing the buffer's repo and cwd.
-- Provided by snacks.nvim's `lazygit` module (config in plugins/snacks.lua),
-- which replaced kdheepak/lazygit.nvim — same idea (a thin float around the
-- `lazygit` binary, installed via Homebrew and declared in .config/Brewfile),
-- just built on snacks.terminal instead of plenary's floating window.
--
-- Complements gitsigns rather than overlapping with it: gitsigns is per-hunk
-- work inside the buffer you're editing (<leader>h…), lazygit is repo-level
-- work — staging across files, branches, rebases, stashes, log browsing.

local map = vim.keymap.set

-- Repo-wide status panel, rooted whenever lazygit's own cwd detection lands —
-- same as the old `:LazyGit`.
map('n', '<leader>lg', function()
  Snacks.lazygit()
end, { desc = 'LazyGit' })

-- Commits touching the current file only — lazygit's filtered log view,
-- equivalent to the old `:LazyGitFilterCurrentFile`. The fast way to answer
-- "when did this file last change and why".
map('n', '<leader>lc', function()
  Snacks.lazygit.log_file()
end, { desc = 'LazyGit: current file log' })

-- Also available and left unbound, since you didn't ask for them:
--   Snacks.lazygit.log()        log filtered to cwd (old :LazyGitFilter)
