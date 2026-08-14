-- lua/ak/plugins/init.lua
--
-- The entire plugin surface of this config, in one table.
--
-- Why one call and one file: vim.pack has no declarative lazy-loading, so
-- splitting add() calls across files buys nothing and costs you the ability to
-- see everything you've installed at a glance.
--
-- ── One entry, one truth ───────────────────────────────────────────────────
-- Every entry declares where its configuration lives, and the requires at the
-- bottom are DERIVED from that — there is no second list to keep in step.
--
--   config = 'ak.plugins.noice'                  one config module
--   config = { 'ak.plugins.snacks', ... }        several (snacks.nvim)
--   config = false                               deliberately none, reason in a comment
--
-- Leaving `config` off entirely is not a third option: the loader reports it at
-- startup. That is the whole point of the field. Installing a plugin and
-- configuring it used to be two edits in two hand-synced lists, and they had
-- already drifted — four nvim-dap plugins were being cloned, pinned, and put on
-- the runtimepath with nothing configuring them, behind a commented-out require
-- nobody could see from the spec.
--
-- Order matters in two places, both because the list is walked top to bottom:
--
--   tokyonight is FIRST, so the colorscheme is applied before anything draws.
--
--   nvim-autopairs comes before blink.cmp. blink binds <A-e> as
--   `{ 'hide', 'fallback' }`, and its fallback is whatever <A-e> already meant
--   — autopairs' fast_wrap. Load blink first and it captures nothing, so
--   <A-e> stops wrapping once the completion menu is closed. See the note in
--   plugins/autopairs.lua.
--
-- Managing plugins:
--   :lua vim.pack.update()              fetch + review + confirm with :w
--   :lua vim.pack.update(nil, {offline = true})   browse installed plugins
--   :lua vim.pack.del({ 'name' })       remove from disk after deleting its spec
--
-- Plugins land in ~/.local/share/nvim/site/pack/core/opt/ and revisions are
-- recorded in ~/.config/nvim/nvim-pack-lock.json — which is committed, so a
-- fresh machine installs this exact set at these exact revisions.

local function gh(repo)
  return 'https://github.com/' .. repo
end

