-- ~/.config/nvim/init.lua
--
-- Entry point. Everything else lives in lua/ak/ and is required from here in a
-- deliberate order. Where the order matters, the reason is in a comment.

-- Leader keys must be set BEFORE anything creates a <leader> mapping. A mapping
-- captures the *current* value of mapleader at the moment it is defined, so
-- setting this later would silently leave earlier maps bound to the old leader
-- (the default, backslash). This is the single most common cause of "my leader
-- keymaps don't work" in a fresh config.
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

-- Byte-compilation cache for Lua modules: caches the compiled bytecode of every
-- required file so subsequent startups skip parsing them.
--
-- This is an opt-in trade, not a freebie. `:h vim.loader.enable` in 0.12.4 still
-- carries "WARNING: This feature is experimental/unstable", and it is OFF by
-- default. You get measurably faster startup as this config grows, in exchange
-- for a feature Neovim reserves the right to change. If you ever see a stale
-- module after editing a file, delete this line and the symptom goes away.
vim.loader.enable()

-- Providers are the bridges that let Neovim run plugins *authored in* Python,
-- Ruby, Perl, or Node. This config uses no such plugins. Disabling them skips
-- an executable search at startup and keeps :checkhealth free of warnings you'd
-- otherwise learn to ignore.
--
-- NOTE: `loaded_ruby_provider` has nothing to do with *editing* Ruby. Ruby
-- support here comes from LSP and treesitter. This only disables plugins whose
-- own source code is Ruby — of which you have none.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

require('ak.options')     -- vim.opt settings; depends on nothing
require('ak.keymaps')     -- plugin-independent maps only
require('ak.agent')       -- <leader>ac/ao: ask Claude/OpenCode about the selection
require('ak.autocmds')    -- editor behaviour; reads options set above

-- Plugins BEFORE lsp AND before treesitter, and this ordering is load-bearing.
--
-- vim.pack.add() extends 'runtimepath' synchronously — by the time this require
-- returns, every plugin directory is on the rtp. ak.lsp then calls
-- vim.lsp.enable('vtsls'), which resolves the server by searching for a file
-- named lsp/vtsls.lua *on the runtimepath*. Most of those files are supplied by
-- nvim-lspconfig, which is a plugin. Reverse these two lines and every server
-- that relies on an lsp/*.lua from nvim-lspconfig silently fails to start.
require('ak.plugins')

-- treesitter AFTER plugins: it calls require('nvim-treesitter'), which only
-- resolves once vim.pack.add() has put the plugin on the runtimepath. This
-- module used to sit above, back when it was core-only and had no dependency.
require('ak.treesitter')

require('ak.diagnostics') -- vim.diagnostic.config; independent of any client
require('ak.lsp')         -- vim.lsp.config defaults, enable list, LspAttach maps
