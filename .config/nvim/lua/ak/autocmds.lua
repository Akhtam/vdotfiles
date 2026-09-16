-- lua/ak/autocmds.lua
--
-- Editor behaviour driven by events. Plugin-specific autocmds live with their
-- plugin; these are all core-only.
--
-- Every autocmd below is registered in a named group created with clear = true.
-- That matters: without a group, re-sourcing this file (or `:source $MYVIMRC`)
-- stacks a SECOND copy of every autocmd, and they all fire. Clearing the group
-- first makes this file safely re-runnable.

local function augroup(name)
  return vim.api.nvim_create_augroup('ak_' .. name, { clear = true })
end

local autocmd = vim.api.nvim_create_autocmd

-- ── Highlight yanked text ──────────────────────────────────────────────────
-- The only feedback Vim gives that a yank happened, which makes motion-y yanks
-- (y2j, yi{) verifiable at a glance. `vim.hl.on_yank` in 0.11+;
-- `vim.highlight.on_yank` is a deprecated alias.
autocmd('TextYankPost', {
  group = augroup('highlight_yank'),
  callback = function()
    vim.hl.on_yank({ higroup = 'IncSearch', timeout = 150 })
  end,
})

-- ── Restore cursor position ────────────────────────────────────────────────
-- Reopen a file on the line you left it. The `"` mark is set by Neovim when a
-- buffer is unloaded and persisted in the shada file.
--
-- The line-count guard is not optional: if the file shrank since you last
-- opened it (git checkout, rebase), the saved mark can point past the end of
-- the buffer and nvim_win_set_cursor throws.
autocmd('BufReadPost', {
  group = augroup('restore_cursor'),
  callback = function(ev)
    local exclude = { 'gitcommit', 'gitrebase', 'commit', 'rebase' }
    if vim.tbl_contains(exclude, vim.bo[ev.buf].filetype) then
      return -- always start at the top when writing a commit message
    end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ── Large file guard ───────────────────────────────────────────────────────
-- A mature Rails app's db/schema.rb runs to tens of thousands of lines, and
-- checked-in bundles are worse — enough to bring a treesitter highlighter to
-- its knees.
--
-- Sets b:ak_big_file BEFORE the file is read, then drops the features whose
-- cost scales with size. THE FLAG IS A CROSS-MODULE PROTOCOL: treesitter.lua
-- (skips attaching) and plugins/lint.lua (skips linting) both read it.
--
-- 1.5MB: high enough that no hand-written source file trips it, low enough to
-- catch generated output.
local BIG_FILE_BYTES = 1.5 * 1024 * 1024

local big_file_group = augroup('big_file')

autocmd('BufReadPre', {
  group = big_file_group,
  callback = function(ev)
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
    if not ok or not stats or stats.size <= BIG_FILE_BYTES then
      return
    end

    vim.b[ev.buf].ak_big_file = true

    -- Buffer-local: undo history and swap are per-buffer costs.
    vim.bo[ev.buf].undofile = false
    vim.bo[ev.buf].swapfile = false

    vim.notify(
      ('Large file (%.1f MB): treesitter, syntax, and undo disabled'):format(stats.size / 1024 / 1024),
      vim.log.levels.WARN
    )
  end,
})

-- Filetype syntax and indent scripts run after BufReadPre, so disable syntax
-- here rather than clearing it early and allowing it to be re-enabled later.
autocmd('FileType', {
  group = big_file_group,
  callback = function(ev)
    if not vim.b[ev.buf].ak_big_file then
      return
    end

    vim.bo[ev.buf].syntax = ''
    -- vim.wo[0][0] scopes to this buffer in the window, so the next file opened
    -- there doesn't inherit these. See the fold note in treesitter.lua.
    for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
      vim.api.nvim_win_call(win, function()
        vim.wo[0][0].foldmethod = 'manual'
        vim.wo[0][0].wrap = false
      end)
    end
  end,
})

-- ── Create missing directories on save ─────────────────────────────────────
-- `:e src/components/new/Thing.tsx` on a path that doesn't exist yet fails at
-- write time with E212. This creates the parent directories instead.
--
-- Skip non-file buffers and URI schemes (oil://, fugitive://, scp://), where
-- the "directory" is not a filesystem path at all.
autocmd('BufWritePre', {
  group = augroup('auto_mkdir'),
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= '' or ev.match:find('^[%a][%w+.-]*://') then
      return
    end
    local file = vim.uv.fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})

-- ── Close utility buffers with q ───────────────────────────────────────────
-- Help, quickfix, and man pages are read-only scratch windows (:checkhealth
-- maps q itself); requiring
-- :q for them is friction with no upside. Kept buffer-local so `q` still
-- starts a macro recording everywhere else.
autocmd('FileType', {
  group = augroup('quick_close'),
  pattern = {
    'help',
    'qf',
    'man',
    'startuptime',
    'query', -- :InspectTree output
  },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false -- keep them out of :bnext rotation
    vim.keymap.set('n', 'q', '<cmd>close<CR>', { buf = ev.buf, silent = true })
  end,
})

-- ── Terminal buffers ───────────────────────────────────────────────────────
-- Start in insert mode so :terminal is immediately typeable. Core's own
-- TermOpen already turns off number, relativenumber and signcolumn
-- (`:h default-autocmds`).
autocmd('TermOpen', {
  group = augroup('terminal'),
  callback = function()
    vim.cmd('startinsert')
  end,
})

-- ── Equalize splits when the terminal is resized ───────────────────────────
-- Without this, un-zooming Ghostty or changing font size leaves splits at
-- their old absolute widths, often with one squeezed to a sliver.
autocmd('VimResized', {
  group = augroup('resize_splits'),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd('tabdo wincmd =')
    vim.cmd('tabnext ' .. current_tab) -- tabdo leaves you on the last tab
  end,
})

-- ── Reload files changed outside Neovim ────────────────────────────────────
-- 'autoread' is on by default but only acts when Neovim happens to check. This
-- forces the check on focus and buffer entry, so files rewritten by git
-- checkout, rubocop -a or prettier --write don't show up stale.
autocmd({ 'FocusGained', 'TermClose', 'TermLeave', 'BufEnter' }, {
  group = augroup('checktime'),
  callback = function()
    -- checktime errors in command-line window mode; guard rather than pcall so
    -- the intent is visible.
    if vim.o.buftype ~= 'nofile' then
      vim.cmd('checktime')
    end
  end,
})

-- ── Per-filetype indent overrides ──────────────────────────────────────────
-- options.lua sets a global 2-space default, correct for Ruby, TS, and JSX.
-- These are the filetypes where that is actively wrong.
autocmd('FileType', {
  group = augroup('indent_overrides'),
  pattern = { 'go', 'make', 'gitconfig' },
  callback = function(ev)
    -- These formats are tab-significant: Make requires literal tabs, and
    -- gofmt emits them.
    vim.bo[ev.buf].expandtab = false
    vim.bo[ev.buf].shiftwidth = 4
    vim.bo[ev.buf].tabstop = 4
  end,
})

-- DELIBERATELY ABSENT: strip-trailing-whitespace on save. conform already runs
-- prettierd and rubocop, which strip it in the files they own — so a blanket
-- stripper only touches the files they DON'T (Markdown, where two trailing
-- spaces are a hard line break; fixtures; vendored code; .patch files) and
-- rewrites lines you never edited, turning a two-line diff into a fifty-line
-- one. 'list' is on in options.lua, so you can see and remove it deliberately.
