-- lua/ak/options.lua
--
-- Editor options — ONLY those differing from Neovim 0.12.5's defaults. Commonly
-- set but already the default in 0.12, so absent on purpose: hlsearch,
-- incsearch, autoindent, mouse=nvi, jumpoptions=clean, and termguicolors (auto-
-- detected, and Ghostty advertises truecolor).

local o = vim.o

-- ── Indentation ────────────────────────────────────────────────────────────
-- 2 spaces suits Ruby, TS, and JSX alike. Per-filetype overrides (Go, Make)
-- belong in autocmds.lua, not here.
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2

-- NO `smartindent`, deliberately: it's a C-style heuristic that fights the
-- filetype indent scripts — most visibly yanking `#` comments to column 0,
-- wrong in Ruby and ERB, and it mishandles JSX. `autoindent` plus the bundled
-- indent/{ruby,typescriptreact,eruby}.vim do the real work.
o.breakindent = true -- wrapped lines keep their indent level

-- ── UI ─────────────────────────────────────────────────────────────────────
o.number = true
o.relativenumber = true -- makes 5j / d3k countable at a glance

-- Pin the sign column open. Left on "auto" it appears and disappears as
-- gitsigns and diagnostics come and go, shifting all your text one column
-- sideways while you're reading it.
o.signcolumn = 'yes'

o.cursorline = true
o.scrolloff = 8     -- keep 8 lines of context above/below the cursor
o.sidescrolloff = 8 -- same horizontally, matters with nowrap below
o.wrap = false      -- code: scroll horizontally rather than reflow

-- Global statusline (one bar across the bottom) instead of one per split.
-- Default is 2 (per-window), which wastes a row per split.
o.laststatus = 3
o.showmode = false -- the statusline shows the mode; this would duplicate it

-- One global border for ALL floats (LSP hover, signature help, diagnostics), so
-- no plugin needs its own. `:h 'pumborder'` styles the completion menu
-- separately if you ever want them to differ.
o.winborder = 'rounded'
o.pumheight = 10 -- cap the completion menu; it can otherwise fill the screen

-- Hide the `~` filler on lines past the end of the buffer.
o.fillchars = 'eob: '

-- Show whitespace that matters. Trailing space is endemic in ERB and JSX and
-- invisible without this.
o.list = true
o.listchars = 'tab:» ,trail:·,nbsp:␣'

-- ── Search ─────────────────────────────────────────────────────────────────
-- Case-insensitive UNLESS the pattern contains a capital. Both are required:
-- smartcase alone does nothing without ignorecase.
o.ignorecase = true
o.smartcase = true

-- Live preview of :s in a split showing every match, not just inline.
-- Default is "nosplit" (inline only).
o.inccommand = 'split'

-- Make :grep use ripgrep instead of /usr/bin/grep. You already have rg 15.2.
-- --vimgrep gives one match per line in file:line:col:text form, which is
-- exactly what 'grepformat' below parses into the quickfix list.
o.grepprg = 'rg --vimgrep --smart-case'
o.grepformat = '%f:%l:%c:%m'

-- ── Splits ─────────────────────────────────────────────────────────────────
-- Open new splits down and to the right, matching how every other editor does
-- it. Vim's defaults (up/left) shove existing content around.
o.splitright = true
o.splitbelow = true

-- ── Files & persistence ────────────────────────────────────────────────────
-- Persistent undo: undo history survives closing the file. Lives in
-- ~/.local/share/nvim/undo, created automatically.
o.undofile = true

-- Swapfiles off: loses crash recovery, but stops the "found a swap file" prompt
-- on every killed process or doubly-opened file. With undofile above and git
-- underneath, that's the better side of the trade. Turn back on for flaky SSH.
o.swapfile = false

-- Prompt to save on :q with unsaved changes instead of erroring out.
o.confirm = true

-- ── Timing ─────────────────────────────────────────────────────────────────
-- The CursorHold delay; default 4000ms feels broken, 250ms feels live.
--
-- Nothing here currently depends on it — snacks' `words` and gitsigns' inline
-- blame both run their own timers on purpose. It stays because CursorHold is a
-- generic event any future plugin may use, and 4s would be a bad default then.
o.updatetime = 250

-- How long to wait for a multi-key mapping to complete. Default 1000ms is a
-- long stall on a half-typed leader sequence.
o.timeoutlen = 500

-- ── Completion ─────────────────────────────────────────────────────────────
-- menuone: show the menu even for a single match. noselect: never auto-insert.
--
-- blink.cmp draws its own menu and largely ignores 'completeopt', so this only
-- governs the built-in fallback (i_CTRL-X, vim.lsp.completion) — cheap
-- insurance rather than load-bearing.
o.completeopt = 'menu,menuone,noselect,popup'

-- ── Folding ────────────────────────────────────────────────────────────────
-- The treesitter foldexpr itself is set up in treesitter.lua. This just ensures
-- files open fully unfolded — otherwise every file greets you collapsed.
o.foldlevelstart = 99
o.foldlevel = 99

-- ── Misc ───────────────────────────────────────────────────────────────────
-- Let visual-block selections extend past end-of-line. Makes column edits on
-- ragged lines (aligning JSX props, Ruby hashes) behave sanely.
o.virtualedit = 'block'

-- DELIBERATELY NOT SET: clipboard = 'unnamedplus' routes every yank, `x` and
-- `d` through the system clipboard, so deleting a word destroys what you copied
-- from the browser. keymaps.lua has explicit <leader>y / <leader>p instead.
-- Uncomment and delete those maps if you want everything shared.
-- o.clipboard = 'unnamedplus'
