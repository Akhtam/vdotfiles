-- lua/ak/plugins/gh.lua
--
-- GitHub issues/PRs, via snacks.nvim's `picker` module — `Snacks.picker.gh_*`
-- sources, backed by the `gh` CLI. Split out of picker.lua rather than living
-- alongside the rest of the `Snacks.picker.*` bindings, same reasoning as
-- lazygit.lua: it depends on an external binary (`gh`, authed) the way
-- lazygit.lua depends on the `lazygit` binary, so it's silently unusable
-- without that prerequisite — worth its own file rather than blending into
-- picker.lua's "every picker source" list.

local map = vim.keymap.set
local opts = function(desc)
  return { silent = true, desc = 'GitHub: ' .. desc }
end

-- Overrides picker.lua's global `ivy` layout (a bottom-anchored panel) just
-- for these four commands: issue/PR bodies are prose, not a single-line list
-- of files, so a centred float with more room reads better here. `default`
-- is snacks' own floating preset (see snacks/picker/config/layouts.lua) —
-- reused rather than hand-built, just resized from its 0.8/0.8 default down
-- to 0.9/0.9.
local float = { layout = { preset = 'default', layout = { width = 0.9, height = 0.9 } } }

map('n', '<leader>gi', function()
  Snacks.picker.gh_issue(float)
end, opts('Issues (open)'))

map('n', '<leader>gI', function()
  Snacks.picker.gh_issue(vim.tbl_extend('force', { state = 'all' }, float))
end, opts('Issues (all)'))

map('n', '<leader>gp', function()
  Snacks.picker.gh_pr(float)
end, opts('Pull requests (open)'))

map('n', '<leader>gP', function()
  Snacks.picker.gh_pr(vim.tbl_extend('force', { state = 'all' }, float))
end, opts('Pull requests (all)'))
