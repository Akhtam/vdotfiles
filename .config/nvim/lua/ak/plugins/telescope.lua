-- lua/ak/plugins/telescope.lua
--
-- Ported from your lazy.nvim config. Same theme, same mappings, same keymaps.
-- Three deliberate differences, each explained where it occurs:
--   1. no version pin (your `tag = "0.1.8"` is two majors behind)
--   2. the fzf-native extension is loaded
--   3. a few additions marked NEW that you can delete freely

local telescope = require('telescope')
local builtin = require('telescope.builtin')
local themes = require('telescope.themes')
local actions = require('telescope.actions')

-- Your shared mapping table, unchanged. Applied to both insert and normal mode
-- so the picker behaves identically regardless of which you're in.
--
-- Worth noting now that it actually works: <A-k>/<A-j>/<A-f>/<A-b> were dead
-- keys in Ghostty until we set `macos-option-as-alt = left`. Before that the
-- Option key emitted ˚/∆/ƒ/∫ and Neovim never saw an Alt modifier at all — so
-- if you'd carried this config over untouched, four of these five bindings
-- would have silently done nothing.
local shared_mapping = function()
  return {
    ['<C-h>'] = actions.file_split, -- open file in a horizontal split
    ['<A-k>'] = actions.move_selection_previous,
    ['<A-j>'] = actions.move_selection_next,
    ['<A-f>'] = actions.preview_scrolling_down,
    ['<A-b>'] = actions.preview_scrolling_up,
  }
end

telescope.setup({
  -- ivy theme for every picker: a bottom-anchored panel rather than a centred
  -- floating box. Keeps the picker anchored in one place so your eyes don't
  -- have to re-find it each time.
  defaults = themes.get_ivy({
    -- "smart" shortens leading path components only as far as needed to keep
    -- entries unique. In a Rails app this is the difference between four
    -- indistinguishable `show.html.erb` rows and
    -- `app/views/{users,posts}/show.html.erb`.
    path_display = { 'smart' },

    mappings = {
      i = shared_mapping(),
      n = shared_mapping(),
    },

    -- NEW: exclude directories that are pure noise in your two stacks. Without
    -- this, live_grep in a Rails app returns hits from vendor/bundle and every
    -- find_files call wades through node_modules.
    file_ignore_patterns = {
      '^%.git/',
      'node_modules/',
      '^vendor/bundle/',
      '^tmp/',
      '^log/',
      '%.min%.js$',
      '%.lock$',
    },
  }),

  pickers = {
    -- Yours: reference lists get long, and the source line adds width without
    -- adding much — the file:line and the preview already tell you where you are.
    lsp_references = {
      show_line = false,
    },

    -- NEW: include dotfiles in find_files. You are, at this moment, editing a
    -- dotfiles repo; excluding them by default is actively wrong here.
    find_files = {
      hidden = true,
    },
  },

  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = 'smart_case', -- case-insensitive until you type a capital
    },
  },
})

-- ── fzf-native ─────────────────────────────────────────────────────────────
-- NEW, and the reason libfzf.so gets built by the PackChanged hook in
-- plugins/init.lua. It swaps telescope's pure-Lua sorter for fzf's C
-- implementation — the same algorithm as the fzf binary you already have.
--
-- The difference is only noticeable at scale, which is exactly your case: a
-- Rails app plus node_modules is tens of thousands of candidate paths, and the
-- Lua sorter visibly lags behind your typing there.
--
-- pcall'd because a failed native build should degrade to the slower sorter,
-- not break every picker you own.
local ok, err = pcall(telescope.load_extension, 'fzf')
if not ok then
  vim.notify(
    'telescope-fzf-native not loaded (falling back to the Lua sorter).\n'
      .. 'Rebuild with: cd ~/.local/share/nvim/site/pack/core/opt/telescope-fzf-native.nvim && make\n'
      .. tostring(err),
    vim.log.levels.WARN
  )
end

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Yours, verbatim. `desc` added to each — it's what :Telescope keymaps and
-- `:map <leader>f` display, and it costs nothing.
local map = vim.keymap.set
local opts = function(desc)
  return { noremap = true, silent = true, desc = 'Telescope: ' .. desc }
end

map('n', '<leader>ff', builtin.find_files, opts('Find files'))
map('n', '<leader>fr', builtin.lsp_references, opts('LSP references'))
map('n', '<leader>fg', builtin.git_files, opts('Git files'))
map('n', '<leader>fl', builtin.live_grep, opts('Live grep'))
map('n', '<leader>fb', builtin.buffers, opts('Buffers'))

-- NEW — delete any you don't want.
--
-- Reopen the last picker with its query and cursor position intact. The single
-- most useful telescope binding after the basics: you grep, open a result,
-- realise it was the wrong one, and want the list back rather than retyping.
map('n', '<leader>f.', builtin.resume, opts('Resume last picker'))

-- Every diagnostic in the workspace, searchable. Complements <leader>dl in
-- diagnostics.lua, which is buffer-scoped only.
map('n', '<leader>fd', builtin.diagnostics, opts('Workspace diagnostics'))

-- Grep for the word under the cursor without typing it. In a Rails codebase
-- "where else is this constant used" is a constant question.
map('n', '<leader>fw', builtin.grep_string, opts('Grep word under cursor'))

-- Search the help. Genuinely worth a binding while a config is this new —
-- :h vim.pack, :h lsp-config, :h treesitter-query-modeline are all in here.
map('n', '<leader>fh', builtin.help_tags, opts('Help tags'))
