-- lua/ak/plugins/lint.lua
--
-- Linters that are NOT already covered by a language server.
--
-- This file is short on purpose. The obvious linters for your stack both
-- already run as LSPs:
--
--   eslint   -> lsp/eslint.lua (diagnostics + a fixAll code action)
--   rubocop  -> ruby-lsp runs it in-process (linters = {'rubocop'} in
--               lsp/ruby_lsp.lua)
--
-- Running either a second time through nvim-lint would produce DUPLICATE
-- diagnostics on every line — the same complaint from two sources, which is
-- why `source = true` in diagnostics.lua wouldn't even help you tell them
-- apart. So nvim-lint is left to cover the gaps instead.

local lint = require('lint')

lint.linters_by_ft = {
  -- ERB templates. ruby-lsp attaches to eruby but does not lint the ERB
  -- itself, and rubocop can't parse a template. erb_lint catches unclosed
  -- tags and Rails-specific view issues.
  --
  -- Only runs if the gem is present; a missing linter is a silent no-op, so
  -- this costs nothing on projects that don't use it.
  eruby = { 'erb_lint' },

  -- Dockerfiles and shell scripts — neither has an LSP in our enable list.
  dockerfile = { 'hadolint' },
  sh = { 'shellcheck' },
  bash = { 'shellcheck' },

  -- NOTE what's absent and why:
  --   javascript/typescript  -> lsp/eslint.lua owns these
  --   ruby                   -> ruby-lsp owns this
  -- Adding them here is the single most common way to end up with every
  -- warning displayed twice.
}

-- ── When to lint ───────────────────────────────────────────────────────────
-- nvim-lint does not hook anything itself; you choose the trigger.
--
-- BufWritePost and InsertLeave, deliberately NOT TextChanged: these linters
-- are external processes, and running one per keystroke means dozens of
-- concurrent spawns. On save and on leaving insert mode is frequent enough to
-- feel live without that.
vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave', 'BufReadPost' }, {
  group = vim.api.nvim_create_augroup('ak_lint', { clear = true }),
  callback = function()
    -- Skip the huge generated files flagged in autocmds.lua.
    if vim.b.ak_big_file then
      return
    end

    -- try_lint() with no argument uses linters_by_ft for the current
    -- filetype, and does nothing when there's no entry. The pcall guards
    -- against a linter binary that exists but errors on startup.
    pcall(lint.try_lint)
  end,
})

vim.keymap.set('n', '<leader>ml', function()
  lint.try_lint()
  vim.notify('Linting triggered')
end, { desc = 'Lint current buffer' })
