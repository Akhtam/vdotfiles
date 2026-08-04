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
  end,
})

vim.cmd.colorscheme('tokyonight-moon')
