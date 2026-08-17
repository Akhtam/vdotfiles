-- lua/ak/plugins/conform.lua
--
-- Formatting. conform runs external formatters and can fall back to the LSP.
--
-- Division of labour, decided per language rather than globally:
--   JS/TS/CSS/JSON/YAML/MD  prettierd  (daemon: no Node startup per save)
--   Ruby/ERB                the LSP    (ruby-lsp formats in-process; shelling
--                                       out to rubocop costs 1-3s of VM boot)
--   Lua                     stylua
--
-- FORMAT-ON-SAVE IS CURRENTLY OFF — the `format_on_save` block below and the
-- FormatToggle command / <leader>mt are commented out. <leader>mp formats on
-- demand. Uncomment both blocks together to turn it back on; the toggle exists
-- because :noautocmd w can't skip conform (it uses BufWritePre).

local conform = require('conform')

conform.setup({
  formatters_by_ft = {
    -- prettierd is a daemon: the first call starts it, every later call reuses
    -- the warm process. Plain `prettier` would add ~500ms of Node startup to
    -- every save.
    javascript = { 'prettierd' },
    javascriptreact = { 'prettierd' },
    typescript = { 'prettierd' },
    typescriptreact = { 'prettierd' },
    css = { 'prettierd' },
    scss = { 'prettierd' },
    html = { 'prettierd' },
    json = { 'prettierd' },
    jsonc = { 'prettierd' },
    yaml = { 'prettierd' },
    markdown = { 'prettierd' },
    graphql = { 'prettierd' },

    lua = { 'stylua' },

    -- ── Ruby: fast path via LSP, correct fallback via CLI ──
    -- ruby-lsp has rubocop in-process and formats instantly; the CLI costs 1-3s
    -- of VM boot. But ruby-lsp only advertises formatting when it RESOLVES a
    -- formatter, and it resolves by inspecting the bundle, not by finding a
    -- .rubocop.yml — so in a project with .rubocop.yml but no Gemfile it reports
    -- no formatting support, and omitting ruby here would leave that project
    -- with none at all.
    --
    -- Hence a per-buffer function: empty list defers to lsp_format, non-empty
    -- runs the CLI.
    ruby = function(bufnr)
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = 'ruby_lsp' })) do
        if client:supports_method('textDocument/formatting') then
          return {} -- ruby-lsp has it; let the LSP fallback handle it
        end
      end
      return { 'rubocop' } -- slow, but better than silently not formatting
    end,

    -- ERB: no formatter. Deliberate — rubocop can't parse a template, and
    -- prettierd would reflow the HTML around the <% %> tags in ways that break
    -- Rails helpers spanning multiple lines. erb_lint in lint.lua reports
    -- problems without rewriting the file.
  },

  -- ── Format on save ───────────────────────────────────────────────────────
  -- format_on_save = function(bufnr)
  --   -- Escape hatch: `:noautocmd w` won't help because conform uses BufWritePre,
  --   -- so this checks a variable instead. Toggle it with <leader>mt below when
  --   -- you need to save something the formatter would mangle (a fixture, a
  --   -- vendored file, a half-finished refactor).
  --   if vim.g.ak_disable_autoformat or vim.b[bufnr].ak_disable_autoformat then
  --     return
  --   end
  --
  --   return {
  --     timeout_ms = 1000,
  --
  --     -- 'fallback' = use a formatter from the table above if one exists,
  --     -- otherwise ask the LSP. This is what routes Ruby to ruby-lsp.
  --     --
  --     -- Note this is the modern spelling. The `lsp_fallback = true` in your old
  --     -- config still works but is deprecated in current conform; `lsp_format`
  --     -- takes 'never' | 'fallback' | 'prefer' | 'first' | 'last' and is more
  --     -- explicit about ordering.
  --     lsp_format = 'fallback',
  --   }
  -- end,
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- lsp_format = 'fallback' means "a formatter from the table above if one
-- exists, otherwise the LSP" — this is what routes Ruby to ruby-lsp. (The older
-- `lsp_fallback = true` spelling is deprecated.)
--
-- async = false is deliberate: it blocks until done, so a format immediately
-- followed by :w can't race and write the unformatted text.
vim.keymap.set({ 'n', 'v' }, '<leader>mp', function()
  conform.format({
    lsp_format = 'fallback',
    async = false,
    timeout_ms = 1000,
  })
end, { desc = 'Format file or range (in visual mode)' })

-- Toggle format-on-save. Buffer-local with a bang, global without.
-- vim.api.nvim_create_user_command('FormatToggle', function(args)
--   if args.bang then
--     vim.b.ak_disable_autoformat = not vim.b.ak_disable_autoformat
--     vim.notify('Format on save ' .. (vim.b.ak_disable_autoformat and 'OFF' or 'ON') .. ' (buffer)')
--   else
--     vim.g.ak_disable_autoformat = not vim.g.ak_disable_autoformat
--     vim.notify('Format on save ' .. (vim.g.ak_disable_autoformat and 'OFF' or 'ON') .. ' (global)')
--   end
-- end, { bang = true, desc = 'Toggle format on save' })
--
-- vim.keymap.set('n', '<leader>mt', '<cmd>FormatToggle<CR>', { desc = 'Toggle format on save' })

-- Which formatter would run here, and is it actually installed? The most
-- common formatting question, and otherwise surprisingly hard to answer.
vim.keymap.set('n', '<leader>mi', '<cmd>ConformInfo<CR>', { desc = 'Formatter info for this buffer' })
