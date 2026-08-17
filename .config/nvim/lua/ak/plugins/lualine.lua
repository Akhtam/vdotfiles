-- lua/ak/plugins/lualine.lua
--
-- Your lualine config. Three things could not be carried over verbatim; each is
-- marked CHANGED below with the reason.

local lualine = require('lualine')

-- Yours, unchanged. gitsigns publishes b:gitsigns_status_dict per buffer;
-- reading it directly means the diff counts come from the same source as the
-- gutter signs, rather than lualine shelling out to git a second time.
-- Returns nil when gitsigns hasn't attached (non-git buffers), which lualine
-- treats as "no diff to show".
local diff_source = function()
  local gitsigns = vim.b.gitsigns_status_dict
  if gitsigns then
    return {
      added = gitsigns.added,
      modified = gitsigns.changed,
      removed = gitsigns.removed,
    }
  end
end

-- CHANGED: your version called vim.fn['copilot#Enabled']() directly. Copilot
-- isn't installed here, and calling a Vimscript function that doesn't exist
-- raises E117 — which, inside a statusline component, redraws several times a
-- second. The exists() guard makes the component render nothing until you
-- install copilot, and light up automatically if you ever do.
local copilot_status = function()
  if vim.fn.exists('*copilot#Enabled') == 0 then
    return ''
  end
  return vim.fn['copilot#Enabled']() == 1 and ' ' or ' '
end

-- noice components are guarded the same way. noice IS installed, but if its
-- setup ever fails this keeps the statusline rendering instead of erroring on
-- every redraw. `pcall` at module scope rather than in the component, so the
-- cost is paid once.
local ok_noice, noice = pcall(require, 'noice')

local noice_component = function(kind, color)
  if not ok_noice then
    return nil
  end
  return {
    noice.api.status[kind].get,
    cond = noice.api.status[kind].has,
    color = { fg = color },
  }
end

-- Build lualine_x conditionally, since the noice entries may be absent.
--
-- CHANGED: your first entry was lazy_status.updates / lazy_status.has_updates,
-- which comes from lazy.nvim. This config uses vim.pack, so that module does
-- not exist and requiring it is a hard error at startup.
--
-- There is no drop-in replacement: vim.pack has no "are updates available"
-- query that works offline — finding out requires a network fetch, which is
-- what vim.pack.update() does interactively. So the component is dropped
-- rather than faked. Run :lua vim.pack.update() when you want to check.
local lualine_x = {
  { 'fileformat' },
  { 'filetype' },
}
for _, c in ipairs({ noice_component('mode', '#ff9e64'), noice_component('search', '#ff9e64') }) do
  table.insert(lualine_x, c)
end

lualine.setup({
  options = {
    theme = 'tokyonight',

    -- Not in your original, but required for correctness here: options.lua
    -- sets laststatus = 3 (one global statusline). Without globalstatus,
    -- lualine draws per-window and you get a doubled or empty bar.
    globalstatus = true,

    disabled_filetypes = {
      -- 'snacks_picker_*' covers every picker AND the explorer (it's a picker
      -- under the hood — see explorer.lua) — replaces the old 'NvimTree'
      -- entry, plus every other picker window that never needed one before.
      statusline = {
        'snacks_picker_input',
        'snacks_picker_list',
        'snacks_picker_preview',
        -- All six panes of nvim-dap-ui's default layout — scopes/breakpoints/
        -- stacks/watches in the sidebar, repl/console along the bottom. Miss
        -- one and that pane alone draws a statusline the other five suppress.
        -- Note the REPL's filetype is 'dap-repl' (nvim-dap owns that buffer),
        -- not 'dapui_repl' like the rest.
        'dapui_scopes',
        'dapui_breakpoints',
        'dapui_stacks',
        'dapui_watches',
        'dapui_console',
        'dap-repl',
      },
    },
  },

  sections = {
    -- Note lualine_a and lualine_y are omitted here exactly as in your config,
    -- so they keep lualine's defaults: mode in a, progress in y.
    lualine_b = { { 'filename', path = 1 } },
    lualine_c = { { 'diff', source = diff_source } },
    lualine_x = lualine_x,
    lualine_z = {
      {
        copilot_status,
        -- CHANGED: yours was #2E3440, which is a Nord palette colour — dark
        -- grey. On TokyoNight Moon's background (#222436) it is very nearly
        -- invisible. Swapped for Moon's own green so the indicator reads.
        color = { fg = '#c3e88d' },
      },
    },
  },

  inactive_sections = {
    lualine_b = { { 'filename', path = 1 } },
  },

  -- 'nvim-tree' dropped: no lualine extension ships for snacks' explorer, and
  -- `disabled_filetypes.statusline` above already covers its window.
  extensions = { 'quickfix', 'man' },
})
