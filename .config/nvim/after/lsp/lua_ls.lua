-- after/lsp/lua_ls.lua — local Lua overrides for editing this config
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
        -- Index Neovim's runtime for API signatures without indexing every
        -- installed plugin. Plugin modules still resolve from the workspace.
        -- `${3rd}/luv/library` adds the type annotations for vim.uv.
        library = { vim.env.VIMRUNTIME, '${3rd}/luv/library' },

        -- Don't prompt to configure the workspace as a luassert/busted project
        -- every time a new directory is opened.
        checkThirdParty = false,
      },

      -- Telemetry off.
      telemetry = { enable = false },

      -- Formatting is stylua's job (conform.lua). lua_ls has its own formatter
      -- and the two disagree about continuation-line indentation.
      format = { enable = false },
    },
  },
}
