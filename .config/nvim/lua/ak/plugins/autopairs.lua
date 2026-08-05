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
  -- Compatibility note, since this is the setting most likely to break:
  -- nvim-autopairs' treesitter code uses CORE apis only —
  -- vim.treesitter.get_node(), get_parser(), is_in_node_range(). It does NOT
  -- use nvim-treesitter's old ts_utils module, which the main-branch rewrite
  -- removed. Verified against both sources; check_ts is safe here.
  check_ts = true,

  ts_config = {
    -- Values are treesitter node types where a pair should NOT be added.
    --
    -- In a JS template string you type backtick-delimited text containing
    -- apostrophes constantly (`it's`), and auto-closing those is pure noise.
    javascript = { 'template_string' },
    typescript = { 'template_string' },
    lua = { 'string' },
  },

  -- ── Filetypes to skip ────────────────────────────────────────────────────
  -- telescope's prompt is a real buffer; pairing inside a search query is
  -- actively unhelpful when you're typing a regex.
  disable_filetype = { 'TelescopePrompt', 'snacks_picker_input', 'vim' },

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
  -- <A-e> in insert mode wraps the next word in the pair you're on. Genuinely
  -- useful for `foo` -> `(foo)` without leaving insert.
  --
  -- NOTE: this needs the Alt key to reach Neovim. That depends on Ghostty's
  -- `macos-option-as-alt` setting — with it unset, Option emits `´` rather
  -- than <A-e> and this binding is inert. The same applies to the <A-j>/<A-k>
  -- telescope mappings and the <A-h/j/k/l> insert-mode arrows in keymaps.lua.
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

-- ── Deliberately NOT wired: completion integration ─────────────────────────
-- The classic snippet for this is
--
--   local cmp_autopairs = require('nvim-autopairs.completion.cmp')
--   cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
--
-- That exists to make nvim-cmp add brackets when you accept a function. We're
-- on blink.cmp, which does that itself via completion.accept.auto_brackets
-- (set in plugins/blink.lua) — and it's smarter about it, using the item's
-- LSP kind and semantic tokens to decide whether the thing is callable.
--
-- Wiring both is where the "why did I get foo(())" reports come from. blink
-- owns completion-accept; nvim-autopairs owns manual typing. No overlap.
