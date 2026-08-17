-- lua/ak/lsp.lua
--
-- Native LSP wiring for Neovim 0.12. No nvim-lspconfig framework: we use
-- vim.lsp.config() / vim.lsp.enable(), and the per-server settings live in
-- ~/.config/nvim/lsp/<name>.lua.
--
-- How a server is resolved (`:h lsp-config-merge`), in increasing priority:
--   1. built-in defaults
--   2. every lsp/<name>.lua on the 'runtimepath'  <- nvim-lspconfig supplies
--                                                    these: cmd, filetypes,
--                                                    root_markers
--   3. every after/lsp/<name>.lua on the runtimepath
--   4. vim.lsp.config() calls                     <- the '*' block below
--
-- Our own lsp/<name>.lua files sit at layer 2 alongside nvim-lspconfig's. Since
-- ours are earlier on the runtimepath they win, and we only need to specify the
-- fields we actually want to change — cmd and filetypes come free.

-- ── Defaults applied to every server ───────────────────────────────────────
vim.lsp.config('*', {
  -- What this client can do. blink.cmp extends Neovim's baseline with snippet,
  -- resolve and insert-replace support; without it servers downgrade to
  -- plain-text completions.
  --
  -- Guarded so a broken or absent blink doesn't take LSP down with it.
  capabilities = (function()
    local ok, blink = pcall(require, 'blink.cmp')
    if ok and blink.get_lsp_capabilities then
      return blink.get_lsp_capabilities()
    end
    return nil -- fall back to Neovim's built-in capabilities
  end)(),

  -- Fallback project root when a server's own lsp/<name>.lua doesn't specify
  -- markers. Per-server files override this with something more precise
  -- (package.json, Gemfile, tsconfig.json).
  root_markers = { '.git' },
})

-- ── Servers to activate ────────────────────────────────────────────────────
-- Each name resolves to lsp/<name>.lua on the runtimepath. Enabling a server
-- whose binary isn't installed is a silent no-op, not an error — so this list
-- can safely include things you only sometimes have.
vim.lsp.enable({
  'vtsls', -- TypeScript / JavaScript / React
  'eslint', -- JS/TS linting as LSP (gives you fixAll as a code action)
  'ruby_lsp', -- Ruby / Rails
  'lua_ls', -- for editing this config
  'jsonls', -- package.json / tsconfig schema validation
  'yamlls', -- CI configs, docker-compose
  'html',
  'cssls',
})

-- ── Per-buffer setup on attach ─────────────────────────────────────────────
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('ak_lsp_attach', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end

    local buf = ev.buf
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = 'LSP: ' .. desc })
    end

    -- ── Keymaps ──
    -- ONLY what 0.12 doesn't already provide. These are global defaults created
    -- unconditionally at startup:
    --
    --   gra  code action (n+v)     grn  rename        grr  references
    --   gri  implementation        grt  type def      grx  codelens run
    --   gO   document symbols      K    hover         CTRL-S signature (insert)
    --   ]d / [d  diagnostics       gx   documentLink
    --
    -- `gd` is NOT among them — plain `gd` is Vim's local-declaration motion,
    -- which is why it's the one worth overriding.
    map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
    map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')

    -- Workspace-wide symbol search; gO covers the current document only.
    -- <leader>wy not <leader>ws — auto-session owns ws, and both under one
    -- prefix would stall for 'timeoutlen' on every press.
    map('n', '<leader>wy', vim.lsp.buf.workspace_symbol, 'Workspace symbols')

    -- ── Inlay hints ──
    -- Parameter names and inferred types inline — valuable in TypeScript, where
    -- `const x = useMemo(...)` tells you nothing about x. Off by default: they
    -- reflow the code visually.
    if client:supports_method('textDocument/inlayHint') then
      map('n', '<leader>th', function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
      end, 'Toggle inlay hints')
    end

    -- ── Document colour ──
    -- Colour swatches beside colour values — with tailwindcss, `bg-slate-800`
    -- shows its colour. Built into 0.12.
    if client:supports_method('textDocument/documentColor') then
      -- Second arg is a FILTER TABLE, not a bufnr. All four vim.lsp.*.enable()
      -- functions take (enable: boolean, filter: table); a bare number raises
      -- "filter: expected table, got number".
      vim.lsp.document_color.enable(true, { bufnr = buf })
    end

    -- ── Linked editing ──
    -- Rename a JSX/HTML opening tag and the closing tag follows. Built into
    -- 0.12; what nvim-ts-autotag existed to do.
    if client:supports_method('textDocument/linkedEditingRange') then
      vim.lsp.linked_editing_range.enable(true, { bufnr = buf })
    end

    -- ── Code lens ──
    -- Servers that publish lenses (ruby-lsp does, for test blocks) show them
    -- inline; grx runs the one under the cursor.
    --
    -- enable(), NOT refresh() — the latter is deprecated in 0.12, and enable()
    -- manages its own refresh cycle, so the BufEnter/InsertLeave/TextChanged
    -- autocmds older configs wire up by hand are redundant.
    if client:supports_method('textDocument/codeLens') then
      vim.lsp.codelens.enable(true, { bufnr = buf })
    end

    -- Document highlight is deliberately absent: snacks.nvim's `words` module
    -- makes the same documentHighlight request and checks supports_method on
    -- every cursor move, so no per-client wiring belongs here. Adding one back
    -- gives two listeners fighting over the highlight.
  end,
})

-- ── Cleanup on detach ──────────────────────────────────────────────────────
-- Clears reference highlights left by the detaching client; otherwise a stale
-- underline survives :LspRestart with no client left to clear it.
vim.api.nvim_create_autocmd('LspDetach', {
  group = vim.api.nvim_create_augroup('ak_lsp_detach', { clear = true }),
  callback = function()
    vim.lsp.buf.clear_references()
  end,
})

-- ── Commands ───────────────────────────────────────────────────────────────
-- Restart every client attached to the current buffer. The common need is
-- after editing tsconfig.json or a Gemfile, when the server's cached project
-- model is stale.
vim.api.nvim_create_user_command('LspRestart', function()
  local buf = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    local name = client.name
    client:stop()
    vim.defer_fn(function()
      vim.lsp.enable(name)
      vim.cmd('edit') -- re-trigger FileType so the client re-attaches
    end, 500)
  end
end, { desc = 'Restart LSP clients for this buffer' })

-- What is actually attached here, and does it do what I think?
vim.api.nvim_create_user_command('LspInfo', function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    print('No LSP clients attached to this buffer')
    return
  end
  for _, c in ipairs(clients) do
    print(('%s  (id %d)  root: %s'):format(c.name, c.id, c.root_dir or 'n/a'))
  end
end, { desc = 'Show LSP clients for this buffer' })
