-- lua/ak/plugins/snacks.lua
--
-- snacks.nvim ships ~30 independent modules, each opt-in: a module only
-- activates if you pass it options here. `image`, `notifier`, `lazygit`,
-- `picker`, `explorer`, `indent`, and `words` are configured; nothing else
-- in the bundle activates.
--
-- ── image ──────────────────────────────────────────────────────────────────
-- Renders images using the terminal's graphics protocol (kitty protocol —
-- Ghostty supports it) in two places:
--   1. Image files opened directly (png, jpg, gif, pdf, ...) — the whole
--      buffer becomes the image.
--   2. Inline in markdown buffers, at the location of an image link
--      (`![]()`) or `<img>` tag — rendered as you scroll past it.
--
-- REQUIRES ImageMagick (the `magick` CLI) to decode/convert source images
-- before handing them to the terminal. Installed, and declared in
-- .config/Brewfile; without it images silently fail to render.
--
-- ── notifier ───────────────────────────────────────────────────────────────
-- Replaces nvim-notify as noice's toast backend. noice's "notify" view tries
-- backends in order `{ "snacks", "notify" }` (see
-- noice/config/views.lua and noice/view/backend/snacks.lua) and picks snacks
-- automatically once `Snacks.config.notifier.enabled` is true — no change
-- needed on the noice side. See noice.lua for the nvim-notify setup this
-- replaced.
--
--   style = 'fancy'   closest visual match to nvim-notify's default look.
--   top_down = false  toasts stack upward from the bottom, same as the old
--                     `require('notify').setup({ top_down = false })`.
--
-- ── lazygit ────────────────────────────────────────────────────────────────
-- Replaces kdheepak/lazygit.nvim. Defaults are already the right call:
--   configure = true   auto-generates a lazygit theme matching the active
--                       colorscheme and sets `os.editPreset = "nvim-remote"`,
--                       which is a mode built into lazygit itself — unlike
--                       the old plugin's `lazygit_use_neovim_remote`, it does
--                       NOT need the external `nvr` (neovim-remote) tool.
-- Keymaps live in lua/ak/plugins/lazygit.lua.
--
-- ── picker ─────────────────────────────────────────────────────────────────
-- Replaces telescope.nvim + telescope-fzf-native. Ported from telescope.lua,
-- same theme, same ignore list, same shared split/nav/preview-scroll keys —
-- see that file's git history for the original. Keymaps live in
-- lua/ak/plugins/picker.lua. Like `lazygit`, no `enabled` flag: every picker
-- (files, grep, buffers, ...) is called on demand as `Snacks.picker.<name>()`.
--
-- No fzf-native equivalent needed: the matcher here is snacks' own Lua
-- implementation, not a pluggable sorter, so there's no separate C extension
-- to build (and no PackChanged hook for it, unlike telescope's).
--
-- ── explorer ───────────────────────────────────────────────────────────────
-- Replaces nvim-tree — "a file explorer (picker in disguise)" per its own
-- doc comment, so most of it is configured as a `picker` SOURCE below
-- (`sources.explorer`), not here. This top-level `explorer = {}` is the
-- module's own general settings, separate from the picker source config:
--   replace_netrw = true (default)   disables netrw itself, so no more
--                                     hand-set `vim.g.loaded_netrw` flags
--   trash = true (default)           deletions go to the system trash, not
--                                     `rm` — needs a `trash` CLI on $PATH
-- Both already default true; declared for visibility, same as `lazygit = {}`
-- above. Keymap lives in lua/ak/plugins/explorer.lua.
--
-- ── indent ─────────────────────────────────────────────────────────────────
-- Replaces lukas-reineke/indent-blankline.nvim. Same two settings ported
-- 1:1, everything else left at snacks' defaults:
--
--   indent.char = '▏'    U+258F LEFT ONE EIGHTH BLOCK, same thinner-than-│
--                        guide ibl was using — matters at 2-space indentation
--                        (Ruby, TS, JSX in options.lua) where guides sit close
--                        together.
--   scope.enabled = false   ibl had this off too. Scope highlighting is
--                        treesitter-driven, and in ERB the tree is three
--                        injected languages deep (embedded_template + html +
--                        ruby) — scope resolution across those injection
--                        boundaries is exactly where it gets confused and
--                        draws the highlight around the wrong block. Off
--                        avoids that entirely, same reasoning as before.
--
-- No keymap file: like `image`/`notifier`, this module has no user-facing
-- commands, just per-window rendering — config here is the whole story.
--
-- ── words ──────────────────────────────────────────────────────────────────
-- Auto-highlights every reference to the symbol under the cursor and lets you
-- jump between them, on top of `textDocument/documentHighlight` — same LSP
-- request lsp.lua's old CursorHold-triggered `document_highlight()` used, but
-- driven by CursorMoved with its own 200ms debounce instead of 'updatetime',
-- plus the `]]`/`[[` jump that hand-rolled version never had. Replaces that
-- block entirely (see lsp.lua) rather than running alongside it — two
-- listeners fighting over the same highlight would just flicker. Defaults
-- otherwise; keymaps live in lua/ak/plugins/words.lua.
--
-- Ignore list, ported from telescope's `file_ignore_patterns`. Glob syntax
-- here (passed to fd's `-E` / rg's `-g !...`) rather than Lua patterns.
-- telescope's `file_ignore_patterns` lived in `defaults` and so applied to
-- every picker; snacks' `exclude` is per-source, hence listing it under both
-- `files` and `grep` below. `.git` needs no entry — fd/rg exclude it
-- unconditionally already.
local picker_exclude = {
  'node_modules',
  'vendor/bundle',
  'tmp',
  'log',
  '*.min.js',
  '*.lock',
}

-- The explorer's own exclude list, ported from nvim-tree's `filters.custom`
-- (.DS_Store) + `filters.exclude` (.env.local/.env.development) — narrower
-- than `picker_exclude` above on purpose. nvim-tree's `git.ignore = false`
-- meant everything else gitignored (node_modules included) stayed visible
-- while browsing, even though `picker_exclude` hides it from fuzzy search —
-- browsing "what's in this directory" and "find a file by name" have
-- different noise tolerances, so the two lists stay separate.
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
    scope = { enabled = false },
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
      -- <C-h> was telescope's `file_split`; snacks' equivalent action is
      -- `edit_split`. <A-k>/<A-j> move the selection, <A-f>/<A-b> scroll the
      -- preview — same four Alt keys as before. Left Option only; that's
      -- settled in ghostty/config, not here.
      input = {
        keys = {
          ['<C-h>'] = { 'edit_split', mode = { 'i', 'n' } },
          ['<A-k>'] = { 'list_up', mode = { 'i', 'n' } },
          ['<A-j>'] = { 'list_down', mode = { 'i', 'n' } },
          ['<A-f>'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
          ['<A-b>'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
        },
      },
      list = {
        keys = {
          ['<C-h>'] = 'edit_split',
          ['<A-k>'] = 'list_up',
          ['<A-j>'] = 'list_down',
          ['<A-f>'] = 'preview_scroll_down',
          ['<A-b>'] = 'preview_scroll_up',
        },
      },
    },
  },
})
