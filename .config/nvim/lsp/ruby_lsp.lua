-- lsp/ruby_lsp.lua — Ruby / Rails
--
-- Merges with nvim-lspconfig's lsp/ruby_lsp.lua, which supplies:
--
--   cmd           a FUNCTION that spawns `ruby-lsp` with cwd = root_dir
--   filetypes     { 'ruby', 'eruby' }        <- note: ERB too
--   root_markers  { 'Gemfile', '.git' }
--   reuse_client  so a monorepo with several Gemfiles gets one client each
--
-- The cmd-as-function detail is what makes asdf work: the shim resolves its
-- Ruby version from the .tool-versions found by walking up from the process's
-- CWD, and lspconfig sets that CWD to the project root — so each app gets ITS
-- Ruby, not the global default.
--
-- WHEN IT BREAKS: if a project's .tool-versions names a Ruby with no ruby-lsp
-- gem, the shim exits non-zero and the client silently fails to attach.
-- :LspInfo shows nothing attached; fix with `asdf install` + `gem install
-- ruby-lsp` for that version.

---@type vim.lsp.Config
return {
  init_options = {
    -- ── Formatting ───────────────────────────────────────────────────────
    -- 'auto' inspects the Gemfile and picks rubocop, syntax_tree, or none —
    -- right per project, including projects using neither.
    --
    -- THE LSP OWNS RUBY FORMATTING, not conform: shelling out to `rubocop` per
    -- save costs 1-3s of VM boot, while ruby-lsp formats in-process against an
    -- already-loaded rubocop. conform.lua delegates here (see its `ruby`
    -- function). rubocop --server would also solve it, but that's a second
    -- daemon to supervise for no gain.
    formatter = 'auto',

    -- Diagnostics from rubocop, in-process, same reasoning.
    linters = { 'rubocop' },

    -- ── Feature configuration ────────────────────────────────────────────
    featuresConfiguration = {
      inlayHint = {
        -- What a bare `rescue` catches (StandardError) and what an omitted hash
        -- value expands to (`{ name: }` -> `{ name: name }`) — information the
        -- code deliberately omits. Only renders when hints are on (<leader>th).
        implicitRescue = true,
        implicitHashValue = true,
      },
      codeLens = {
        -- Run/debug lenses above test blocks; grx runs the one under the cursor.
        -- Needs ruby-lsp-rspec in the Gemfile for RSpec.
        --
        -- Kept ON despite neotest also running tests: the lens confirms ruby-lsp
        -- has IDENTIFIED something as a test, which is the useful signal when
        -- neotest can't find it either.
        enableTestCodeLens = true,
      },
    },

    -- ── Indexing ─────────────────────────────────────────────────────────
    -- What ruby-lsp can find for go-to-definition and completion. Built at
    -- startup, so this is a direct speed/coverage trade.
    indexing = {
      excludedPatterns = {
        '**/node_modules/**/*.rb',
        '**/tmp/**/*.rb',
        '**/vendor/bundle/**/*.rb',
        -- Thousands of near-identical classes you navigate by filename, never
        -- by symbol — one of the bigger startup wins on an old codebase.
        '**/db/migrate/**/*.rb',
      },
      includedPatterns = {
        -- Ruby that doesn't end in .rb and would otherwise be skipped, but
        -- defines constants worth jumping to.
        '**/*.rake',
        '**/Rakefile',
      },
    },

    -- ── Addon settings ───────────────────────────────────────────────────
    -- Addons are gems in the project's Gemfile (ruby-lsp-rails, ruby-lsp-rspec),
    -- discovered automatically. Naming an absent one is harmless.
    addonSettings = {
      ['Ruby LSP Rails'] = {
        -- Otherwise it modals about pending migrations on attach — interruption
        -- with no decision attached, when you opened the file to read it.
        enablePendingMigrationsPrompt = false,
      },
    },
  },
}
