-- lua/ak/options.lua
--
-- Editor options. Deliberately contains ONLY settings that differ from Neovim
-- 0.12.4's actual defaults — every line here was checked against `nvim --clean`.
-- Things people habitually set that are already the default in 0.12, and so are
-- absent on purpose:
--
--   hlsearch, incsearch   already on
--   autoindent            already on
--   mouse=nvi             already the default
--   jumpoptions=clean     already the default
--   termguicolors         auto-detected; `:h 'termguicolors'` says "Nvim will
--                         automatically attempt to determine if the host
--                         terminal" supports it. Ghostty advertises truecolor,
--                         so setting it by hand accomplishes nothing.

local o = vim.o

-- ── Indentation ────────────────────────────────────────────────────────────
-- 2 spaces suits Ruby, TS, and JSX alike. Per-filetype overrides (Go, Make)
-- belong in autocmds.lua, not here.
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2

-- NOTE the absence of `smartindent`. It is a blunt C-style heuristic that
-- actively fights the filetype indent scripts we rely on — most visibly, it
-- yanks `#` comments to column 0, which is wrong in Ruby and ERB, and it
-- mishandles JSX. `autoindent` is on by default and the bundled
-- indent/ruby.vim, indent/typescriptreact.vim, indent/eruby.vim do the real
-- work. Setting smartindent here would make TSX and ERB indent worse.
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

-- New in 0.11+: a single global border style for ALL floating windows — LSP
-- hover, signature help, diagnostics floats. Older configs had to pass a border
-- to each plugin separately. `:h 'pumborder'` styles the completion menu
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

-- Swapfiles off. The trade: you lose crash recovery, but you stop getting the
-- "ATTENTION: found a swap file" prompt every time a process is killed or the
-- same file is open in two nvim instances — which, with undofile above and git
-- underneath, is a bad deal in the other direction. Set this back to true if
-- you ever edit over flaky SSH.
o.swapfile = false

-- Prompt to save on :q with unsaved changes instead of erroring out.
o.confirm = true

-- ── Timing ─────────────────────────────────────────────────────────────────
-- Default 4000ms. This is the CursorHold/CursorHoldI delay. 4 seconds feels
-- broken; 250ms feels live. Low values also mean more frequent swapfile writes
-- — irrelevant here since swapfile is off.
--
-- Worth being honest that nothing in this config currently depends on the
-- value. Both things that used to are now driven by their own timers:
--
--   reference highlighting  snacks' `words` module, CursorMoved + its own
--                           200ms debounce (plugins/snacks.lua). lsp.lua used
--                           to hand-roll this on CursorHold and no longer does.
--   gitsigns inline blame   current_line_blame_opts.delay = 500, set
--                           explicitly in plugins/gitsigns.lua precisely so it
--                           does NOT inherit this value.
--
-- It stays because CursorHold is a generic event any future plugin may use,
-- and 4s would be the wrong default when one does.
o.updatetime = 250

-- How long to wait for a multi-key mapping to complete. Default 1000ms is a
-- long stall on a half-typed leader sequence.
o.timeoutlen = 500

-- ── Completion ─────────────────────────────────────────────────────────────
-- menuone: show the menu even for a single match (so you can see what it is).
-- noselect: never auto-insert a completion; you choose explicitly.
--
-- Honest caveat: blink.cmp draws its own menu and largely ignores 'completeopt'.
-- This governs the built-in fallback (i_CTRL-X, and vim.lsp.completion if you
-- ever drop blink), so it's cheap insurance rather than load-bearing config.
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

-- DELIBERATELY NOT SET: clipboard = 'unnamedplus'.
-- That routes every yank, every `x`, and every `d` through the macOS system
-- clipboard, so deleting a word destroys whatever you copied from the browser.
-- keymaps.lua defines explicit <leader>y / <leader>p for system-clipboard
-- access instead. If you'd rather have the everything-is-shared behaviour,
-- uncomment the next line and delete those maps.
-- o.clipboard = 'unnamedplus'