-- ── Build hooks ────────────────────────────────────────────────────────────
-- Registered BEFORE add(), because add() installs missing plugins immediately
-- and fires PackChanged as it goes. Register after, and the hook misses the
-- very install it exists to handle — `:h vim.pack-events` calls this out
-- explicitly: "If hooks need to run on install, run this before
-- `vim.pack.add()`".
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
      -- code and parser ABI must move together. Its README: "When upgrading
      -- the plugin, you must make sure that all installed parsers are updated
      -- to the latest version via :TSUpdate."
      --
      -- On a fresh install the plugin's own commands don't exist yet — nothing
      -- has been sourced. `:h vim.pack-events` covers this: "If action relies
      -- on code from the plugin (like user command or Lua code), make sure to
      -- explicitly load it first."
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
  -- Indent guides used to be lukas-reineke/indent-blankline.nvim here; now
  -- provided by snacks.nvim's `indent` module instead (config in
  -- plugins/snacks.lua) — one less plugin to pin/update, and consistent with
  -- the other snacks modules already in use (image, notifier, lazygit, ...).

  -- Auto-close brackets and quotes as you type. Deliberately UNPINNED: the
  -- repo has exactly one tag (0.10.0) and has moved well past it on the
  -- default branch, so a version range would pin you to stale code. The
  -- lockfile still records the exact revision.
  { src = gh('windwp/nvim-autopairs'), config = 'ak.plugins.autopairs' },

  -- ─ Sessions ─
  -- Auto-saves a session per working directory and restores it on re-entry.
  {
    src = gh('rmagatti/auto-session'),
    version = vim.version.range('2.x'),
    config = 'ak.plugins.autosession',
  },

  -- ─ Multiplexer integration ─
  -- The NVIM half of a paired plugin. The tmux half is already installed via
  -- TPM at ~/.tmux/plugins/vim-tmux-navigator, declared in ~/.dotfiles/.tmux.conf.
  -- Using the same repo for both halves means they can't drift apart.
  --
  -- config = false because its configuration isn't per-plugin: lua/ak/mux.lua
  -- owns the whole multiplexer seam — this plugin under tmux, the herdr CLI
  -- under herdr, one policy and one set of keymaps over both — and init.lua
  -- calls its setup() directly.
  { src = gh('christoomey/vim-tmux-navigator'), config = false },

  -- ─ Treesitter ─
  -- version = 'main' is NOT redundant, and getting it wrong is a real hazard.
  -- This repo carries two live branches: 'main' is the 0.12-only rewrite, and
  -- 'master' is FROZEN for Neovim 0.11 back-compat. main happens to be the
  -- default branch today, but pinning it explicitly means an upstream default
  -- change can't silently drop you onto the frozen branch.
  --
  -- The rewrite is a different plugin from the one most configs on the
  -- internet describe: no `highlight = { enable = true }`, no `ensure_installed`.
  -- It installs parsers + queries and nothing else; enabling features is done
  -- against core APIs in lua/ak/treesitter.lua.
  --
  -- It explicitly does NOT support lazy-loading, which suits vim.pack fine.
  --
  -- config = false because lua/ak/treesitter.lua is required from init.lua, not
  -- from here: it configures core APIs rather than the plugin, and it has to
  -- run after this whole file has put the plugin on the runtimepath.
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main', config = false },

  -- ─ Shared library ─
  -- Async/job/path utilities. Not used directly by us; the neotest adapters
  -- require it, and vim.pack has no dependency resolution — every transitive
  -- dependency must be listed explicitly. That's a real difference from
  -- lazy.nvim, and this is the cost.
  { src = gh('nvim-lua/plenary.nvim'), config = false }, -- library; nothing to configure

  -- ─ Icons ─
  -- Consumed by the snacks explorer/picker (file/git-status icons) and, per
  -- its own doc comment, auto-detected by anything that calls
  -- `MiniIcons.get()` — you already have a Nerd Font 2.3.3 installed, so the
  -- glyphs resolve. Ghostty falls back to it for the private-use-area
  -- codepoints even though font-family is the unpatched "JetBrains Mono NL".
  -- Everything that uses it still works without it, just with generic icons.
  { src = gh('nvim-mini/mini.icons'), config = false }, -- setup() lives in plugins/explorer.lua

  -- ─ Markdown rendering ─
  -- Renders markdown in the buffer as you read it — headings, code blocks,
  -- tables, and checkboxes drawn as virtual text instead of raw syntax, with
  -- the line under the cursor left as plain text so it stays editable.
  { src = gh('MeanderingProgrammer/render-markdown.nvim'), config = false }, -- defaults are what we want

  -- ─ snacks.nvim ─
  -- A bundle of ~30 independent modules (dashboard, indent, terminal, etc.),
  -- each opt-in: per its README, a module only activates if you explicitly
  -- pass it options in setup(). Seven are configured — `image`, `notifier`
  -- (noice's toast backend, replacing nvim-notify), `lazygit` (replacing
  -- kdheepak/lazygit.nvim), `picker` (replacing telescope.nvim +
  -- telescope-fzf-native), `explorer` (replacing nvim-tree), `indent`, and
  -- `words` — nothing else in the bundle activates.
  --
  -- The one entry with several config modules. snacks.lua is the setup() call;
  -- the rest are keymaps for individual modules, split out so a binding sits
  -- next to the thing it drives. snacks.lua must come first — the others call
  -- into modules it activates.
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
  -- PINNED TO 1.x DELIBERATELY. blink.cmp's README currently carries:
  -- "V2 is under active development with many breaking changes. Consider
  -- staying on stable by using branch = 'v1' or version = '1.*'". V2 also
  -- requires a separate blink.lib plugin. Tracking the default branch would
  -- silently put you on that.
  --
  -- NOTE the range string is '1', not '1.0'. vim.version.range('1.0') resolves
  -- to >=1.0.0 <1.1.0 — it does NOT match v1.10.2. The vim.pack help uses
  -- '1.0' in its example, which reads like "the 1.x line" and isn't.
  -- Verified: range('1') -> from=1.0.0 to=2.0.0, matches 1.10.2.
  {
    src = gh('Saghen/blink.cmp'),
    version = vim.version.range('1'),
    config = 'ak.plugins.blink',
  },
  -- Snippet corpus in VSCode format; blink reads it via its snippets source.
  { src = gh('rafamadriz/friendly-snippets'), config = false }, -- data only

  -- ─ LSP ─
  -- Used as a DATA REPOSITORY only. It ships lsp/<server>.lua files that
  -- vim.lsp.enable() picks up off the runtimepath — default cmd, filetypes,
  -- and root_markers for hundreds of servers. We never call
  -- require('lspconfig'), which is deprecated and warns: its README says
  -- "Calls to require('lspconfig') will show a warning, which will later
  -- become an error."
  --
  -- config = false for the same reason as treesitter: our LSP configuration is
  -- lua/ak/lsp.lua, which drives core vim.lsp APIs and is required from
  -- init.lua after this file has extended the runtimepath.
  { src = gh('neovim/nvim-lspconfig'), config = false },

  -- ─ Formatting & linting ─
  -- Kept separate from LSP on purpose: formatters run on files the language
  -- server may not own, and keeping them independent means format-on-save
  -- still works while a server is booting or crashed.
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
  -- COMMENTED OUT, not gone. These four were installing and loading with
  -- nothing configuring them — no lua/ak/plugins/dap.lua exists — which is the
  -- drift the `config` field above is meant to make impossible. Taking them out
  -- of the spec is the honest fix until that file is written.
  --
  -- Two consequences, because commenting a spec entry is not the same as
  -- removing a plugin:
  --
  --   The four clones are still in ~/.local/share/nvim/site/pack/core/opt/ and
  --   still pinned in nvim-pack-lock.json. vim.pack does not garbage-collect.
  --   They are not alone in that: every plugin this config has ever replaced is
  --   still on disk and in the lockfile. The full orphan list today, none of
  --   which appears in the spec above —
  --
  --     nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, nvim-dap-ruby
  --     telescope.nvim, telescope-fzf-native.nvim   (-> snacks picker)
  --     nvim-tree.lua                               (-> snacks explorer)
  --     nvim-notify                                 (-> snacks notifier)
  --     lazygit.nvim                                (-> snacks lazygit)
  --
  --   `:lua vim.pack.del({ ... })` with those names is what actually removes
  --   them. Harmless to leave — nothing puts them on the runtimepath — but they
  --   make the lockfile a poor answer to "what is installed".
  --
  --   While commented out they are invisible to the loader, so nothing warns
  --   about them. Uncommenting brings the startup warning back, which is the
  --   point: it names ak.plugins.dap until that module exists.
  -- { src = gh('mfussenegger/nvim-dap'), config = 'ak.plugins.dap' },
  -- { src = gh('rcarriga/nvim-dap-ui'), config = 'ak.plugins.dap' },
  -- { src = gh('theHamsta/nvim-dap-virtual-text'), config = 'ak.plugins.dap' },
  -- { src = gh('suketa/nvim-dap-ruby'), config = 'ak.plugins.dap' }, -- wires up rdbg from the `debug` gem
}

-- ── Install ────────────────────────────────────────────────────────────────
-- vim.pack.add() validates the fields of every spec it is handed, and `config`
-- is ours, not one it knows. So it gets a copy with that key dropped —
-- subtractive rather than an allowlist of the keys to keep, so a vim.pack field
-- this config doesn't use today still passes straight through when you add it.
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
  -- No modal prompt on first install. The confirmation dialog exists to stop a
  -- config from silently cloning things you didn't ask for — but this list IS
  -- the request, it's version-controlled, and you're reading it right now.
  -- On a fresh machine the alternative is a prompt before you can use the
  -- editor at all.
  --
  -- This only affects INSTALL. vim.pack.update() still opens its confirmation
  -- buffer where you review the changelog and accept with :w — which is where
  -- review actually matters, since that's when code changes under you.
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
