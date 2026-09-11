-- lua/ak/plugins/init.lua
--
-- The entire plugin surface of this config, in one table. vim.pack has no
-- declarative lazy-loading, so splitting add() calls across files would buy
-- nothing and cost the at-a-glance view.
--
-- ── One entry, one truth ───────────────────────────────────────────────────
-- Every entry declares where its configuration lives; the requires at the
-- bottom are DERIVED from it, so there is no second list to keep in step.
--
--   config = 'ak.plugins.noice'             one config module
--   config = { 'ak.plugins.snacks', ... }   several
--   config = false                          deliberately none, reason in a comment
--
-- Omitting `config` is not a third option — the loader warns at startup. That
-- is the point of the field: install and configure used to be two hand-synced
-- lists, and they drifted.
--
-- Order matters in two places, since the list is walked top to bottom:
--   tokyonight FIRST, so the colorscheme applies before anything draws.
--   nvim-autopairs before blink.cmp — blink binds <A-e> as { 'hide', 'fallback' }
--     and the fallback is whatever <A-e> already meant (autopairs' fast_wrap).
--     Load blink first and <A-e> stops wrapping. See plugins/autopairs.lua.
--
-- Managing plugins:
--   :lua vim.pack.update()                        fetch + review + confirm with :w
--   :lua vim.pack.update(nil, {offline = true})   browse installed
--   :lua vim.pack.del({ 'name' })                 remove from disk
--
-- Plugins land in ~/.local/share/nvim/site/pack/core/opt/; revisions are
-- recorded in the committed nvim-pack-lock.json, so a fresh machine installs
-- this exact set at these exact revisions.

local function gh(repo)
  return 'https://github.com/' .. repo
end

-- ── Build hooks ────────────────────────────────────────────────────────────
-- Registered BEFORE add(): add() installs missing plugins immediately and fires
-- PackChanged as it goes, so registering after would miss the very install this
-- exists to handle. See `:h vim.pack-events`.
vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('ak_pack_build', { clear = true }),
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind

    -- Only 'install' and 'update' change code on disk. 'delete' obviously
    -- needs no build.
    if kind ~= 'install' and kind ~= 'update' then
      return
    end

    if name == 'nvim-treesitter' then
      -- Parsers are pinned to revisions in the plugin's manifest, so plugin
      -- code and parser ABI must move together — :TSUpdate on every change.
      --
      -- On a fresh install nothing has been sourced yet, so the plugin's own
      -- commands don't exist; packadd it first (`:h vim.pack-events`).
      if not ev.data.active then
        vim.cmd.packadd('nvim-treesitter')
      end
      vim.cmd('TSUpdate')
    end
  end,
})

