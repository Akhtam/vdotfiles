-- lua/ak/plugins/conform.lua
--
-- Formatting. conform runs external formatters and can fall back to the LSP.
--
-- Division of labour, decided per language rather than globally:
--   JS/TS/CSS/JSON/YAML/MD  prettierd  (daemon: fast enough for format-on-save)
--   Ruby/ERB                the LSP    (ruby-lsp formats in-process; shelling
--                                       out to rubocop costs 1-3s of VM boot)
--   Lua                     stylua

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
    --
    -- Preference is ruby-lsp, which has rubocop loaded in-process and formats
    -- instantly. Shelling out to the rubocop CLI costs 1-3s of Ruby VM boot,
    -- well past where format-on-save stops feeling automatic.
    --
    -- But ruby-lsp only advertises formatting when it RESOLVES a formatter,
    -- and `formatter = 'auto'` resolves by inspecting the bundle — not by
    -- looking for a .rubocop.yml. Verified: in a project with a .rubocop.yml
    -- but no Gemfile, ruby_lsp:supports_method('textDocument/formatting')
    -- returns false. Leaving Ruby out of this table entirely would mean such a
    -- project gets NO formatting from either path.
    --
    -- So: a function, evaluated per buffer. Empty list => conform defers to
    -- lsp_format below. Non-empty => the CLI runs.
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
  format_on_save = function(bufnr)
    -- Escape hatch: `:noautocmd w` won't help because conform uses BufWritePre,
    -- so this checks a variable instead. Toggle it with <leader>mt below when
    -- you need to save something the formatter would mangle (a fixture, a
    -- vendored file, a half-finished refactor).
    if vim.g.ak_disable_autoformat or vim.b[bufnr].ak_disable_autoformat then
      return
    end

    return {
      timeout_ms = 1000,

      -- 'fallback' = use a formatter from the table above if one exists,
      -- otherwise ask the LSP. This is what routes Ruby to ruby-lsp.
      --
      -- Note this is the modern spelling. The `lsp_fallback = true` in your old
      -- config still works but is deprecated in current conform; `lsp_format`
      -- takes 'never' | 'fallback' | 'prefer' | 'first' | 'last' and is more
      -- explicit about ordering.
      lsp_format = 'fallback',
    }
  end,
})

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Yours, verbatim in behaviour. `lsp_fallback = true` translated to
-- `lsp_format = 'fallback'` — same meaning, current spelling.
--
-- async = false is deliberate on a manual format: it blocks until done, so a
-- format immediately followed by :w can't race and write the unformatted text.
vim.keymap.set({ 'n', 'v' }, '<leader>mp', function()
  conform.format({
    lsp_format = 'fallback',
    async = false,
    timeout_ms = 1000,
  })
end, { desc = 'Format file or range (in visual mode)' })

-- Toggle format-on-save. Buffer-local with a bang, global without.
vim.api.nvim_create_user_command('FormatToggle', function(args)
  if args.bang then
    vim.b.ak_disable_autoformat = not vim.b.ak_disable_autoformat
    vim.notify('Format on save ' .. (vim.b.ak_disable_autoformat and 'OFF' or 'ON') .. ' (buffer)')
  else
    vim.g.ak_disable_autoformat = not vim.g.ak_disable_autoformat
    vim.notify('Format on save ' .. (vim.g.ak_disable_autoformat and 'OFF' or 'ON') .. ' (global)')
  end
end, { bang = true, desc = 'Toggle format on save' })

vim.keymap.set('n', '<leader>mt', '<cmd>FormatToggle<CR>', { desc = 'Toggle format on save' })

-- Which formatter would run here, and is it actually installed? The most
-- common formatting question, and otherwise surprisingly hard to answer.
vim.keymap.set('n', '<leader>mi', '<cmd>ConformInfo<CR>', { desc = 'Formatter info for this buffer' })
