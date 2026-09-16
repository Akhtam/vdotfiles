-- lua/ak/lsp.lua
--
-- Native LSP wiring for Neovim 0.12. No nvim-lspconfig framework: we use
-- vim.lsp.config() / vim.lsp.enable(), and local server overrides live in
-- ~/.config/nvim/after/lsp/<name>.lua.
--
-- How a server is resolved (`:h lsp-config-merge`), in increasing priority:
--   1. built-in defaults
--   2. every lsp/<name>.lua on the 'runtimepath'  <- nvim-lspconfig supplies
--                                                    these: cmd, filetypes,
--                                                    root_markers
--   3. every after/lsp/<name>.lua on the runtimepath
--   4. vim.lsp.config() calls                     <- the '*' block below
--
-- Our overrides live at layer 3 under after/lsp/, so they deterministically win
-- over nvim-lspconfig while inheriting its cmd, filetypes, and root detection.

-- ── Defaults applied to every server ───────────────────────────────────────
vim.lsp.config('*', {
  -- No `capabilities` here: blink.cmp's plugin/blink-cmp.lua already extends
  -- vim.lsp.config('*') with its completion capabilities on 0.11+.

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
      vim.keymap.set(mode, lhs, rhs, { buf = buf, desc = 'LSP: ' .. desc })
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
    -- Nothing to do: 0.12 enables document colours on attach by default
    -- (`:h lsp-defaults`). Opt out with vim.lsp.document_color.enable(false, …).

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

    -- ── ESLint fix-on-save ──
    -- Apply eslint's auto-fixable rules on save — import ordering, unused
    -- imports, fixable hook-dependency rules. Here rather than an on_attach in
    -- after/lsp/eslint.lua, which would replace lspconfig's own on_attach.
    --
    -- A SEPARATE mechanism from conform, which currently registers no
    -- BufWritePre at all (its format_on_save is commented out). If you turn
    -- that back on, ORDER MATTERS: BufWritePre autocmds run in registration
    -- order, and these fixes are code changes, so prettierd must run afterwards
    -- to re-format the result.
    if client.name == 'eslint' then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('ak_eslint_fix_' .. buf, { clear = true }),
        buf = buf,
        callback = function()
          if vim.g.ak_disable_eslint_fix or vim.b[buf].ak_disable_eslint_fix then
            return
          end

          local response, reason = client:request_sync('workspace/executeCommand', {
            command = 'eslint.applyAllFixes',
            arguments = {
              {
                uri = vim.uri_from_bufnr(buf),
                version = vim.lsp.util.buf_versions[buf],
              },
            },
          }, nil, buf)

          if not response then
            vim.notify_once('ESLint fix-on-save failed: ' .. (reason or 'no response'), vim.log.levels.WARN)
          elseif response.err then
            vim.notify_once('ESLint fix-on-save failed: ' .. vim.inspect(response.err), vim.log.levels.WARN)
          end
        end,
      })
    end

    -- Document highlight is deliberately absent: snacks.nvim's `words` module
    -- makes the same documentHighlight request and checks supports_method on
    -- every cursor move, so no per-client wiring belongs here. Adding one back
    -- gives two listeners fighting over the highlight.
  end,
})

-- No custom :LspInfo / :LspRestart: 0.12 ships `:lsp restart|stop|enable|disable`
-- (`:h lsp-commands`), and `:checkhealth vim.lsp` shows what is attached.

-- ESLint fixes are on by default. A bang changes only the current buffer;
-- without one the switch applies globally.
vim.api.nvim_create_user_command('EslintFixToggle', function(args)
  local scope
  local disabled
  if args.bang then
    vim.b.ak_disable_eslint_fix = not vim.b.ak_disable_eslint_fix
    disabled = vim.b.ak_disable_eslint_fix
    scope = 'buffer'
  else
    vim.g.ak_disable_eslint_fix = not vim.g.ak_disable_eslint_fix
    disabled = vim.g.ak_disable_eslint_fix
    scope = 'global'
  end
  vim.notify(('ESLint fix on save %s (%s)'):format(disabled and 'OFF' or 'ON', scope))
end, { bang = true, desc = 'Toggle ESLint fix on save' })
