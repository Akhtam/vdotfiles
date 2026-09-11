-- after/lsp/vtsls.lua — local TypeScript / JavaScript / React overrides
--
-- MERGES with nvim-lspconfig's lsp/vtsls.lua rather than replacing it
-- (`:h lsp-config-merge`), so we inherit for free:
--
--   cmd        { 'vtsls', '--stdio' }
--   filetypes  javascript, javascriptreact, typescript, typescriptreact
--   root_dir   finds the lockfile, handles monorepos, bails on Deno projects
--
-- Do NOT redefine root_dir here — overriding it breaks monorepo detection.
-- Everything below is `settings`, which lspconfig's file doesn't touch.

---@type vim.lsp.Config
return {
  settings = {
    -- ── vtsls' own knobs ───────────────────────────────────────────────────
    vtsls = {
      -- The project's TypeScript, not the copy bundled in vtsls — editor errors
      -- must match what `tsc` produces in CI, and version skew between the two
      -- is a maddening class of bug.
      autoUseWorkspaceTsdk = true,

      -- "Move to file" as a code action (gra): pull a component into its own
      -- file with imports rewritten.
      enableMoveToFileCodeAction = true,

      experimental = {
        completion = {
          -- Fuzzy-match server-side rather than shipping the whole candidate
          -- set to the client. A real latency win in TSX, where the list for a
          -- bare `<` is enormous.
          enableServerSideFuzzyMatch = true,
        },
      },
    },

    -- ── TypeScript ─────────────────────────────────────────────────────────
    typescript = {
      -- 'always' skips the confirmation prompt, right for an editor where
      -- renames happen via fuzzy-finder rather than a file tree.
      updateImportsOnFileMove = { enabled = 'always' },

      preferences = {
        -- '@/components/Button' over '../../components/Button' where a tsconfig
        -- alias exists; falls back to relative where it doesn't.
        importModuleSpecifier = 'shortest',
        -- `import type { X }`, so the bundler can drop them cleanly.
        preferTypeOnlyAutoImports = true,
      },

      suggest = {
        -- Insert parentheses and parameter placeholders, not just the name.
        completeFunctionCalls = true,
      },

      -- ── Inlay hints ──
      -- Only rendered once toggled on with <leader>th (lsp.lua); these decide
      -- WHAT is shown then.
      inlayHints = {
        -- 'literals' annotates only bare-literal arguments — foo(true) becomes
        -- foo(enabled: true). 'all' would also give you foo(userId: userId),
        -- which is pure noise.
        parameterNames = { enabled = 'literals' },
        parameterTypes = { enabled = true },

        -- The high-value ones in React: what a useMemo/useCallback returns, and
        -- what TS inferred for a destructured prop.
        functionLikeReturnTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        enumMemberValues = { enabled = true },

        -- OFF on purpose: `const [open, setOpen] = useState(false)` renders as
        -- `const [open: boolean, setOpen: Dispatch<SetStateAction<boolean>>]`,
        -- which is true and unreadable.
        variableTypes = { enabled = false },
      },
    },

    -- ── JavaScript ─────────────────────────────────────────────────────────
    -- vtsls keeps separate setting trees per language — JS does NOT inherit
    -- from the typescript block, so omitting this leaves Node scripts and .jsx
    -- silently without inlay hints.
    javascript = {
      updateImportsOnFileMove = { enabled = 'always' },
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        parameterNames = { enabled = 'literals' },
        parameterTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        enumMemberValues = { enabled = true },
        variableTypes = { enabled = false },
      },
    },
  },
}
