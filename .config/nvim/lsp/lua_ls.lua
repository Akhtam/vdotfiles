-- lsp/lua_ls.lua — Lua, for editing this config
--
-- Merges with nvim-lspconfig's lsp/lua_ls.lua for cmd, filetypes, and the root
-- markers (.luarc.json, stylua.toml, .git).

---@type vim.lsp.Config
return {
  settings = {
    Lua = {
      runtime = {
        -- Neovim embeds LuaJIT, which is 5.1 with extensions — not 5.4.
        -- Without this, lua_ls flags `unpack` and `loadstring` as undefined
        -- and suggests 5.4-only APIs that don't exist here.
        version = 'LuaJIT',
      },

      workspace = {
        -- Index Neovim's own runtime so `vim.lsp.document_color.enable(` gives
        -- real signatures. This is what turns editing this config from
        -- guesswork into completion — and it would have caught the filter-table
        -- bug in lsp.lua at type-check time rather than at LspAttach.
        library = vim.api.nvim_get_runtime_file('', true),

        -- Don't prompt to configure the workspace as a luassert/busted project
        -- every time a new directory is opened.
        checkThirdParty = false,
      },

      -- `vim` is injected by Neovim, so lua_ls sees it as an undefined global
      -- without this. Declaring it here is why we don't need a `---@diagnostic
      -- disable` comment at the top of every file.
      diagnostics = {
        globals = { 'vim' },
      },

      -- Telemetry off.
      telemetry = { enable = false },

      -- Formatting is stylua's job (conform.lua). lua_ls has its own formatter
      -- and the two disagree about continuation-line indentation.
      format = { enable = false },
    },
  },
}
