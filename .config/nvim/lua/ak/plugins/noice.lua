-- lua/ak/plugins/noice.lua
--
-- Replaces the cmdline, messages, and popupmenu with floating windows.
-- Your config, with one override removed — marked CHANGED.

-- nvim-notify is noice's toast backend. In your lazy config this was set via
-- the dependency's `opts`; vim.pack has no equivalent, so it's an explicit
-- setup call. It must run BEFORE noice.setup(), because noice checks for a
-- configured notify backend at setup time.
require('notify').setup({
  -- Toasts stack upward from the bottom. Keeps them clear of the cmdline
  -- popup, which the views block below positions at 50% height.
  top_down = false,
})

local noice = require('noice')

noice.setup({
  lsp = {
    -- Render LSP markdown (hover docs, signature help) through treesitter
    -- rather than noice's own stylizer, so code blocks in documentation get
    -- real syntax highlighting from the parsers we installed.
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      ['vim.lsp.util.stylize_markdown'] = true,

      -- CHANGED: your config also had
      --     ['cmp.entry.get_documentation'] = true
      -- That override targets nvim-cmp, which this config does not use — we're
      -- on blink.cmp. noice's own docs mark that line "requires
      -- hrsh7th/nvim-cmp". Leaving it in makes noice try to hook a module that
      -- isn't there.
      --
      -- Nothing is lost: blink renders its own documentation window and
      -- already highlights it via treesitter.
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
-- Yours, verbatim.
--
-- Note these live under <leader>n, which also holds <leader>nr (toggle
-- relativenumber) from keymaps.lua. No conflict — all four are two keys deep,
-- so nothing waits on 'timeoutlen'.
vim.keymap.set('n', '<leader>nl', function()
  noice.cmd('last')
end, { desc = 'Show Noice last message' })

vim.keymap.set('n', '<leader>ne', function()
  noice.cmd('errors')
end, { desc = 'Show Noice errors' })

vim.keymap.set('n', '<leader>nh', function()
  noice.cmd('pick')
end, { desc = 'Show Noice history' })
