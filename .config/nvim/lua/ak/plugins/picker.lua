-- lua/ak/plugins/picker.lua
--
-- Keymaps for snacks.nvim's `picker` module. Setup (theme, ignore patterns,
-- window mappings) lives in plugins/snacks.lua; this file only wires leader
-- keys to `Snacks.picker.*`.

local map = vim.keymap.set
local opts = function(desc)
  return { silent = true, desc = 'Picker: ' .. desc }
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

-- Every diagnostic in the workspace, searchable. Complements <leader>xl in
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
-- The rest of snacks' picker sources, on LazyVim's layout but adapted where it
-- collides with keys already bound here:
--
--   <leader>s is "splits" (keymaps.lua), not "search" — so LazyVim's <leader>s
--   pickers live under <leader>f instead.
--
--   <leader>fr is lsp_references, so recent files moves to <leader>fo. NO bare
--   `gr` binding for references either: it collides with the built-in
--   grr/grn/gra/gri family, and typing `grr` would stall for 'timeoutlen'.
--
--   The explorer is <leader>ef/<leader>et in explorer.lua, not bare <leader>e,
--   because it needs toggle logic (opening twice shouldn't stack two).
--
-- Skipped entirely: `lazy` — Snacks.picker.lazy() reads lazy.nvim's spec
-- registry, and this config uses vim.pack, so it would just error.

-- Top-level: unprefixed, since none collide with anything (space/comma/slash
-- are otherwise unused at the top of the leader tree).
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
-- gitsigns owns <leader>h for hunks, so this prefix is free for git pickers.
--
-- The whole group floats at 90% rather than the global `ivy` layout — git
-- output is wide. gh.lua applies the same override to the gh_issue/gh_pr
-- pickers sharing this prefix, so the prefix stays visually consistent.
local float = { layout = { preset = 'default', layout = { width = 0.9, height = 0.9 } } }

map('n', '<leader>gb', function()
  Snacks.picker.git_branches(float)
end, opts('Git branches'))

map('n', '<leader>gl', function()
  Snacks.picker.git_log(float)
end, opts('Git log'))

map('n', '<leader>gL', function()
  Snacks.picker.git_log_line(float)
end, opts('Git log line'))

map('n', '<leader>gs', function()
  Snacks.picker.git_status(float)
end, opts('Git status'))

map('n', '<leader>gS', function()
  Snacks.picker.git_stash(float)
end, opts('Git stash'))

map('n', '<leader>gd', function()
  Snacks.picker.git_diff(float)
end, opts('Git diff (hunks)'))

map('n', '<leader>gf', function()
  Snacks.picker.git_log_file(float)
end, opts('Git log file'))

-- GitHub issues/PRs (<leader>gi/gI/gp/gP) share this prefix but live in gh.lua,
-- since they depend on the external `gh` CLI. They duplicate the `float` table
-- above rather than sharing it, so each file stays self-contained — change one
-- and change both.

-- ── <leader>u — ui ───────────────────────────────────────────────────────────
map('n', '<leader>uc', function()
  Snacks.picker.colorschemes()
end, opts('Colorschemes'))