-- ── The plugin set ─────────────────────────────────────────────────────────
local spec = {
  -- ─ Appearance ─
  -- Matches the "TokyoNight Moon" theme already set in your Ghostty config, so
  -- the terminal chrome and editor agree instead of clashing at the edges.
  -- FIRST in this list on purpose: see the note at the top of the file.
  { src = gh('folke/tokyonight.nvim'), config = 'ak.plugins.ui' },
  { src = gh('nvim-lualine/lualine.nvim'), config = 'ak.plugins.lualine' },

  -- version = '*' in lazy.nvim means "latest semver tag". The vim.pack
  -- equivalent is a range covering all majors — v4.9.1 is current.
  {
    src = gh('akinsho/bufferline.nvim'),
    version = vim.version.range('*'),
    config = 'ak.plugins.bufferline',
  },

  -- ─ UI replacement for messages/cmdline ─
  -- noice needs this; vim.pack resolves no dependencies, so it is listed
  -- explicitly (nui = UI primitives noice's popups are built from). The toast
  -- backend is snacks.nvim's `notifier` module, below, not a separate plugin.
  { src = gh('MunifTanjim/nui.nvim'), config = false }, -- library; noice configures it
  { src = gh('folke/noice.nvim'), config = 'ak.plugins.noice' },

  -- ─ Keymap discovery ─
  { src = gh('folke/which-key.nvim'), config = 'ak.plugins.whichkey' },

  -- ─ Editing ─
  -- Indent guides come from snacks.nvim's `indent` module (plugins/snacks.lua).
  --
  -- Auto-close brackets and quotes as you type. Deliberately UNPINNED: the repo
  -- has exactly one tag (0.10.0) and has moved well past it on the default
  -- branch, so a version range would pin you to stale code. The lockfile still
  -- records the exact revision.
  { src = gh('windwp/nvim-autopairs'), config = 'ak.plugins.autopairs' },

  -- ─ Sessions ─
  -- Auto-saves a session per working directory and restores it on re-entry.
  {
    src = gh('rmagatti/auto-session'),
    version = vim.version.range('2.x'),
    config = 'ak.plugins.autosession',
  },

  -- ─ Multiplexer integration ─
  -- The Neovim half of a paired plugin; the tmux half is installed via TPM and
  -- declared in ~/.dotfiles/.tmux.conf. Same repo, so the halves can't drift.
  --
  -- config = false because lua/ak/mux.lua owns the whole multiplexer seam — this
  -- plugin under tmux, the herdr CLI under herdr — and init.lua calls its setup().
  { src = gh('christoomey/vim-tmux-navigator'), config = false },

  -- ─ Treesitter ─
  -- version = 'main' is NOT redundant. The repo carries two live branches: main
  -- is the 0.12-only rewrite, master is FROZEN for 0.11 back-compat. Pinning
  -- explicitly means an upstream default-branch change can't drop you onto the
  -- frozen one.
  --
  -- The rewrite is a different plugin from the one most configs describe: no
  -- `highlight = { enable = true }`, no `ensure_installed`. It installs parsers
  -- and queries, nothing else; features are enabled against core APIs in
  -- lua/ak/treesitter.lua, which init.lua requires after this file has extended
  -- the runtimepath. No lazy-loading support, which suits vim.pack fine.
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main', config = false },

  -- ─ Shared library ─
  -- Required by the neotest adapters, not by us. vim.pack resolves no
  -- dependencies, so every transitive one is listed explicitly.
  { src = gh('nvim-lua/plenary.nvim'), config = false }, -- library; nothing to configure

  -- ─ Icons ─
  -- File/git-status icons for the snacks explorer and picker, plus anything
  -- calling `MiniIcons.get()`. Degrades to generic icons without a Nerd Font.
  { src = gh('nvim-mini/mini.icons'), config = false }, -- setup() lives in plugins/explorer.lua

  -- ─ Markdown rendering ─
  -- Headings, code blocks, tables and checkboxes drawn as virtual text as you
  -- read, with the cursor line left raw so it stays editable.
  { src = gh('MeanderingProgrammer/render-markdown.nvim'), config = false }, -- defaults are what we want

  -- ─ snacks.nvim ─
  -- ~30 opt-in modules; seven are configured (see plugins/snacks.lua). The one
  -- entry with several config modules: snacks.lua is the setup() call and MUST
  -- come first — the rest are keymaps calling into modules it activates.
  {
    src = gh('folke/snacks.nvim'),
    config = {
      'ak.plugins.snacks',
      'ak.plugins.picker',
      'ak.plugins.gh',
      'ak.plugins.words',
      'ak.plugins.explorer',
      'ak.plugins.lazygit',
    },
  },

  -- ─ Completion ─
  -- PINNED TO 1.x DELIBERATELY: blink.cmp's V2 is under active development with
  -- breaking changes and needs a separate blink.lib plugin. Tracking the default
  -- branch would silently put you on it.
  --
  -- The range string is '1', NOT '1.0': range('1.0') resolves to >=1.0.0 <1.1.0
  -- and does not match v1.10.2. The vim.pack help's '1.0' example reads like
  -- "the 1.x line" and isn't. range('1') -> 1.0.0..2.0.0.
  {
    src = gh('Saghen/blink.cmp'),
    version = vim.version.range('1'),
    config = 'ak.plugins.blink',
  },
  -- Snippet corpus in VSCode format; blink reads it via its snippets source.
  { src = gh('rafamadriz/friendly-snippets'), config = false }, -- data only

  -- ─ LSP ─
  -- A DATA REPOSITORY only: it ships lsp/<server>.lua files that
  -- vim.lsp.enable() picks up off the runtimepath (cmd, filetypes, root_markers
  -- for hundreds of servers). Never call require('lspconfig') — deprecated, and
  -- the warning is slated to become an error.
  --
  -- config = false for the same reason as treesitter: our configuration is
  -- lua/ak/lsp.lua, required from init.lua after the runtimepath is extended.
  { src = gh('neovim/nvim-lspconfig'), config = false },

  -- ─ Formatting & linting ─
  -- Separate from LSP on purpose: formatters run on files no language server
  -- owns, and staying independent means format-on-save still works while a
  -- server is booting or crashed.
  { src = gh('stevearc/conform.nvim'), config = 'ak.plugins.conform' },
  { src = gh('mfussenegger/nvim-lint'), config = 'ak.plugins.lint' },

  -- ─ Git ─
  { src = gh('lewis6991/gitsigns.nvim'), config = 'ak.plugins.gitsigns' },
  -- LazyGit float is snacks.nvim's `lazygit` module, above — no separate
  -- plugin. See lua/ak/plugins/lazygit.lua for the keymaps.

  -- ─ Testing ─
  { src = gh('nvim-neotest/nvim-nio'), config = false }, -- async library neotest is built on
  { src = gh('nvim-neotest/neotest'), config = 'ak.plugins.neotest' },
  -- The adapters are constructed inside neotest's setup() call, so their
  -- configuration is plugins/neotest.lua's adapter list, not a file each.
  { src = gh('olimorris/neotest-rspec'), config = false },
  { src = gh('nvim-neotest/neotest-jest'), config = false },
  { src = gh('marilari88/neotest-vitest'), config = false },
  --
  -- Also note: neotest adapters need a treesitter PARSER for the language, to
  -- locate test blocks in the file. nvim-treesitter installs ruby, javascript,
  -- typescript, and tsx via the list in lua/ak/treesitter.lua.

  -- ─ Debugging ─
  -- All four name the SAME config module; the loader below dedupes via its
  -- `loaded` table, so ak.plugins.dap is required once. They belong in one file
  -- because they are one feature — adapters, UI, inline values and the ruby
  -- wiring are useless individually and share keymaps.
  --
  -- Unpinned: the four move independently of nvim-dap's release tags, and the
  -- lockfile records each exact revision anyway.
  --
  -- Placed after Testing so the files read in dependency order (neotest's
  -- <leader>td resolves through these adapters). Nothing enforces it — neotest
  -- only touches dap inside a keymap callback.
  { src = gh('mfussenegger/nvim-dap'), config = 'ak.plugins.dap' },
  { src = gh('rcarriga/nvim-dap-ui'), config = 'ak.plugins.dap' },
  { src = gh('theHamsta/nvim-dap-virtual-text'), config = 'ak.plugins.dap' },
  -- Wires up rdbg from the `debug` gem. Kept rather than hand-rolled because
  -- neotest-rspec's dap strategy is written against THIS plugin's private config
  -- keys (error_on_failure, random_port, current_line, waiting), not plain DAP
  -- fields.
  { src = gh('suketa/nvim-dap-ruby'), config = 'ak.plugins.dap' },
}

-- ── Install ────────────────────────────────────────────────────────────────
-- vim.pack.add() validates every field it is handed and `config` is ours, so it
-- gets a copy with that key dropped. Subtractive rather than an allowlist, so a
-- vim.pack field this config doesn't use today still passes through.
local pack_spec = {}
for i, entry in ipairs(spec) do
  local copy = {}
  for k, v in pairs(entry) do
    if k ~= 'config' then
      copy[k] = v
    end
  end
  pack_spec[i] = copy
end

vim.pack.add(pack_spec, {
  -- No modal prompt on first install: the dialog guards against cloning things
  -- you didn't ask for, but this version-controlled list IS the request, and on
  -- a fresh machine the alternative is a prompt before you can use the editor.
  --
  -- INSTALL only. vim.pack.update() still opens its confirmation buffer, which
  -- is where review actually matters — that's when code changes under you.
  confirm = false,
})

-- ── Plugin configuration ───────────────────────────────────────────────────
-- Everything above is now on the runtimepath, so these requires can safely call
-- into plugin code.
--
-- Walked in spec order, so "tokyonight is first" is the only ordering rule
-- there is to remember. A module named by two entries (or by one entry twice)
-- loads once.
local loaded, missing, undeclared = {}, {}, {}

for _, entry in ipairs(spec) do
  if entry.config == nil then
    undeclared[#undeclared + 1] = entry.src:match('[^/]+$')
  elseif entry.config then
    local modules = type(entry.config) == 'table' and entry.config or { entry.config }
    for _, module in ipairs(modules) do
      if not loaded[module] then
        loaded[module] = true
        -- Ask the runtimepath whether the file exists rather than pcall-ing
        -- require: a pcall would swallow a genuine syntax error in a config
        -- module and report it as "not written yet". Real errors still throw.
        if #vim.api.nvim_get_runtime_file('lua/' .. module:gsub('%.', '/') .. '.lua', false) > 0 then
          require(module)
        else
          missing[#missing + 1] = module
        end
      end
    end
  end
end

-- Deferred so the message lands in noice's UI rather than into a startup that
-- hasn't drawn yet. A warning, not an error: an unconfigured plugin is a loose
-- end, not a broken editor.
if #missing > 0 or #undeclared > 0 then
  vim.schedule(function()
    local lines = {}
    if #missing > 0 then
      lines[#lines + 1] = 'installed but not configured: ' .. table.concat(missing, ', ')
    end
    if #undeclared > 0 then
      lines[#lines + 1] = 'no `config` field on: ' .. table.concat(undeclared, ', ')
    end
    vim.notify('ak.plugins\n' .. table.concat(lines, '\n'), vim.log.levels.WARN)
  end)
end
