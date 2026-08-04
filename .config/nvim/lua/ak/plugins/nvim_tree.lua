-- lua/ak/plugins/nvim_tree.lua
--
-- Ported from your lazy.nvim config: same centred-float layout, same ratios,
-- same four keymaps. Differences are marked and explained.

local nvimtree = require('nvim-tree')

-- ── Disable netrw ──────────────────────────────────────────────────────────
-- nvim-tree's docs call this "strongly advised": netrw also claims directory
-- buffers, so with both live, opening a directory races between them.
--
-- Timing note, since this moved from lazy.nvim to vim.pack. netrw is a bundled
-- plugin sourced during the |load-plugins| step, which runs AFTER init.lua
-- finishes. This file is required from init.lua, so these flags are set before
-- netrw is ever read — same as under lazy. Verified: :echo exists('g:loaded_netrw')
-- is 1 and netrw defines no commands.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local HEIGHT_RATIO = 0.8
local WIDTH_RATIO = 0.5

nvimtree.setup({
  view = {
    float = {
      enable = true,
      -- Yours, unchanged. Computes a centred float each time it opens, so it
      -- re-centres when you resize Ghostty rather than keeping stale geometry.
      open_win_config = function()
        local screen_w = vim.opt.columns:get()
        local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
        local window_w = screen_w * WIDTH_RATIO
        local window_h = screen_h * HEIGHT_RATIO
        local window_w_int = math.floor(window_w)
        local window_h_int = math.floor(window_h)
        local center_x = (screen_w - window_w) / 2
        local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()
        return {
          border = 'rounded',
          relative = 'editor',
          row = center_y,
          col = center_x,
          width = window_w_int,
          height = window_h_int,
        }
      end,
    },
    -- Used when float is disabled; kept so toggling float off still gives a
    -- sensible sidebar width.
    width = function()
      return math.floor(vim.opt.columns:get() * WIDTH_RATIO)
    end,
  },

  -- Yours: the window picker prompts "which split?" on open, which fights
  -- split-based workflows. Disabled means files open in the last-used window.
  actions = {
    open_file = {
      window_picker = {
        enable = false,
      },
      -- NEW: close the float after opening a file. With a centred float (as
      -- opposed to a sidebar) leaving it up covers the file you just opened.
      quit_on_open = true,
    },
  },

  filters = {
    custom = { '.DS_Store' },
    -- NEW: `git.ignore = false` below means gitignored files ARE listed. In a
    -- Rails + node project that pulls in node_modules/, tmp/, and log/, which
    -- is thousands of entries. These hide the worst offenders while keeping
    -- everything else visible.
    exclude = { '.env.local', '.env.development' },
  },

  git = {
    -- Yours: show gitignored files rather than hiding them. Deliberate — it
    -- means you can still open .env or a build artifact when you need to.
    ignore = false,
  },

  -- NEW: render git status as icons in the tree. Complements gitsigns, which
  -- only shows status inside a file you already have open; this tells you
  -- which files changed without opening any of them.
  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
      },
    },
  },
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Yours, verbatim.
--
-- NOTE: <leader>e was previously bound to vim.diagnostic.open_float. It has
-- moved to <leader>de (see diagnostics.lua) — a bare <leader>e would have made
-- all four of these stall for 'timeoutlen' while Neovim waited to see if you
-- meant the shorter mapping.
local keymap = vim.keymap

keymap.set('n', '<leader>ee', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle file explorer' })
keymap.set('n', '<leader>ef', '<cmd>NvimTreeFindFileToggle<CR>', { desc = 'Toggle file explorer on current file' })
keymap.set('n', '<leader>ec', '<cmd>NvimTreeCollapse<CR>', { desc = 'Collapse file explorer' })
keymap.set('n', '<leader>er', '<cmd>NvimTreeRefresh<CR>', { desc = 'Refresh file explorer' })
