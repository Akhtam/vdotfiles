-- lua/ak/plugins/ui.lua
--
-- Colorscheme only. The statusline moved to plugins/lualine.lua when your own
-- lualine config came in — they were two unrelated concerns sharing a file.

-- "moon" specifically, to match `theme = TokyoNight Moon` in your Ghostty
-- config. Mismatched terminal and editor themes show up as a colour seam
-- around the edges of the editor and in :terminal buffers.
require('tokyonight').setup({
  style = 'moon',

  styles = {
    comments = { italic = true },
    keywords = { italic = false }, -- italic keywords in TSX get noisy fast
  },

  -- Dim inactive splits so the focused window is obvious. With laststatus=3
  -- there's no per-window statusline to tell them apart otherwise.
  dim_inactive = true,

  transparent = false,

  on_highlights = function(hl, c)
    -- Treesitter injections in ERB: the html layer and the ruby layer both
    -- render inside one buffer. Tinting the <% %> delimiters makes the
    -- boundary between them visible at a glance, which matters when you're
    -- scanning a view for where logic starts and markup ends.
    hl['@punctuation.special.embedded_template'] = { fg = c.orange, bold = true }

    -- snacks' scope bar defaults to linking `Special` — blue1 (#65bcff) here,
    -- bright enough to compete with the code it's bracketing. The plain indent
    -- guides link NonText = fg_gutter (#3b4261), so the scope only needs to sit
    -- one step above that to read as "this block is current". dark3 (#545c7e)
    -- is the same muted hue, just lifted.
    -- Brighter: c.dark5, then c.comment. Saturated accent: c.blue0.
    hl.SnacksIndentScope = { fg = c.dark3 }
  end,
})

vim.cmd.colorscheme('tokyonight-moon')
