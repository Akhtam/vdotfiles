-- lua/ak/plugins/snacks.lua
--
-- snacks.nvim ships ~30 independent modules, each opt-in: a module activates
-- only if you pass it options here. Seven are configured — image, notifier,
-- lazygit, picker, explorer, indent, words — and nothing else in the bundle
-- runs. Keymaps live one file per module (picker.lua, explorer.lua, ...);
-- this file is setup() only.
--
-- External binaries, both declared in .config/Brewfile:
--   image     needs ImageMagick's `magick` to decode images before handing
--             them to the terminal — without it, images silently don't render
--   explorer  trash = true (default) sends deletions to the system trash
--             rather than `rm`, which needs a `trash` CLI on $PATH
--
-- notifier is noice's toast backend: noice tries `{ "snacks", "notify" }` in
-- order and picks this one automatically once it's enabled, so nothing on the
-- noice side configures it.
--
-- indent:
--   char = '▏'          U+258F, thinner than │ — matters at the 2-space
--                       indentation options.lua sets, where guides sit close
--   scope.enabled = false  Scope highlighting is treesitter-driven, and in ERB
--                       the tree is three injected languages deep
--                       (embedded_template + html + ruby). Resolution across
--                       those injection boundaries is where it draws the
--                       highlight around the wrong block.
--
-- words auto-highlights references to the symbol under the cursor via
-- `textDocument/documentHighlight`, debounced on CursorMoved. lsp.lua must NOT
-- also run document_highlight() — two listeners on the same highlight flicker.
--
-- explorer is "a picker in disguise", so most of its configuration is the
-- `sources.explorer` block below, not the top-level `explorer = {}`.

-- Glob syntax (fd `-E` / rg `-g !...`), not Lua patterns. snacks' `exclude` is
-- per-source, hence repeating it under both `files` and `grep`. `.git` needs
-- no entry — fd and rg exclude it unconditionally.
local picker_exclude = {
  'node_modules',
  'vendor/bundle',
  'tmp',
  'log',
  '*.min.js',
  '*.lock',
}

-- Narrower than `picker_exclude` on purpose: browsing "what's in this
-- directory" and "find a file by name" have different noise tolerances, so
-- gitignored files (node_modules included) stay visible while browsing.
local explorer_exclude = {
  '.DS_Store',
  '.env.local',
  '.env.development',
}

require('snacks').setup({
  image = { enabled = true },
  notifier = {
    enabled = true,
    style = 'fancy',
    top_down = false,
  },
  indent = {
    enabled = true,
    indent = { char = '▏' },
    scope = { enabled = true, char = '▏'},
    hl = "SnacksIndent", ---@type string|string[] hl groups for indent guides
  },
  words = { enabled = true },
  -- No `enabled` flag exists for this module — unlike `image`/`notifier` it's
  -- not gated, just called on demand (`Snacks.lazygit()`). The empty table is
  -- here purely so this module's presence is visible at a glance next to the
  -- other two.
  lazygit = {},
  explorer = {},

  picker = {
    -- ivy theme for every picker: a bottom-anchored panel rather than a
    -- centred floating box, same as telescope's `themes.get_ivy()`. Built
    -- into snacks as a layout preset — no theme module to require.
    layout = { preset = 'ivy' },

    formatters = {
      file = {
        -- Closest match to telescope's `path_display = { 'smart' }`: keep the
        -- filename visible and truncate from the front when a path is too
        -- long for the column. Not identical (telescope shortens only as far
        -- as needed to keep entries unique; this is a fixed-width truncate),
        -- but the same practical effect — you always see the filename.
        truncate = 'left',
      },
    },

    sources = {
      -- Dotfiles repo: exclude-by-default would hide the very files you're
      -- editing right now. Only `files` needs this — grep, buffers, etc.
      -- don't filter on dotfile-ness.
      files = { hidden = true, exclude = picker_exclude },
      grep = { exclude = picker_exclude },

      -- The explorer, ported from nvim-tree.lua's settings:
      explorer = {
        hidden = true, -- dotfiles repo — same reasoning as `files` above
        -- nvim-tree's `git.ignore = false`: show gitignored files too (so
        -- .env etc. stay reachable), minus the noise in `explorer_exclude`.
        ignored = true,
        exclude = explorer_exclude,
        -- nvim-tree's `quit_on_open = true`: this is a centred float (see
        -- `layout` below), not a permanent sidebar, so it should get out of
        -- the way once you've picked a file rather than keep covering it.
        -- (The default explorer source sets `jump = { close = false }` for
        -- the opposite reason — its default layout IS a sidebar.)
        jump = { close = true },
        -- nvim-tree's centred float, ratios and all: WIDTH_RATIO = 0.5,
        -- HEIGHT_RATIO = 0.8 there is exactly the built-in `vertical` preset's
        -- width/height. `preview = false` keeps it a plain tree, matching
        -- nvim-tree (which had no inline preview pane).
        layout = { preset = 'vertical', preview = false },
      },
    },

    win = {
      -- Shared mapping table, unchanged in spirit from telescope's
      -- `shared_mapping()`: applied to both the input (insert) and list
      -- (normal) windows via `mode = { "i", "n" }`, so the picker behaves
      -- identically regardless of which has focus.
      --
      -- Snacks' `edit_split` action opens the selection below the current
      -- window. Terminals report Ctrl+- as either <C-_> or <C-->.
      -- <A-k>/<A-j> move the selection, <A-f>/<A-b> scroll the preview — same
      -- four Alt keys as before. Left Option only; that's settled in
      -- ghostty/config, not here.
      input = {
        keys = {
          ['<C-_>'] = { 'edit_split', mode = { 'i', 'n' } },
          ['<C-->'] = { 'edit_split', mode = { 'i', 'n' } },
          ['<A-k>'] = { 'list_up', mode = { 'i', 'n' } },
          ['<A-j>'] = { 'list_down', mode = { 'i', 'n' } },
          ['<A-f>'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
          ['<A-b>'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
        },
      },
      list = {
        keys = {
          ['<C-_>'] = 'edit_split',
          ['<C-->'] = 'edit_split',
          ['<A-k>'] = 'list_up',
          ['<A-j>'] = 'list_down',
          ['<A-f>'] = 'preview_scroll_down',
          ['<A-b>'] = 'preview_scroll_up',
        },
      },
    },
  },
})
