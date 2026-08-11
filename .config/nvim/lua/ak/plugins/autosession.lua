-- lua/ak/plugins/autosession.lua
--
-- Saves a session per working directory and restores it when you come back.
-- `cd ~/work/rails-app && nvim` reopens the buffers, splits, and tabs you left.

-- ── sessionoptions ─────────────────────────────────────────────────────────
-- A prerequisite, not a preference — this is the value auto-session's README
-- calls "recommended for the best experience", and the parts that matter are
-- the ones Neovim omits by default:
--
--   winpos, winsize     window geometry, so splits come back the right size
--   terminal            :terminal buffers survive
--   folds               your fold state persists
--   localoptions        buffer-local settings (filetype, indent) are restored,
--                       which matters here because that's what re-triggers the
--                       FileType autocmds driving treesitter and LSP attach
--
-- Kept in this file rather than options.lua because it only affects :mksession
-- — it's this plugin's dependency, not an editor-wide preference. (timeoutlen
-- went to options.lua because it changes how every mapping behaves.)
vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions'

require('auto-session').setup({
  -- ── Where NOT to auto-session ────────────────────────────────────────────
  -- Starting nvim in your home directory or / is almost always incidental —
  -- a quick edit, not a project. Creating sessions there accumulates junk and,
  -- worse, restores a pile of unrelated buffers next time you happen to run
  -- nvim from $HOME.
  suppressed_dirs = { '~/', '~/Downloads', '~/Desktop', '/' },

  -- ── Behaviour ────────────────────────────────────────────────────────────
  -- All three default to true; stated explicitly because they're the whole
  -- contract of the plugin and worth seeing at a glance.
  auto_save = true,
  auto_restore = true,
  auto_create = true,

  -- OFF deliberately. With this on, a `:cd` mid-session saves the current
  -- session and swaps to another — which sounds convenient but means the
  -- picker or explorer changing the cwd can silently swap your whole workspace.
  cwd_change_handling = false,

  -- Default true, and it's what makes the explorer safe here: its window
  -- isn't backed by a real file, so :mksession would restore a broken one.
  -- This closes such windows before saving.
  close_unsupported_windows = true,

  -- Don't save a session whose only open buffer is one of these — no point
  -- persisting "I opened nvim and looked at the tree". `snacks_picker_list`
  -- is the explorer's filetype (it's a picker under the hood — see
  -- explorer.lua); nvim-tree's was 'NvimTree'.
  bypass_save_filetypes = { 'snacks_picker_list' },

  -- Delete sessions untouched for 30 days, asynchronously at startup. Without
  -- this the session directory grows a file per project you ever opened,
  -- including one-off clones.
  purge_after_minutes = 43200, -- 60 * 24 * 30
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Under <leader>w (workspace), already declared as a which-key group.
local map = vim.keymap.set

-- Command names verified against the installed v2.5.1, not the README. Two
-- traps there:
--   * the subcommand form is `:Autosession` with a LOWERCASE s. `:AutoSession`
--     does not exist, and Vim command names are case-sensitive.
--   * the dedicated :Session* commands below are the real interface and read
--     better at a keymap anyway.
--
-- Picker over saved sessions — auto-session ships this itself now, so the old
-- separate session-lens plugin is unnecessary.
map('n', '<leader>ws', '<cmd>SessionSearch<CR>', { desc = 'Search sessions' })
map('n', '<leader>wS', '<cmd>SessionSave<CR>', { desc = 'Save session' })
map('n', '<leader>wr', '<cmd>SessionRestore<CR>', { desc = 'Restore session' })
map('n', '<leader>wd', '<cmd>SessionDelete<CR>', { desc = 'Delete session' })
map('n', '<leader>wt', '<cmd>SessionToggleAutoSave<CR>', { desc = 'Toggle session autosave' })

-- NOTE: <leader>ws was previously vim.lsp.buf.workspace_symbol in lsp.lua.
-- That has moved to <leader>wy to free this up — see lsp.lua.
