-- lua/ak/plugins/ui.lua
--
-- Colorscheme and statusline.

-- ── Colorscheme ────────────────────────────────────────────────────────────
-- "moon" specifically, to match `theme = TokyoNight Moon` in your Ghostty
-- config. Mismatched terminal and editor themes show up as a colour seam
-- around the edges of the editor and in :terminal buffers.
require('tokyonight').setup({
  style = 'moon',

  -- Italic comments are the default. They render as a synthesised oblique in
  -- JetBrains Mono NL (the "NL" variant is No Ligatures, and its italic is a
  -- separate face), which is fine — but italics in a terminal depend on the
  -- terminfo entry supporting them. Ghostty does. Left on.
  styles = {
    comments = { italic = true },
    keywords = { italic = false }, -- italic keywords in TSX get noisy fast
  },

  -- Dim inactive splits so the focused window is obvious. With laststatus=3
  -- there's no per-window statusline to tell them apart otherwise.
  dim_inactive = true,

  -- Make the terminal background match, rather than showing Ghostty's own
  -- background through Neovim's.
  transparent = false,

  on_highlights = function(hl, c)
    -- Treesitter injections in ERB: the html layer and the ruby layer both
    -- render inside one buffer. Tinting the <% %> delimiters makes the
    -- boundary between them visible at a glance, which matters a lot when
    -- you're scanning a view for where logic starts and markup ends.
    hl['@punctuation.special.embedded_template'] = { fg = c.orange, bold = true }
  end,
})

vim.cmd.colorscheme('tokyonight-moon')

-- ── Statusline ─────────────────────────────────────────────────────────────
require('lualine').setup({
  options = {
    theme = 'tokyonight',
    -- ONE statusline across the bottom, not one per split. This must agree
    -- with laststatus = 3 in options.lua; set one without the other and you
    -- get either a doubled bar or an empty one.
    globalstatus = true,
    component_separators = { left = '│', right = '│' },
    section_separators = '',
    disabled_filetypes = {
      statusline = { 'NvimTree', 'neo-tree', 'dapui_scopes', 'dapui_stacks', 'dapui_watches', 'dapui_console' },
    },
  },

  sections = {
    lualine_a = { 'mode' },
    lualine_b = {
      'branch',
      -- Git hunks, populated by gitsigns.
      { 'diff', symbols = { added = '+', modified = '~', removed = '-' } },
    },
    lualine_c = {
      {
        'filename',
        -- 1 = relative path, not just the basename. In a Rails app you will
        -- have app/views/users/show.html.erb and app/views/posts/show.html.erb
        -- open simultaneously and "show.html.erb" tells you nothing.
        path = 1,
        symbols = { modified = ' ●', readonly = ' ' },
      },
    },
    lualine_x = {
      {
        'diagnostics',
        sources = { 'nvim_diagnostic' },
        symbols = { error = 'E', warn = 'W', info = 'I', hint = 'H' },
      },
      -- Which language servers are attached to THIS buffer. Worth the space:
      -- the most common LSP question is "is it even running?", and in a
      -- Rails+TS monorepo you genuinely need to know whether it's ruby_lsp,
      -- vtsls, eslint, or nothing at all.
      {
        function()
          local clients = vim.lsp.get_clients({ bufnr = 0 })
          if #clients == 0 then
            return ''
          end
          local names = vim.tbl_map(function(c)
            return c.name
          end, clients)
          table.sort(names)
          return ' ' .. table.concat(names, ',')
        end,
        -- Skip on narrow windows so the filename isn't crowded out.
        cond = function()
          return vim.o.columns > 100
        end,
      },
      'filetype',
    },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },

  -- Inactive windows: just the path. dim_inactive above handles the visual
  -- distinction; repeating the full component set here is noise.
  inactive_sections = {
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = { 'location' },
  },

  extensions = { 'quickfix', 'man', 'lazy' },
})
