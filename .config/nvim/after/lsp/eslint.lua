-- after/lsp/eslint.lua — local ESLint overrides
--
-- Merges with nvim-lspconfig's lsp/eslint.lua, which supplies cmd
-- (vscode-eslint-language-server, from vscode-langservers-extracted), the
-- filetype list, root markers covering flat config too, and an on_attach that
-- creates :LspEslintFixAll.
--
-- The LSP rather than eslint_d via nvim-lint, because the server gives code
-- actions: `gra` on a lint error offers the fix and save-time fixes apply all
-- file. A CLI linter only emits diagnostics.
--
-- No on_attach here: a function field REPLACES rather than merges, so defining
-- one would drop lspconfig's. Fix-on-save lives in lua/ak/lsp.lua's LspAttach
-- callback instead, which leaves lspconfig's on_attach intact.

---@type vim.lsp.Config
return {
  settings = {
    -- Run eslint against the file's own directory rather than the workspace
    -- root, so per-package configs in a monorepo are respected.
    workingDirectory = { mode = 'auto' },

    -- Format via eslint is off: prettierd owns formatting (see conform.lua).
    -- Leaving this on means eslint --fix and prettier can disagree about the
    -- same file on every save, each undoing the other.
    format = false,
  },
}
