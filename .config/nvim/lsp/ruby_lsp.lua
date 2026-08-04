-- lsp/ruby_lsp.lua — Ruby / Rails
--
-- Merges with nvim-lspconfig's lsp/ruby_lsp.lua, which supplies:
--
--   cmd           a FUNCTION that spawns `ruby-lsp` with cwd = root_dir
--   filetypes     { 'ruby', 'eruby' }        <- note: ERB too
--   root_markers  { 'Gemfile', '.git' }
--   reuse_client  so a monorepo with several Gemfiles gets one client each
--
-- That cmd-as-function detail is what makes asdf work. Your `ruby-lsp` is
-- ~/.asdf/shims/ruby-lsp, and an asdf shim resolves its Ruby version from the
-- .tool-versions found by walking up from the process's CWD. Because lspconfig
-- sets cwd to the project root, each Rails app gets ITS Ruby, not whatever the
-- global default happens to be.
--
-- Corollary worth knowing when it breaks: if a project's .tool-versions names a
-- Ruby that has no ruby-lsp gem installed, the shim exits non-zero and the
-- client silently fails to attach. Fix is `asdf install` + `gem install
-- ruby-lsp` for that version — :LspInfo (defined in lua/ak/lsp.lua) will show
-- nothing attached, which is the symptom to look for.
--
-- Every key below was verified against ruby-lsp's own source
-- (lib/ruby_lsp/global_state.rb) and its VS Code manifest, not guessed.

---@type vim.lsp.Config
return {
  init_options = {
    -- ── Formatting ───────────────────────────────────────────────────────
    -- 'auto' inspects the Gemfile and picks rubocop, syntax_tree, or none.
    -- Left as-is deliberately: it does the right thing per project, including
    -- projects that use neither.
    --
    -- IMPORTANT — this reverses what I said earlier about conform owning Ruby
    -- formatting. The reason is latency. Shelling out to `rubocop` per save
    -- costs 1-3s of Ruby VM boot; ruby-lsp formats IN-PROCESS against an
    -- already-loaded rubocop, so it's effectively instant. conform.lua will
    -- therefore delegate Ruby to the LSP rather than run the CLI.
    -- (rubocop --server exists and would also solve this, but it's a second
    -- daemon to supervise for no gain over the one we already run.)
    formatter = 'auto',

    -- Diagnostics from rubocop, in-process, same reasoning.
    linters = { 'rubocop' },

    -- ── Feature configuration ────────────────────────────────────────────
    featuresConfiguration = {
      inlayHint = {
        -- Show what a bare `rescue` actually catches (StandardError) and what
        -- an omitted hash value expands to (`{ name: }` -> `{ name: name }`,
        -- Ruby 3.1+ shorthand). Both are cases where the code deliberately
        -- omits information that you occasionally need to see.
        --
        -- These only render when inlay hints are toggled on via <leader>th.
        implicitRescue = true,
        implicitHashValue = true,
      },
      codeLens = {
        -- Run/debug lenses above test blocks. Requires ruby-lsp-rspec in the
        -- project's Gemfile for RSpec. grx runs the lens under the cursor.
        --
        -- Kept ON even though neotest also runs tests: the lens tells you
        -- ruby-lsp has correctly *identified* something as a test, which is a
        -- useful signal when neotest can't find it either.
        enableTestCodeLens = true,
      },
    },

    -- ── Indexing ─────────────────────────────────────────────────────────
    -- Controls what ruby-lsp can find for go-to-definition and completion.
    -- The index is built at startup, so this is a direct speed/coverage trade.
    indexing = {
      excludedPatterns = {
        -- Never useful to index, and large in a mature Rails app.
        '**/node_modules/**/*.rb',
        '**/tmp/**/*.rb',
        '**/vendor/bundle/**/*.rb',
        -- db/migrate is thousands of near-identical classes that you navigate
        -- by filename, never by symbol. Excluding it is one of the bigger
        -- startup wins on an old codebase.
        '**/db/migrate/**/*.rb',
      },
      includedPatterns = {
        -- Ruby files that don't end in .rb and would otherwise be skipped.
        -- Rakefiles and .rake tasks define constants you do want to jump to.
        '**/*.rake',
        '**/Rakefile',
      },
    },

    -- ── Addon settings ───────────────────────────────────────────────────
    -- Addons are gems in the project's Gemfile (ruby-lsp-rails,
    -- ruby-lsp-rspec); ruby-lsp discovers them automatically. This block only
    -- configures ones that are present — naming an absent addon is harmless.
    addonSettings = {
      ['Ruby LSP Rails'] = {
        -- Rails addon otherwise prompts about pending migrations on attach.
        -- A modal about migrations when you opened a file to read it is
        -- interruption without a decision attached; `rails db:migrate` is
        -- something you run deliberately.
        enablePendingMigrationsPrompt = false,
      },
    },
  },
}
