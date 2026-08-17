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
  -- End-of-line virtual text on every problem line, cursor line included. The
  -- trade: long messages truncate at the window edge, which TypeScript generic
  -- errors routinely do. Two ways to read the rest:
  --
  --   <leader>xe   float with the full text (source included)
  --   <leader>xv   toggle to virtual_lines, message on its own lines below
  --
  -- KEEP IN SYNC with the virtual_text table in the <leader>xv toggle below,
  -- which restates these two values.
  virtual_text = {
    -- Leading marker so the message reads as separate from the code rather
    -- than as a continuation of the line.
    prefix = '●',
    spacing = 2,

    -- `severity_sort` does NOT belong here — it's a field of the top-level
    -- Opts (and Opts.Float), and nested under virtual_text it is silently
    -- ignored. The top-level `severity_sort = true` below does the job.
  },

  -- Off, so the current line doesn't render the same diagnostic twice — once
  -- beside it and once beneath. <leader>xv swaps which of the two is active.
  virtual_lines = false,

  -- ── Gutter signs ─────────────────────────────────────────────────────────
  -- The 0.11+ table form, which supersedes vim.fn.sign_define('DiagnosticSign…').
  -- Letters rather than nerd-font glyphs: they render in any font and stay
  -- legible at the sign column's one-cell width.
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
  -- Most severe wins a shared line. Without this a stylistic rubocop hint can
  -- mask a real error, since the last to arrive wins rather than the worst.
  severity_sort = true,

  -- Already the default, stated because it's what people reach for when
  -- diagnostics feel "laggy" — turning it ON makes errors flicker as you type.
  update_in_insert = false,

  -- ── Hover float ──────────────────────────────────────────────────────────
  float = {
    -- `border` omitted on purpose: options.lua sets winborder = 'rounded'
    -- globally, which covers every float including this one.
    --
    -- source = true costs horizontal space but earns it here: a Ruby buffer can
    -- have ruby_lsp AND rubocop-via-nvim-lint attached, a TSX buffer vtsls AND
    -- eslint, and "which tool said that?" decides whether you edit
    -- .rubocop.yml, .eslintrc or tsconfig.json.
    source = true,
    header = '',
    prefix = '',
  },

  -- ── ]d / [d behaviour ────────────────────────────────────────────────────
  -- Built-in maps as of 0.11 (keymaps.lua deliberately doesn't redefine them);
  -- this configures what they do.
  jump = {
    -- Pop the float on arrival, so ]d doesn't just move the cursor and leave
    -- you to press something else to find out what's wrong.
    float = true,
    wrap = true,
  },
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
local map = vim.keymap.set

-- All four maps here live under <leader>x, not <leader>d: dap owns <leader>d
-- (the conventional debug prefix, and it has nine maps wanting a short one).
--
-- Full diagnostic float for the current line, on demand — for when
-- virtual_lines is off, or to read a message without moving the cursor.
map('n', '<leader>xe', vim.diagnostic.open_float, { desc = 'Show line diagnostics' })

-- Send every diagnostic in the buffer to the location list. The quickfix maps
-- in keymaps.lua (]q / [q) then walk them. `setloclist` is per-window, so this
-- doesn't clobber a quickfix list you're already working through.
map('n', '<leader>xl', vim.diagnostic.setloclist, { desc = 'Diagnostics to loclist' })

-- Swap between full-message (virtual_lines) and end-of-line (virtual_text)
-- rendering, for when the extra lines shift code around more than truncation
-- costs you. NOTE the virtual_text table below restates prefix/spacing from the
-- config at the top of this file — change one and change both.
map('n', '<leader>xv', function()
  local cfg = vim.diagnostic.config()
  local using_lines = cfg.virtual_lines ~= false
  vim.diagnostic.config({
    virtual_lines = not using_lines and { current_line = true } or false,
    virtual_text = using_lines and { prefix = '●', spacing = 2 } or false,
  })
  vim.notify('Diagnostics: ' .. (using_lines and 'virtual text' or 'virtual lines'))
end, { desc = 'Toggle diagnostic display style' })

-- Silence diagnostics entirely for the current buffer. For the times you're
-- mid-refactor and the errors are all things you already know about.
map('n', '<leader>xt', function()
  local enabled = vim.diagnostic.is_enabled({ bufnr = 0 })
  vim.diagnostic.enable(not enabled, { bufnr = 0 })
  vim.notify('Diagnostics ' .. (enabled and 'disabled' or 'enabled') .. ' for buffer')
end, { desc = 'Toggle diagnostics for buffer' })
