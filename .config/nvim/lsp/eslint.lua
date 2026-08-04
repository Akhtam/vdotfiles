-- lsp/eslint.lua — ESLint as a language server
--
-- Merges with nvim-lspconfig's lsp/eslint.lua, which supplies cmd
-- (vscode-eslint-language-server, from the vscode-langservers-extracted package
-- you installed), the filetype list, and root markers covering every eslint
-- config filename including flat config.
--
-- Why the LSP rather than eslint_d via nvim-lint: the server gives you code
-- actions. `gra` on a lint error offers the actual fix, and EslintFixAll fixes
-- the whole file — neither of which a CLI linter can provide, since it only
-- emits diagnostics.

---@type vim.lsp.Config
return {
  settings = {
    -- Run eslint against the file's own directory rather than the workspace
    -- root, so per-package configs in a monorepo are respected.
    workingDirectories = { mode = 'auto' },

    -- Format via eslint is off: prettierd owns formatting (see conform.lua).
    -- Leaving this on means eslint --fix and prettier can disagree about the
    -- same file on every save, each undoing the other.
    format = false,
  },

  on_attach = function(client, bufnr)
    -- Apply eslint's auto-fixable rules on save — import ordering, unused
    -- imports, missing hook dependencies where the rule is fixable.
    --
    -- This is a SEPARATE mechanism from conform's format_on_save, and the
    -- order matters: BufWritePre autocmds run in registration order, and
    -- conform's is registered when conform.setup() runs. Fixes here are code
    -- changes rather than formatting, so prettierd running afterwards to
    -- re-format the result is the correct sequence.
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = vim.api.nvim_create_augroup('ak_eslint_fix_' .. bufnr, { clear = true }),
      buffer = bufnr,
      callback = function()
        -- EslintFixAll is defined by nvim-lspconfig's eslint config. pcall
        -- because it's absent if the server hasn't finished initialising, and
        -- a failed fix must never block the write.
        pcall(vim.cmd, 'EslintFixAll')
      end,
    })
  end,
}
