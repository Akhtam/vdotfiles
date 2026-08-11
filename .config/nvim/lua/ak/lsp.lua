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
  -- Tell servers what this client can do. Neovim supplies a solid baseline;
  -- blink.cmp extends it with the completion features it implements
  -- (snippet support, resolve support, insert-replace edits). Without this,
  -- servers downgrade to plain-text completions with no snippets.
  --
  -- Guarded: this file must still load if blink is absent or broken, otherwise
  -- a completion plugin failure takes LSP down with it.
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
    -- ONLY what 0.12 doesn't already provide. Verified against `nvim --clean`;
    -- these are global defaults created unconditionally at startup:
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

    -- Workspace-wide symbol search. gO covers the current document only, and
    -- in a Rails app "where is UserMailer" is a workspace question.
    --
    -- MOVED from <leader>ws to <leader>wy: auto-session claims <leader>ws for
    -- its session picker. Two maps under the same prefix would both work, but
    -- <leader>ws would stall for 'timeoutlen' waiting to see which you meant.
    map('n', '<leader>wy', vim.lsp.buf.workspace_symbol, 'Workspace symbols')

    -- ── Inlay hints ──
    -- Parameter names and inferred types rendered inline. Genuinely valuable
    -- in TypeScript, where `const x = useMemo(...)` tells you nothing about
    -- what x is. Off by default because they reflow your code visually and
    -- that's disorienting until you want them.
    if client:supports_method('textDocument/inlayHint') then
      map('n', '<leader>th', function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
      end, 'Toggle inlay hints')
    end

    -- ── Document colour ──
    -- Renders actual colour swatches for colour values. With tailwindcss this
    -- means `bg-slate-800` shows the colour beside it. Built into 0.12 — this
    -- used to require nvim-colorizer or tailwind-tools.
    if client:supports_method('textDocument/documentColor') then
      -- Second arg is a FILTER TABLE, not a bufnr. All four of these
      -- vim.lsp.*.enable() functions share the signature
      -- (enable: boolean, filter: table) — passing a bare number raises
      -- "filter: expected table, got number" from vim/lsp/_capability.lua.
      vim.lsp.document_color.enable(true, { bufnr = buf })
    end

    -- ── Linked editing ──
    -- Rename a JSX/HTML opening tag and the closing tag follows. Built into
    -- 0.12; this is what nvim-ts-autotag existed to do.
    if client:supports_method('textDocument/linkedEditingRange') then
      vim.lsp.linked_editing_range.enable(true, { bufnr = buf })
    end

    -- ── Code lens ──
    -- Servers that publish lenses (ruby-lsp does, for test blocks) show them
    -- inline; grx runs the one under the cursor.
    --
    -- Use enable(), NOT refresh(). `:h deprecated` in 0.12 lists
    -- vim.lsp.codelens.refresh() as superseded by
    -- vim.lsp.codelens.enable(true) — and enable() manages its own refresh
    -- cycle, so the BufEnter/InsertLeave/TextChanged autocmds that older
    -- configs wire up by hand are now redundant.
    if client:supports_method('textDocument/codeLens') then
      vim.lsp.codelens.enable(true, { bufnr = buf })
    end

    -- ── Document highlight ──
    -- Underline other occurrences of the symbol under the cursor. Handled by
    -- snacks.nvim's `words` module now (plugins/snacks.lua) instead of a
    -- hand-rolled CursorHold/CursorMoved pair here — same
    -- `textDocument/documentHighlight` request, plus `]]`/`[[` jump between
    -- occurrences (plugins/words.lua). No per-client wiring needed: `words`
    -- checks `supports_method` itself on every cursor move.
  end,
})

-- ── Cleanup on detach ──────────────────────────────────────────────────────
-- Clears any reference highlight left behind by the detaching client (from
-- `words`, see plugins/snacks.lua) — otherwise a stale underline can survive
-- a :LspRestart with no client left to ever clear it.
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
