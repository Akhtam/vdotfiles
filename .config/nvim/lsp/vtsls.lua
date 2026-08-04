-- lsp/vtsls.lua — TypeScript / JavaScript / React
--
-- This file MERGES with nvim-lspconfig's own lsp/vtsls.lua rather than
-- replacing it (`:h lsp-config-merge`: "the merged configuration of ALL
-- lsp/<config>.lua files in 'runtimepath'"). So we inherit for free:
--
--   cmd        { 'vtsls', '--stdio' }
--   filetypes  javascript, javascriptreact, typescript, typescriptreact
--   root_dir   a function that finds the package-manager lockfile, handles
--              monorepos, and bails out on Deno projects
--
-- Deliberately NOT redefined here. That root_dir is more careful than anything
-- worth hand-rolling, and overriding it would break monorepo detection.
--
-- Everything below is `settings`, which lspconfig's file doesn't touch — so
-- there is no conflict, only addition.

---@type vim.lsp.Config
return {
  settings = {
    -- ── vtsls' own knobs ───────────────────────────────────────────────────
    vtsls = {
      -- Use the TypeScript version from the project's node_modules rather than
      -- the one bundled inside vtsls. This matters: type errors must match
      -- what `tsc` produces in CI, and a version skew between editor and build
      -- is a genuinely maddening class of bug.
      autoUseWorkspaceTsdk = true,

      -- Offers "Move to file" as a code action (gra) — pull a component out
      -- into its own file with imports rewritten automatically.
      enableMoveToFileCodeAction = true,

      experimental = {
        completion = {
          -- Let the server do fuzzy matching over the full candidate set
          -- instead of sending everything to the client. On large React
          -- codebases this is a noticeable latency win, since the candidate
          -- list for a bare `<` in TSX is enormous.
          enableServerSideFuzzyMatch = true,
        },
      },
    },

    -- ── TypeScript ─────────────────────────────────────────────────────────
    typescript = {
      -- Rewrite import paths when a file is renamed or moved. 'always' skips
      -- the confirmation prompt, which is right for an editor where renames
      -- usually happen via a fuzzy-finder rather than a file tree.
      updateImportsOnFileMove = { enabled = 'always' },

      preferences = {
        -- Prefer '@/components/Button' over '../../components/Button' when a
        -- tsconfig path alias exists. Falls back to relative when it doesn't.
        importModuleSpecifier = 'shortest',
        -- Use `import type { X }` for type-only imports so the bundler can
        -- drop them cleanly.
        preferTypeOnlyAutoImports = true,
      },

      suggest = {
        -- Completing a function inserts its parentheses and parameter
        -- placeholders, not just the name.
        completeFunctionCalls = true,
      },

      -- ── Inlay hints ──
      -- Rendered only when you toggle them on with <leader>th (see lsp.lua);
      -- these settings decide WHAT is shown when you do.
      inlayHints = {
        -- 'literals' only annotates parameters whose argument is a bare
        -- literal — foo(true) becomes foo(enabled: true). The alternative,
        -- 'all', annotates every argument including ones where the variable
        -- name already says it (foo(userId) -> foo(userId: userId)), which is
        -- pure noise.
        parameterNames = { enabled = 'literals' },
        parameterTypes = { enabled = true },

        -- The high-value ones in React: what does this useMemo/useCallback
        -- actually return, and what type did TS infer for this destructured
        -- prop?
        functionLikeReturnTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        enumMemberValues = { enabled = true },

        -- OFF on purpose. `const [open, setOpen] = useState(false)` would
        -- render as `const [open: boolean, setOpen: Dispatch<SetStateAction
        -- <boolean>>]`, which is technically true and completely unreadable.
        variableTypes = { enabled = false },
      },
    },

    -- ── JavaScript ─────────────────────────────────────────────────────────
    -- vtsls keeps separate setting trees per language; JS settings do NOT
    -- inherit from the typescript block above. Node scripts and .jsx files
    -- would silently get no inlay hints if this were omitted.
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
