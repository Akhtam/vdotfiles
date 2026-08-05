-- lua/ak/plugins/init.lua
--
-- The entire plugin surface of this config, in one vim.pack.add() call.
--
-- Why one call and one file: vim.pack has no declarative lazy-loading, so
-- splitting add() calls across files buys nothing and costs you the ability to
-- see everything you've installed at a glance. Configuration still lives in
-- per-plugin files, required at the bottom.
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
    local name, kind, path = ev.data.spec.name, ev.data.kind, ev.data.path

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

    if name == 'telescope-fzf-native.nvim' then
      -- A C extension providing fzf's matching algorithm to telescope. Without
      -- it telescope falls back to a pure-Lua sorter that is noticeably slower
      -- on large repos — which, with a Rails app plus node_modules, is you.
      vim.notify('building telescope-fzf-native…', vim.log.levels.INFO)
      vim.system({ 'make' }, { cwd = path }, function(out)
        vim.schedule(function()
          if out.code == 0 then
            vim.notify('telescope-fzf-native built', vim.log.levels.INFO)
          else
            vim.notify('fzf-native build FAILED:\n' .. (out.stderr or ''), vim.log.levels.ERROR)
          end
        end)
      end)
    end
  end,
})

-- ── The plugin set ─────────────────────────────────────────────────────────
vim.pack.add({
  -- ─ Appearance ─
  -- Matches the "TokyoNight Moon" theme already set in your Ghostty config, so
  -- the terminal chrome and editor agree instead of clashing at the edges.
  { src = gh('folke/tokyonight.nvim') },
  { src = gh('nvim-lualine/lualine.nvim') },

  -- version = '*' in lazy.nvim means "latest semver tag". The vim.pack
  -- equivalent is a range covering all majors — v4.9.1 is current.
  { src = gh('akinsho/bufferline.nvim'), version = vim.version.range('*') },

  -- ─ UI replacement for messages/cmdline ─
  -- noice needs both of these; vim.pack resolves no dependencies, so they are
  -- listed explicitly (nui = UI primitives, nvim-notify = the toast backend
  -- noice routes messages to).
  { src = gh('MunifTanjim/nui.nvim') },
  { src = gh('rcarriga/nvim-notify') },
  { src = gh('folke/noice.nvim') },

  -- ─ Keymap discovery ─
  { src = gh('folke/which-key.nvim') },

  -- ─ Editing ─
  -- Indent guides. Pinned to 3.x — v3 was a full rewrite that renamed the
  -- module from 'indent_blankline' to 'ibl' (which is what lazy.nvim's
  -- `main = "ibl"` was declaring), so a v4 would likely move it again.
  { src = gh('lukas-reineke/indent-blankline.nvim'), version = vim.version.range('3.x') },

  -- Auto-close brackets and quotes as you type. Deliberately UNPINNED: the
  -- repo has exactly one tag (0.10.0) and has moved well past it on the
  -- default branch, so a version range would pin you to stale code. The
  -- lockfile still records the exact revision.
  { src = gh('windwp/nvim-autopairs') },

  -- ─ Sessions ─
  -- Auto-saves a session per working directory and restores it on re-entry.
  { src = gh('rmagatti/auto-session'), version = vim.version.range('2.x') },

  -- ─ tmux integration ─
  -- The NVIM half of a paired plugin. The tmux half is already installed via
  -- TPM at ~/.tmux/plugins/vim-tmux-navigator, declared in ~/.dotfiles/.tmux.conf.
  -- Using the same repo for both halves means they can't drift apart.
  { src = gh('christoomey/vim-tmux-navigator') },

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
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },

  -- ─ Shared library ─
  -- Async/job/path utilities. Not used directly by us; telescope and the
  -- neotest adapters both require it, and vim.pack has no dependency
  -- resolution — every transitive dependency must be listed explicitly.
  -- That's a real difference from lazy.nvim, and this is the cost.
  { src = gh('nvim-lua/plenary.nvim') },

  -- ─ Fuzzy finding ─
  { src = gh('nvim-telescope/telescope.nvim') },
  { src = gh('nvim-telescope/telescope-fzf-native.nvim') }, -- built by the hook above

  -- ─ File explorer ─
  { src = gh('nvim-tree/nvim-tree.lua') },
  -- Optional for nvim-tree, but you already have a Nerd Font 2.3.3 installed,
  -- so the glyphs resolve. Ghostty falls back to it for the private-use-area
  -- codepoints even though font-family is the unpatched "JetBrains Mono NL".
  -- Without this plugin nvim-tree still works, just with no file icons.
  { src = gh('nvim-tree/nvim-web-devicons') },

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
  },
  -- Snippet corpus in VSCode format; blink reads it via its snippets source.
  { src = gh('rafamadriz/friendly-snippets') },

  -- ─ LSP ─
  -- Used as a DATA REPOSITORY only. It ships lsp/<server>.lua files that
  -- vim.lsp.enable() picks up off the runtimepath — default cmd, filetypes,
  -- and root_markers for hundreds of servers. We never call
  -- require('lspconfig'), which is deprecated and warns: its README says
  -- "Calls to require('lspconfig') will show a warning, which will later
  -- become an error."
  { src = gh('neovim/nvim-lspconfig') },

  -- ─ Formatting & linting ─
  -- Kept separate from LSP on purpose: formatters run on files the language
  -- server may not own, and keeping them independent means format-on-save
  -- still works while a server is booting or crashed.
  { src = gh('stevearc/conform.nvim') },
  { src = gh('mfussenegger/nvim-lint') },

  -- ─ Git ─
  { src = gh('lewis6991/gitsigns.nvim') },

  -- A floating terminal wrapper around the `lazygit` binary (already installed
  -- at /opt/homebrew/bin/lazygit, 0.64.0 — the plugin is only the window, it
  -- shells out for everything else). UNPINNED: the repo carries no tags at all,
  -- so there is no version range to give; the lockfile records the revision.
  --
  -- It requires plenary, which is already listed above for telescope/neotest.
  { src = gh('kdheepak/lazygit.nvim') },

  -- ─ Testing ─
  { src = gh('nvim-neotest/nvim-nio') }, -- async library neotest is built on
  { src = gh('nvim-neotest/neotest') },
  { src = gh('olimorris/neotest-rspec') },
  { src = gh('nvim-neotest/neotest-jest') },
  { src = gh('marilari88/neotest-vitest') },
  --
  -- NOT INSTALLED: antoinemadec/FixCursorHold.nvim, which neotest's README
  -- still recommends. Its purpose is decoupling CursorHold from 'updatetime'
  -- so a low updatetime doesn't cause "excessive writes to disk" — but those
  -- writes are swapfile writes, and options.lua sets swapfile = false. The
  -- rationale doesn't apply here. Add it if neotest's UI ever feels laggy.
  --
  -- Also note: neotest adapters need a treesitter PARSER for the language, to
  -- locate test blocks in the file. nvim-treesitter installs ruby, javascript,
  -- typescript, and tsx via the list in lua/ak/treesitter.lua.

  -- ─ Debugging ─
  { src = gh('mfussenegger/nvim-dap') },
  { src = gh('rcarriga/nvim-dap-ui') },
  { src = gh('theHamsta/nvim-dap-virtual-text') },
  { src = gh('suketa/nvim-dap-ruby') }, -- wires up rdbg from the `debug` gem
}, {
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
-- Everything above is now on the runtimepath, so these requires can safely
-- call into plugin code. Order is mostly irrelevant; ui goes first so the
-- colorscheme is applied before anything draws.
require('ak.plugins.ui')
require('ak.plugins.lualine')
require('ak.plugins.bufferline')
require('ak.plugins.noice')
require('ak.plugins.whichkey')
require('ak.plugins.indent')
require('ak.plugins.autopairs')
require('ak.plugins.autosession')
require('ak.plugins.tmux')
-- TODO: uncomment each as it is written — they are being added one at a time.
require('ak.plugins.telescope')
require('ak.plugins.nvim_tree')
require('ak.plugins.blink')
require('ak.plugins.conform')
require('ak.plugins.lint')
require('ak.plugins.gitsigns')
require('ak.plugins.lazygit')
-- require('ak.plugins.neotest')
-- require('ak.plugins.dap')
