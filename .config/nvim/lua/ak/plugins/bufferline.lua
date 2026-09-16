-- lua/ak/plugins/bufferline.lua
--
-- Tab bar. vim.pack has no `opts` shorthand, so setup() is called explicitly.

require('bufferline').setup({
  options = {
    -- "tabs" shows TABPAGES, not buffers. Worth being deliberate about,
    -- because the default ("buffers") lists every open file and turns the bar
    -- into a mess in a large project.
    --
    -- This pairs directly with the tab keymaps already in keymaps.lua:
    --   <leader>To  new tab        <leader>Tn  next tab
    --   <leader>Tx  close tab      <leader>Tp  prev tab
    --   <leader>Tf  current buffer in a new tab
    -- so the bar is a visual readout of maps you already have.
    mode = 'tabs',

    separator_style = 'slant',
  },
})
