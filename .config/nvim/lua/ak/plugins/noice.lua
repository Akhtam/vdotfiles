-- lua/ak/plugins/noice.lua
--
-- Replaces the cmdline, messages, and popupmenu with floating windows.
--
-- The toast backend needs no wiring: noice tries `{ "snacks", "notify" }` in
-- order and takes the first available, LAZILY — on the first notification, not
-- at setup() — so it doesn't matter that plugins/init.lua requires this file
-- before plugins/snacks.lua. snacks' `notifier` wins automatically.

local noice = require('noice')

noice.setup({
  lsp = {
    -- Render LSP markdown (hover docs, signature help) through treesitter
    -- rather than noice's own stylizer, so code blocks in documentation get
    -- real syntax highlighting from the parsers we installed.
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      -- No stylize_markdown override: deprecated in 0.12, and core's hover no
      -- longer calls it.

      -- Do NOT add ['cmp.entry.get_documentation'] here, despite most examples
      -- carrying it: that override requires nvim-cmp, and this config uses
      -- blink.cmp, which renders and treesitter-highlights its own doc window.
    },
  },

  presets = {
    bottom_search = true, -- classic bottom cmdline for / and ?
    long_message_to_split = true, -- long messages open in a split, not a toast
    inc_rename = false,
    lsp_doc_border = false,
  },

  views = {
    -- Centred command palette.
    cmdline_popup = {
      position = { row = '50%', col = '50%' },
      size = { width = 60, height = 'auto' },
    },
    popupmenu = {
      relative = 'editor',
      position = { row = '62%', col = '50%' },
      size = { width = 60, height = 10 },
      border = {
        style = 'rounded',
        padding = { 0, 1 },
      },
      win_options = {
        winhighlight = { Normal = 'Normal', FloatBorder = 'DiagnosticInfo' },
      },
    },
    mini = {
      timeout = 4000,
    },
  },
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- <leader>n is shared with <leader>nr (toggle relativenumber) in keymaps.lua.
-- No conflict — all four are two keys deep, so nothing waits on 'timeoutlen'.
vim.keymap.set('n', '<leader>nl', function()
  noice.cmd('last')
end, { desc = 'Show Noice last message' })

vim.keymap.set('n', '<leader>ne', function()
  noice.cmd('errors')
end, { desc = 'Show Noice errors' })

vim.keymap.set('n', '<leader>nh', function()
  noice.cmd('pick')
end, { desc = 'Show Noice history' })
