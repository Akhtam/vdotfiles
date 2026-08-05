-- lua/ak/plugins/indent.lua
--
-- Indent guides — a vertical line at each indentation level.
--
-- Your config, unchanged. Two translations from the lazy.nvim spec:
--
--   main = "ibl"   lazy needed telling that the module name differs from the
--                  repo name (indent-blankline.nvim -> ibl). With vim.pack we
--                  just require the right module, so this disappears.
--
--   event = ...    lazy's load trigger. vim.pack has no lazy-loading, so the
--                  plugin loads at startup. Its cost is a few ms of setup; the
--                  actual work is done per-window on redraw either way.

require('ibl').setup({
  indent = {
    -- U+258F LEFT ONE EIGHTH BLOCK. Thinner and less noisy than the default │,
    -- which matters at 2-space indentation where guides sit close together —
    -- and 2 spaces is what options.lua sets for Ruby, TS, and JSX alike.
    char = '▏',
  },

  scope = {
    -- Off, per your config. Scope highlighting draws an emphasised guide for
    -- the block the cursor is inside, recomputed as you move.
    --
    -- Worth knowing WHY this is the right call here rather than just a
    -- preference: scope detection is treesitter-driven, and in ERB the tree is
    -- three injected languages deep (embedded_template + html + ruby). Scope
    -- resolution across injection boundaries is exactly where it gets
    -- confused, drawing the highlight around the wrong block. Off avoids that
    -- entirely.
    enabled = false,
  },
})
