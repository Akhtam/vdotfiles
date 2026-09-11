-- after/lsp/eslint.lua — local ESLint overrides
--
-- Merges with nvim-lspconfig's lsp/eslint.lua, which supplies cmd
-- (vscode-eslint-language-server, from vscode-langservers-extracted), the
-- filetype list, and root markers covering flat config too.
--
-- The LSP rather than eslint_d via nvim-lint, because the server gives code
-- actions: `gra` on a lint error offers the fix and save-time fixes apply all
-- file. A CLI linter only emits diagnostics.

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

  on_attach = function(client, bufnr)
    -- Apply eslint's auto-fixable rules on save — import ordering, unused
    -- imports, fixable hook-dependency rules.
    --
    -- A SEPARATE mechanism from conform, which currently registers no
    -- BufWritePre at all (its format_on_save is commented out). If you turn
    -- that back on, ORDER MATTERS: BufWritePre autocmds run in registration
    -- order, and these fixes are code changes, so prettierd must run afterwards
    -- to re-format the result.
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = vim.api.nvim_create_augroup('ak_eslint_fix_' .. bufnr, { clear = true }),
      buffer = bufnr,
      callback = function()
        if vim.g.ak_disable_eslint_fix or vim.b[bufnr].ak_disable_eslint_fix then
          return
        end

        local response, reason = client:request_sync('workspace/executeCommand', {
          command = 'eslint.applyAllFixes',
          arguments = {
            {
              uri = vim.uri_from_bufnr(bufnr),
              version = vim.lsp.util.buf_versions[bufnr],
            },
          },
        }, nil, bufnr)

        if not response then
          vim.notify_once('ESLint fix-on-save failed: ' .. (reason or 'no response'), vim.log.levels.WARN)
        elseif response.err then
          vim.notify_once('ESLint fix-on-save failed: ' .. vim.inspect(response.err), vim.log.levels.WARN)
        end
      end,
    })
  end,
}
