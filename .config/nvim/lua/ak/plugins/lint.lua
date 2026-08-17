-- lua/ak/plugins/lint.lua
--
-- Linters NOT already covered by a language server. Short on purpose — the
-- obvious ones for this stack already run as LSPs:
--
--   eslint   -> lsp/eslint.lua (diagnostics + a fixAll code action)
--   rubocop  -> ruby-lsp runs it in-process (lsp/ruby_lsp.lua)
--
-- Adding either here gives DUPLICATE diagnostics on every line, and since both
-- copies name the same tool, `source = true` in diagnostics.lua won't even help
-- you tell them apart.

local lint = require('lint')

lint.linters_by_ft = {
  -- ruby-lsp attaches to eruby but doesn't lint the ERB itself, and rubocop
  -- can't parse a template. A missing gem is a silent no-op, so this costs
  -- nothing on projects without it.
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
-- nvim-lint hooks nothing itself. Deliberately NOT TextChanged: these linters
-- are external processes, so one per keystroke means dozens of concurrent
-- spawns. Save and insert-leave feel live enough.
vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave', 'BufReadPost' }, {
  group = vim.api.nvim_create_augroup('ak_lint', { clear = true }),
  callback = function()
    -- Flag set by the large-file guard in autocmds.lua.
    if vim.b.ak_big_file then
      return
    end

    -- No argument = use linters_by_ft for this filetype, doing nothing when
    -- there's no entry. pcall guards a linter binary that exists but errors.
    pcall(lint.try_lint)
  end,
})

vim.keymap.set('n', '<leader>ml', function()
  lint.try_lint()
  vim.notify('Linting triggered')
end, { desc = 'Lint current buffer' })
