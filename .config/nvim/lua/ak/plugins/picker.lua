-- lua/ak/plugins/picker.lua
--
-- Keymaps for snacks.nvim's `picker` module — replaces telescope.nvim.
-- Setup (theme, ignore patterns, mappings) lives in plugins/snacks.lua, next
-- to picker's `enabled`-less siblings (image, notifier, lazygit); this file
-- only wires leader keys to `Snacks.picker.*`, same split as lazygit.lua.
--
-- Same bindings as the old telescope.lua, ported 1:1:
--   <leader>ff  find_files  -> files
--   <leader>fr  lsp_references -> lsp_references
--   <leader>fg  git_files   -> git_files
--   <leader>fl  live_grep   -> grep
--   <leader>fb  buffers     -> buffers
--   <leader>f.  resume      -> resume
--   <leader>fd  diagnostics -> diagnostics
--   <leader>fw  grep_string -> grep_word
--   <leader>fh  help_tags   -> help

local map = vim.keymap.set
local opts = function(desc)
  return { noremap = true, silent = true, desc = 'Picker: ' .. desc }
end

map('n', '<leader>ff', function()
  Snacks.picker.files()
end, opts('Find files'))

map('n', '<leader>fr', function()
  Snacks.picker.lsp_references()
end, opts('LSP references'))

map('n', '<leader>fg', function()
  Snacks.picker.git_files()
end, opts('Git files'))

map('n', '<leader>fl', function()
  Snacks.picker.grep()
end, opts('Live grep'))

map('n', '<leader>fb', function()
  Snacks.picker.buffers()
end, opts('Buffers'))

-- Reopen the last picker with its query and cursor position intact.
map('n', '<leader>f.', function()
  Snacks.picker.resume()
end, opts('Resume last picker'))

-- Every diagnostic in the workspace, searchable. Complements <leader>dl in
-- diagnostics.lua, which is buffer-scoped only.
map('n', '<leader>fd', function()
  Snacks.picker.diagnostics()
end, opts('Workspace diagnostics'))

-- Grep for the word under the cursor without typing it.
map('n', '<leader>fw', function()
  Snacks.picker.grep_word()
end, opts('Grep word under cursor'))

-- Search the help.
map('n', '<leader>fh', function()
  Snacks.picker.help()
end, opts('Help tags'))

