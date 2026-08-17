-- lua/ak/plugins/autosession.lua
--
-- Saves a session per working directory and restores it when you come back.
-- `cd ~/work/rails-app && nvim` reopens the buffers, splits, and tabs you left.

-- ── sessionoptions ─────────────────────────────────────────────────────────
-- A prerequisite, not a preference. The parts Neovim omits by default:
--
--   winpos, winsize     splits come back the right size
--   terminal            :terminal buffers survive
--   folds               fold state persists
--   localoptions        buffer-local settings restored — load-bearing here,
--                       since that's what re-triggers the FileType autocmds
--                       driving treesitter and LSP attach
--
-- Lives here rather than options.lua because it only affects :mksession.
vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions'

require('auto-session').setup({
  -- ── Where NOT to auto-session ────────────────────────────────────────────
  -- nvim in $HOME or / is a quick edit, not a project. Sessions there
  -- accumulate junk and restore a pile of unrelated buffers next time.
  suppressed_dirs = { '~/', '~/Downloads', '~/Desktop', '/' },

  -- ── Behaviour ────────────────────────────────────────────────────────────
  -- All three default true; stated because they're the plugin's whole contract.
  auto_save = true,
  auto_restore = true,
  auto_create = true,

  -- OFF deliberately: with this on, a `:cd` mid-session swaps sessions — so the
  -- picker or explorer changing cwd silently swaps your whole workspace.
  cwd_change_handling = false,

  -- Default true, and what makes the explorer safe here: its window isn't
  -- backed by a real file, so :mksession would restore a broken one.
  close_unsupported_windows = true,

  -- No point persisting "I opened nvim and looked at the tree".
  -- `snacks_picker_list` is the explorer's filetype (it's a picker underneath).
  bypass_save_filetypes = { 'snacks_picker_list' },

  -- Otherwise the session directory grows a file per project ever opened,
  -- including one-off clones.
  purge_after_minutes = 43200, -- 60 * 24 * 30
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Under <leader>w (workspace). NOTE lsp.lua yields <leader>ws to this file and
-- uses <leader>wy for workspace symbols — two maps under one prefix would stall
-- for 'timeoutlen'.
--
-- The :Session* commands below are the real interface. (There is also a
-- subcommand form spelled `:Autosession` with a LOWERCASE s — `:AutoSession`
-- does not exist, and Vim command names are case-sensitive.)
local map = vim.keymap.set

map('n', '<leader>ws', '<cmd>SessionSearch<CR>', { desc = 'Search sessions' })
map('n', '<leader>wS', '<cmd>SessionSave<CR>', { desc = 'Save session' })
map('n', '<leader>wr', '<cmd>SessionRestore<CR>', { desc = 'Restore session' })
map('n', '<leader>wd', '<cmd>SessionDelete<CR>', { desc = 'Delete session' })
map('n', '<leader>wt', '<cmd>SessionToggleAutoSave<CR>', { desc = 'Toggle session autosave' })
