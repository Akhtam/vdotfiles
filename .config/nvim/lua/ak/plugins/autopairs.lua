-- lua/ak/plugins/autopairs.lua
--
-- Auto-close brackets and quotes while typing. Fills the one gap nothing else
-- in this config covers:
--
--   blink `auto_brackets`         only on accepting a COMPLETION
--   vtsls `completeFunctionCalls` same, completion-only
--   core Neovim                   nothing — 'matchpairs' is only for % jumps
--
-- So typing `(` manually produced exactly `(` until this file existed.

local npairs = require('nvim-autopairs')

npairs.setup({
  -- ── Treesitter awareness ─────────────────────────────────────────────────
  -- Consult the syntax tree before inserting a pair, so quotes and brackets
  -- aren't auto-closed where they'd be wrong.
  --
  -- Safe with the main-branch treesitter rewrite: nvim-autopairs uses core APIs
  -- only (vim.treesitter.get_node/get_parser/is_in_node_range), not the old
  -- ts_utils module the rewrite removed.
  check_ts = true,

  ts_config = {
    -- Node types where a pair should NOT be added. Template strings contain
    -- apostrophes constantly (`it's`), and auto-closing those is noise.
    javascript = { 'template_string' },
    typescript = { 'template_string' },
    lua = { 'string' },
  },

  -- ── Filetypes to skip ────────────────────────────────────────────────────
  -- the picker's prompt is a real buffer; pairing inside a search query is
  -- actively unhelpful when you're typing a regex.
  disable_filetype = { 'snacks_picker_input', 'vim' },

  -- Don't add a closing pair when the very next character is alphanumeric —
  -- so typing `(` before an existing word wraps rather than orphans a `)`.
  ignored_next_char = [=[[%w%%%'%[%"%.%`%$]]=],

  -- <CR> inside an empty pair opens an indented line and puts the closer
  -- below. This is the behaviour you want in every language here:
  --   function foo() {|}   ->   function foo() {
  --                               |
  --                             }
  map_cr = true,

  -- <BS> on an empty pair deletes both halves.
  map_bs = true,

  -- Keeps the pair insertion out of the undo sequence of the surrounding
  -- edit, so `u` doesn't unwind character by character.
  break_undo = true,

  -- ── fast_wrap ────────────────────────────────────────────────────────────
  -- <A-e> wraps the next word in the pair you're on: `foo` -> `(foo)` without
  -- leaving insert. Left Option only; settled in ghostty/config.
  --
  -- SHARED with blink.cmp, which binds <A-e> to `{ 'hide', 'fallback' }`, so the
  -- key dismisses the menu when open and falls through to fast_wrap otherwise.
  -- That only works because plugins/init.lua loads this file BEFORE blink's —
  -- blink captures whatever <A-e> already meant.
  fast_wrap = {
    map = '<A-e>',
    chars = { '{', '[', '(', '"', "'", '`' },
    end_key = '$',
    keys = 'qwertyuiopzxcvbnmasdfghjkl',
    check_comma = true,
    highlight = 'Search',
    highlight_grey = 'Comment',
  },
})

-- ── endwise: Ruby ────────────────────────────────────────────────────────
-- <CR> after `def foo`, `class Foo`, `if x`, `do`, etc. auto-inserts `end`.
-- Ships in nvim-autopairs itself (lua/nvim-autopairs/rules/endwise-ruby.lua),
-- built on the same check_ts/treesitter machinery as the pairing rules above —
-- no separate plugin (vim-endwise, nvim-treesitter-endwise) needed.
npairs.add_rules(require('nvim-autopairs.rules.endwise-ruby'))

-- ── Deliberately NOT wired: completion integration ─────────────────────────
-- The classic `cmp_autopairs.on_confirm_done()` snippet exists to make nvim-cmp
-- add brackets on accepting a function. blink.cmp does that itself via
-- completion.accept.auto_brackets (plugins/blink.lua), and more precisely —
-- it checks the item's LSP kind to decide whether the thing is callable.
--
-- Wiring both is where "why did I get foo(())" comes from. blink owns
-- completion-accept; nvim-autopairs owns manual typing. No overlap.
