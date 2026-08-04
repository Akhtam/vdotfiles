-- lua/ak/diagnostics.lua
--
-- How diagnostics are DISPLAYED. Where they come from (LSP servers, nvim-lint)
-- is configured elsewhere; this file is purely presentation, which is why it
-- can run before any client attaches.
--
-- Neovim 0.12 defaults worth knowing, since they shape what's set below:
--   signs             on
--   underline         on
--   virtual_text      OFF
--   virtual_lines     OFF   (built in since 0.11 — no plugin needed)
--   update_in_insert  OFF   (correct: diagnostics updating mid-keystroke is
--                            maddening, and it's why we don't touch it)

local severity = vim.diagnostic.severity

vim.diagnostic.config({
  -- ── Inline message display ───────────────────────────────────────────────
  -- The central choice here, and it's a real trade.
  --
  -- virtual_text puts a truncated message at end-of-line. It's compact but it
  -- lies by omission: a TypeScript "Type 'X' is not assignable to type 'Y'"
  -- error involving generics runs to several hundred characters and you see
  -- the first forty.
  --
  -- virtual_lines renders the full message on its own lines beneath the code.
  -- Scoped to `current_line`, you get the complete text exactly where you're
  -- working, and nothing anywhere else. Other problem lines are still marked
  -- by their sign in the gutter and their underline.
  --
  -- Toggle to end-of-line style with <leader>dv if you'd rather have it.
  virtual_text = false,
  virtual_lines = { current_line = true },

  -- ── Gutter signs ─────────────────────────────────────────────────────────
  -- The 0.11+ table form. The old `vim.fn.sign_define('DiagnosticSignError',…)`
  -- approach still works but is superseded; this is the supported spelling.
  --
  -- Letters rather than nerd-font glyphs, matching the lualine symbols in
  -- ui.lua so the gutter and statusline speak the same language.
  signs = {
    text = {
      [severity.ERROR] = 'E',
      [severity.WARN] = 'W',
      [severity.INFO] = 'I',
      [severity.HINT] = 'H',
    },
    -- Line-number colouring, so a problem is visible even where the sign
    -- column is occupied by a gitsigns hunk marker.
    numhl = {
      [severity.ERROR] = 'DiagnosticSignError',
      [severity.WARN] = 'DiagnosticSignWarn',
    },
  },

  underline = true,

  -- ── Ordering ─────────────────────────────────────────────────────────────
  -- When several diagnostics share a line, show the most severe. Without this
  -- a stylistic rubocop hint can mask a genuine error on the same line, since
  -- the last one to arrive wins rather than the worst one.
  severity_sort = true,

  -- Already the default; stated explicitly because it's the setting people
  -- reach for when diagnostics feel "laggy", and turning it ON is almost
  -- always the wrong fix — it makes errors flicker as you type an identifier.
  update_in_insert = false,

  -- ── Hover float ──────────────────────────────────────────────────────────
  float = {
    -- `border` is omitted on purpose: options.lua sets winborder = 'rounded'
    -- globally in 0.12, which covers every float including this one.
    source = true, -- ALWAYS show which tool produced the message.
    header = '',
    prefix = '',
  },

  -- ── ]d / [d behaviour ────────────────────────────────────────────────────
  -- These maps are built in as of 0.11 (keymaps.lua deliberately doesn't
  -- redefine them); this configures what they do.
  jump = {
    -- Pop the float on arrival. Otherwise ]d moves the cursor and you still
    -- have to press something to find out what's wrong.
    float = true,
    wrap = true,
  },
})

-- `source = true` above deserves justification, because it costs horizontal
-- space on every message. In this config a single Ruby buffer can have
-- ruby_lsp AND rubocop-via-nvim-lint attached, and a TSX buffer can have vtsls
-- AND eslint. When something reports a complaint you disagree with, the first
-- question is always "which tool said that?" — because the answer determines
-- whether you edit .rubocop.yml, .eslintrc, or tsconfig.json.

-- ── Keymaps ────────────────────────────────────────────────────────────────
local map = vim.keymap.set

-- Full diagnostic float for the current line, on demand. Useful when
-- virtual_lines is toggled off, or to read a message without moving the cursor.
--
-- MOVED from <leader>e to <leader>de. nvim-tree owns the <leader>e namespace
-- (<leader>ee, <leader>ef, <leader>ec, <leader>er), and a bare <leader>e
-- alongside them would make every tree keystroke stall for 'timeoutlen'
-- (300ms) while Neovim waits to see whether you meant the shorter mapping.
-- Living under <leader>d groups it with the other diagnostic maps anyway.
map('n', '<leader>de', vim.diagnostic.open_float, { desc = 'Show line diagnostics' })

-- Send every diagnostic in the buffer to the location list. The quickfix maps
-- in keymaps.lua (]q / [q) then walk them. `setloclist` is per-window, so this
-- doesn't clobber a quickfix list you're already working through.
map('n', '<leader>dl', vim.diagnostic.setloclist, { desc = 'Diagnostics to loclist' })

-- Swap between full-message (virtual_lines) and end-of-line (virtual_text)
-- rendering. Handy when you're reading a wide diff and the extra lines shift
-- code around more than the truncation costs you.
map('n', '<leader>dv', function()
  local cfg = vim.diagnostic.config()
  local using_lines = cfg.virtual_lines ~= false
  vim.diagnostic.config({
    virtual_lines = not using_lines and { current_line = true } or false,
    virtual_text = using_lines and { spacing = 2, prefix = '●' } or false,
  })
  vim.notify('Diagnostics: ' .. (using_lines and 'virtual text' or 'virtual lines'))
end, { desc = 'Toggle diagnostic display style' })

-- Silence diagnostics entirely for the current buffer. For the times you're
-- mid-refactor and the errors are all things you already know about.
map('n', '<leader>dt', function()
  local enabled = vim.diagnostic.is_enabled({ bufnr = 0 })
  vim.diagnostic.enable(not enabled, { bufnr = 0 })
  vim.notify('Diagnostics ' .. (enabled and 'disabled' or 'enabled') .. ' for buffer')
end, { desc = 'Toggle diagnostics for buffer' })
