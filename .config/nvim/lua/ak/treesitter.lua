-- lua/ak/treesitter.lua
--
-- Treesitter via nvim-treesitter's 'main' branch rewrite, where the division of
-- labour is the whole point: the plugin installs PARSERS and QUERIES and
-- nothing else, and Neovim core provides highlighting, folds and injections
-- from them.
--
-- NOT the plugin most configs describe — there is no
-- `require('nvim-treesitter.configs').setup { highlight = ... }` and no
-- `ensure_installed`. Those belong to the frozen 'master' branch. setup() is
-- only for changing install_dir, so it is skipped entirely.

-- ── Parsers to install ─────────────────────────────────────────────────────
-- install() is idempotent and async, so running it every startup is free.
--
-- No eruby, typescriptreact or javascriptreact here — those are FILETYPES, not
-- parser languages, and the plugin's plugin/filetypes.lua maps them:
--
--   embedded_template <- eruby
--   tsx               <- typescriptreact, typescript.tsx
--   javascript        <- javascriptreact, jsx, js, ecma
--   json              <- jsonc
--   bash              <- sh
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

    -- language.add() returns true/nil WITHOUT raising, so this is a return-value
    -- check rather than a pcall. Keeps a not-yet-installed language a silent
    -- no-op, which matters because install() above is async and hasn't finished
    -- on the very first startup.
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

    -- ── Indent: deliberately NOT enabled ──
    -- nvim-treesitter provides an indentexpr but labels it experimental, and
    -- $VIMRUNTIME ships mature indent scripts for exactly the filetypes that
    -- matter here (typescriptreact.vim, eruby.vim, ruby.vim) which handle TSX
    -- and ERB more reliably. They load from FileType on their own — this file
    -- staying silent on 'indentexpr' is what lets them.
    --
    -- To try it, uncomment and compare on a deeply nested TSX component.
    -- vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- ── Inspection ─────────────────────────────────────────────────────────────
-- When highlighting looks wrong, these separate query problems from parser ones:
--
--   :Inspect       highlight groups under the cursor (empty => no queries)
--   :InspectTree   live syntax tree (ERROR nodes => parser problem)
--   :EditQuery     interactive query playground
--   :TSInstall {lang} / :TSUpdate / :TSLog
--   :checkhealth nvim-treesitter
