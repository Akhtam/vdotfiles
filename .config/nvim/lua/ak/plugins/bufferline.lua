-- lua/ak/plugins/bufferline.lua
--
-- Your config, unchanged. In lazy.nvim you passed `opts`, which lazy forwards
-- to setup() for you; vim.pack has no such mechanism, so the call is explicit.

require('bufferline').setup({
  options = {
    -- "tabs" shows TABPAGES, not buffers. Worth being deliberate about,
    -- because the default ("buffers") lists every open file and turns the bar
    -- into a mess in a large project.
    --
    -- This pairs directly with the tab keymaps already in keymaps.lua:
    --   <leader>to  new tab        <leader>tn  next tab
    --   <leader>tx  close tab      <leader>tp  prev tab
    --   <leader>tf  current buffer in a new tab
    -- so the bar is a visual readout of maps you already have.
    mode = 'tabs',

    separator_style = 'slant',
  },
})
