-- lua/ak/keymaps.lua
--
-- Plugin-independent keymaps only. Anything that drives a plugin (telescope,
-- gitsigns, neotest, dap, LSP) lives in that plugin's own file, so a binding is
-- always next to the thing it controls.
--
-- NOT DEFINED HERE, because Neovim 0.12 already ships them as defaults —
-- redefining them would be pure cargo cult (verified with `nvim --clean`):
--
--   grn   rename symbol            gra   code action
--   grr   find references          gri   go to implementation
--   gO    document symbols         K     hover documentation
--   ]d / [d   next/prev diagnostic
--   CTRL-W  variants for every window motion

local map = vim.keymap.set

-- ── Window management ──────────────────────────────────────────────────────
map('n', '<leader>sv', '<C-w>v', { desc = 'Split window vertically' })
map('n', '<leader>sh', '<C-w>s', { desc = 'Split window horizontally' })
map('n', '<leader>se', '<C-w>=', { desc = 'Make splits equal size' })
map('n', '<leader>sx', '<cmd>close<CR>', { desc = 'Close current split' })

-- Move between splits without the <C-w> prefix. Worth the two extra maps
-- because window switching is the single most repeated motion in a day.
map('n', '<C-h>', '<C-w>h', { desc = 'Go to left split' })
map('n', '<C-j>', '<C-w>j', { desc = 'Go to split below' })
map('n', '<C-k>', '<C-w>k', { desc = 'Go to split above' })
map('n', '<C-l>', '<C-w>l', { desc = 'Go to right split' })

-- ── Tabs ───────────────────────────────────────────────────────────────────
-- NOTE: this claims the whole <leader>t namespace. neotest conventionally uses
-- <leader>t too, so when we write neotest.lua its maps go under <leader>T
-- (capital) to leave your muscle memory intact. See the note at the end.
map('n', '<leader>to', '<cmd>tabnew<CR>', { desc = 'Open new tab' })
map('n', '<leader>tx', '<cmd>tabclose<CR>', { desc = 'Close current tab' })
map('n', '<leader>tn', '<cmd>tabn<CR>', { desc = 'Go to next tab' })
map('n', '<leader>tp', '<cmd>tabp<CR>', { desc = 'Go to previous tab' })
map('n', '<leader>tf', '<cmd>tabnew %<CR>', { desc = 'Open current buffer in new tab' })

-- ── Toggles ────────────────────────────────────────────────────────────────
map('n', '<leader>nr', '<cmd>set relativenumber!<CR>', { desc = 'Toggle relative number' })

-- ── Insert-mode cursor movement ────────────────────────────────────────────
-- ⚠️  THESE WILL NOT FIRE IN GHOSTTY AS CURRENTLY CONFIGURED.
--
-- `ghostty +show-config --default` reports `macos-option-as-alt =` (unset,
-- i.e. off), which means the Option key emits macOS special characters rather
-- than an Alt/Meta modifier: Option+h sends `˙`, Option+j sends `∆`,
-- Option+k sends `˚`, Option+l sends `¬`. Neovim never sees <A-h> at all.
--
-- Fix: add ONE line to ~/.dotfiles/.config/ghostty/config —
--     macos-option-as-alt = left
-- Left Option becomes Alt (these maps work), right Option keeps typing
-- special characters (é, #, …). Using `true` would sacrifice both keys.
map('i', '<A-h>', '<Left>', { noremap = true })
map('i', '<A-j>', '<Down>', { noremap = true })
map('i', '<A-k>', '<Up>', { noremap = true })
map('i', '<A-l>', '<Right>', { noremap = true })

-- ── Visual mode ────────────────────────────────────────────────────────────
-- Move the selected lines up/down. Breakdown of `:m '>+1<CR>gv=gv`:
--   :m '>+1  move the selection to just after its last line ('> is the end mark)
--   gv       reselect the block you just moved (`:m` drops the selection)
--   =        re-indent it to fit its new context
--   gv       reselect again, since `=` also drops the selection
-- The `=` is what makes this work in nested JSX and Ruby blocks: dragging a
-- line into or out of a block fixes its indentation automatically, using the
-- bundled filetype indent scripts.
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Stay in visual mode when shifting, so you can press > > > instead of
-- > gv > gv >. This is a re-map of an existing key, not a new binding.
map('v', '<', '<gv', { desc = 'Indent left, keep selection' })
map('v', '>', '>gv', { desc = 'Indent right, keep selection' })

-- ── Search ─────────────────────────────────────────────────────────────────
-- Clear search highlight. 'hlsearch' is on by default in Neovim and stays lit
-- until the next search; this gives it an off switch on a key you already hit
-- reflexively.
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- Keep the cursor centred while cycling matches and half-page scrolling, so
-- your eyes stay in one place instead of tracking up and down the screen.
-- `zv` additionally opens any fold the match landed inside.
map('n', 'n', 'nzzzv', { desc = 'Next match, centred' })
map('n', 'N', 'Nzzzv', { desc = 'Prev match, centred' })
map('n', '<C-d>', '<C-d>zz', { desc = 'Half page down, centred' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Half page up, centred' })

-- ── System clipboard ───────────────────────────────────────────────────────
-- Explicit opt-in, because options.lua deliberately does NOT set
-- clipboard=unnamedplus. `"+` is the system clipboard register; every `d`, `x`
-- and `c` you type stays in the unnamed register and leaves it alone.
map({ 'n', 'v' }, '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
map('n', '<leader>Y', '"+Y', { desc = 'Yank line to system clipboard' })
map({ 'n', 'v' }, '<leader>p', '"+p', { desc = 'Paste from system clipboard' })

-- Paste over a visual selection WITHOUT the replaced text overwriting your
-- register — so you can paste the same thing repeatedly. `"_` is the black
-- hole register: the deleted text goes nowhere.
map('v', '<leader>P', '"_dP', { desc = 'Paste over selection, keep register' })

-- ── Quickfix ───────────────────────────────────────────────────────────────
-- ]q / [q mirror the built-in ]d / [d diagnostic pair. The quickfix list is
-- what :grep (ripgrep, wired up in options.lua) and telescope's
-- send-to-quickfix both populate.
map('n', ']q', '<cmd>cnext<CR>zz', { desc = 'Next quickfix item' })
map('n', '[q', '<cmd>cprev<CR>zz', { desc = 'Prev quickfix item' })
map('n', '<leader>q', '<cmd>copen<CR>', { desc = 'Open quickfix list' })
