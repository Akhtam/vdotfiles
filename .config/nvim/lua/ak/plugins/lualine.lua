-- lua/ak/plugins/lualine.lua
--
-- Statusline.

local lualine = require('lualine')

-- gitsigns publishes b:gitsigns_status_dict per buffer;
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
-- No plugin-updates component: vim.pack has no "are updates available"
-- query that works offline — finding out requires a network fetch, which is
-- what vim.pack.update() does interactively. So the component is dropped
-- rather than faked. Run :lua vim.pack.update() when you want to check.
local lualine_x = {
  { 'fileformat' },
  { 'filetype' },
}
for _, kind in ipairs({ 'mode', 'search' }) do
  local component = noice_component(kind, '#ff9e64')
  if component then
    table.insert(lualine_x, component)
  end
end

lualine.setup({
  options = {
    theme = 'tokyonight',

    -- Required for correctness: options.lua
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
    -- lualine_a and lualine_y are omitted, so they keep lualine's defaults: mode in a, progress in y.
    lualine_b = { { 'filename', path = 1 } },
    lualine_c = { { 'diff', source = diff_source } },
    lualine_x = lualine_x,
    lualine_z = {},
  },

  inactive_sections = {
    lualine_b = { { 'filename', path = 1 } },
  },

  -- No explorer extension: none ships for snacks' explorer, and
  -- `disabled_filetypes.statusline` above already covers its window.
  extensions = { 'quickfix', 'man' },
})