-- ── Extended pickers ─────────────────────────────────────────────────────────
-- The rest of snacks' picker sources — LazyVim's default spread, adapted to
-- this config's existing key layout instead of taken wholesale. Three
-- deliberate deviations from that layout, because a straight paste collides
-- with keys already bound above and in other plugin files:
--
--   <leader>s is "splits" here (sv/sh/se/sx in keymaps.lua), not "search" —
--   so every picker LazyVim puts under <leader>s lives under <leader>f
--   instead, alongside the telescope-ported bindings above.
--
--   <leader>fr already means `lsp_references` (ported from telescope.lua).
--   LazyVim's <leader>fr (recent files) moves to <leader>fo instead.
--   `lsp_references` also gets a second entry at bare `gr`, EXCEPT that
--   collides with the built-in grr/grn/gra/gri family (see keymaps.lua's
--   header) — typing `grr` would then pause for 'timeoutlen' while Neovim
--   waits to see whether you meant bare `gr`. Skipped for that reason;
--   <leader>fr remains the only binding.
--
--   Snacks.explorer() (LazyVim's bare <leader>e) isn't here — it's bound as
--   <leader>ee/<leader>ef in lua/ak/plugins/explorer.lua instead, next to the
--   toggle/reveal logic those need (opening it twice shouldn't stack two
--   explorers).
--
-- Also skipped: `lazy` (Snacks.picker.lazy() reads lazy.nvim's plugin spec
-- registry — this config uses vim.pack, so `require("lazy.core.config")`
-- would just error).

-- Top-level: unprefixed, since none collide with anything (space/comma/slash
-- are otherwise unused at the top of the leader tree).
map('n', '<leader><space>', function()
  Snacks.picker.smart()
end, opts('Smart find files'))

map('n', '<leader>,', function()
  Snacks.picker.buffers()
end, opts('Buffers'))

map('n', '<leader>/', function()
  Snacks.picker.grep()
end, opts('Grep'))

map('n', '<leader>:', function()
  Snacks.picker.command_history()
end, opts('Command history'))

-- <leader>f, continued
map('n', '<leader>fc', function()
  Snacks.picker.files({ cwd = vim.fn.stdpath('config') })
end, opts('Find config file'))

map('n', '<leader>fo', function()
  Snacks.picker.recent()
end, opts('Recent files'))

map('n', '<leader>fp', function()
  Snacks.picker.projects()
end, opts('Projects'))

map('n', '<leader>fa', function()
  Snacks.picker.autocmds()
end, opts('Autocmds'))

map('n', '<leader>fB', function()
  Snacks.picker.lines()
end, opts('Buffer lines'))

map('n', '<leader>fG', function()
  Snacks.picker.grep_buffers()
end, opts('Grep open buffers'))

map('n', '<leader>fC', function()
  Snacks.picker.commands()
end, opts('Commands'))

map('n', '<leader>fD', function()
  Snacks.picker.diagnostics_buffer()
end, opts('Buffer diagnostics'))

map('n', '<leader>fH', function()
  Snacks.picker.highlights()
end, opts('Highlights'))

map('n', '<leader>fi', function()
  Snacks.picker.icons()
end, opts('Icons'))

map('n', '<leader>fj', function()
  Snacks.picker.jumps()
end, opts('Jumps'))

map('n', '<leader>fk', function()
  Snacks.picker.keymaps()
end, opts('Keymaps'))

map('n', '<leader>fL', function()
  Snacks.picker.loclist()
end, opts('Location list'))

map('n', '<leader>fm', function()
  Snacks.picker.man()
end, opts('Man pages'))

map('n', '<leader>fM', function()
  Snacks.picker.marks()
end, opts('Marks'))

map('n', '<leader>fq', function()
  Snacks.picker.qflist()
end, opts('Quickfix list'))

map('n', '<leader>f"', function()
  Snacks.picker.registers()
end, opts('Registers'))

map('n', '<leader>f/', function()
  Snacks.picker.search_history()
end, opts('Search history'))

map('n', '<leader>fu', function()
  Snacks.picker.undo()
end, opts('Undo history'))

map('n', '<leader>fs', function()
  Snacks.picker.lsp_symbols()
end, opts('LSP document symbols'))

map('n', '<leader>fS', function()
  Snacks.picker.lsp_workspace_symbols()
end, opts('LSP workspace symbols'))

-- ── <leader>g — git pickers ──────────────────────────────────────────────────
-- The 'git' which-key group (whichkey.lua) was declared but unpopulated —
-- gitsigns owns <leader>h (hunks) instead, so this whole prefix was free.
map('n', '<leader>gb', function()
  Snacks.picker.git_branches()
end, opts('Git branches'))

map('n', '<leader>gl', function()
  Snacks.picker.git_log()
end, opts('Git log'))

map('n', '<leader>gL', function()
  Snacks.picker.git_log_line()
end, opts('Git log line'))

map('n', '<leader>gs', function()
  Snacks.picker.git_status()
end, opts('Git status'))

map('n', '<leader>gS', function()
  Snacks.picker.git_stash()
end, opts('Git stash'))

map('n', '<leader>gd', function()
  Snacks.picker.git_diff()
end, opts('Git diff (hunks)'))

map('n', '<leader>gf', function()
  Snacks.picker.git_log_file()
end, opts('Git log file'))

-- GitHub issues/PRs, via the `gh` CLI — same prerequisite as lazygit needing
-- the `lazygit` binary. Silently unusable without `gh` installed/authed.
map('n', '<leader>gi', function()
  Snacks.picker.gh_issue()
end, opts('GitHub issues (open)'))

map('n', '<leader>gI', function()
  Snacks.picker.gh_issue({ state = 'all' })
end, opts('GitHub issues (all)'))

map('n', '<leader>gp', function()
  Snacks.picker.gh_pr()
end, opts('GitHub pull requests (open)'))

map('n', '<leader>gP', function()
  Snacks.picker.gh_pr({ state = 'all' })
end, opts('GitHub pull requests (all)'))

-- ── <leader>u — ui ───────────────────────────────────────────────────────────
-- New group: nothing claimed <leader>u before this.
map('n', '<leader>uc', function()
  Snacks.picker.colorschemes()
end, opts('Colorschemes'))
