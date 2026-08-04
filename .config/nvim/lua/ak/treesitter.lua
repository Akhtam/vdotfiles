-- lua/ak/treesitter.lua
--
-- Treesitter via nvim-treesitter (the 'main' branch rewrite).
--
-- Division of labour, which is the whole point of the rewrite:
--
--   nvim-treesitter  installs PARSERS and QUERIES. That is all it does now.
--   Neovim core      provides highlighting, folds, and injections, driven by
--                    those queries.
--   nvim-treesitter  additionally offers an indentexpr, which it labels
--                    experimental — see the indent note below.
--
-- This is NOT the plugin most configs on the internet describe. There is no
-- `require('nvim-treesitter.configs').setup { highlight = { enable = true } }`
-- and no `ensure_installed`. Those belong to the frozen 'master' branch.

-- setup() is only needed to change install_dir; the default
-- (stdpath('data')/site, prepended to runtimepath) is what we want, so we skip
-- it entirely. The docs are explicit: "You do not need to call setup".

-- ── Parsers to install ─────────────────────────────────────────────────────
-- install() is idempotent and asynchronous — a no-op when everything is
-- already present, so running it on every startup costs nothing measurable.
--
-- Note what is NOT here: no eruby, no typescriptreact, no javascriptreact.
-- Those are FILETYPES, not parser languages. The plugin's own
-- plugin/filetypes.lua registers the mappings for us:
--
--   embedded_template <- eruby
--   tsx               <- typescriptreact, typescript.tsx
--   javascript        <- javascriptreact, jsx, js, ecma
--   json              <- jsonc
--   bash              <- sh
--
-- That registration is why the hand-written language map this file used to
-- carry is gone.
local ensure = {
  -- JS/TS. `tsx` and `typescript` are separate grammars from one repo; you
  -- need both because .ts and .tsx parse differently.
  'javascript',
  'typescript',
  'tsx',
  'jsdoc',

  -- Ruby/Rails. embedded_template handles the <% %> scaffolding in .erb and
  -- injects ruby + html into it, so all three are required for ERB to
  -- highlight fully — miss one and that layer goes plain.
  'ruby',
  'embedded_template',
  'html',

  -- Web/config
  'css',
  'json',
  'yaml',
  'toml',

  -- Shell & git
  'bash',
  'diff',
  'gitcommit',
  'git_rebase',
  'regex',

  -- Editing this config, plus help files
  'lua',
  'luadoc',
  'vim',
  'vimdoc',
  'markdown',
  'markdown_inline',
}

require('nvim-treesitter').install(ensure)

-- ── Enable features per buffer ─────────────────────────────────────────────
-- The plugin ships queries but deliberately enables nothing: "These are not
-- automatically enabled." Highlighting and folds are core APIs, so this is the
-- same autocmd as the core-only setup used.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('ak_treesitter', { clear = true }),
  callback = function(ev)
    -- Set by the large-file guard in autocmds.lua. A 20k-line db/schema.rb
    -- will make a highlighter feel like a hang.
    if vim.b[ev.buf].ak_big_file then
      return
    end

    local filetype = vim.bo[ev.buf].filetype
    if filetype == '' then
      return
    end

    -- Resolves through the plugin's filetype registrations above.
    local lang = vim.treesitter.language.get_lang(filetype)
    if not lang then
      return
    end

    -- Is the parser actually installed? language.add() returns true when the
    -- parser loads and nil when it doesn't, WITHOUT raising — so this is a
    -- return-value check, not a pcall. Keeps a not-yet-installed language a
    -- silent no-op rather than an error on every buffer you open, which
    -- matters because install() above is async and won't have finished on the
    -- very first startup.
    if not vim.treesitter.language.add(lang) then
      return
    end

    vim.treesitter.start(ev.buf, lang)

    -- ── Folds ──
    -- vim.wo[0][0] is window-local-to-buffer scoping. Plain vim.wo would leak
    -- this foldexpr onto the next buffer opened in the same window, including
    -- ones with no parser, where it then errors on every redraw.
    vim.wo[0][0].foldmethod = 'expr'
    vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'

    -- ── Indent: still NOT enabled ──
    -- nvim-treesitter DOES provide one now:
    --     vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    -- and its README labels it "experimental".
    --
    -- Leaving it off is a deliberate call, and it's the same one as before the
    -- switch: your install ships mature Vim indent scripts for precisely the
    -- filetypes you care about —
    --     $VIMRUNTIME/indent/typescriptreact.vim
    --     $VIMRUNTIME/indent/eruby.vim
    --     $VIMRUNTIME/indent/ruby.vim
    -- and they handle TSX and ERB more reliably than experimental treesitter
    -- indent does. They load automatically from FileType, and this file
    -- staying silent on 'indentexpr' is what lets them.
    --
    -- To try it anyway, uncomment below and compare on a deeply nested TSX
    -- component. It is one line to revert.
    -- vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- ── Inspection ─────────────────────────────────────────────────────────────
-- When highlighting looks wrong, these separate parser problems from query
-- problems. All built into Neovim; no plugin needed:
--
--   :Inspect       highlight groups under the cursor
--                  (empty => queries aren't being found)
--   :InspectTree   live syntax tree
--                  (empty or full of ERROR nodes => parser problem)
--   :EditQuery     interactive query playground
--
-- And from the plugin itself:
--
--   :TSInstall {lang}    install a parser not in the list above
--   :TSUpdate            update all parsers (also runs on plugin update)
--   :TSLog               output of the last install/update
--   :checkhealth nvim-treesitter    installed parsers and queries
