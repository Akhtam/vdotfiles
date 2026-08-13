-- lua/ak/keymaps.lua
--
-- Plugin-independent keymaps only. Anything that drives a plugin (picker,
-- gitsigns, neotest, dap, LSP) lives in that plugin's own file, so a binding is
-- always next to the thing it controls. The same rule applies to a map with a
-- real implementation behind it even when no plugin is involved: <leader>ac /
-- <leader>ao (ask Claude/OpenCode about the selection) live in ak/agent.lua.
-- What's left here is maps whose whole implementation is one <cmd> string.
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
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- <C-h/j/k/l> split navigation lives in plugins/tmux.lua, not here.
--
-- vim-tmux-navigator binds those four keys to a superset of <C-w>h/j/k/l:
-- identical between Neovim splits, and additionally crossing into tmux panes
-- at the window edge. Defining them here as well would just be shadowed
-- depending on load order, so they're defined once, next to the plugin that
-- gives them their extra behaviour.

-- ── Tabs ───────────────────────────────────────────────────────────────────
-- NOTE: <leader>t is claimed by neotest (its maps live in neotest.lua), so
-- tabs share the capitalized <leader>T namespace instead.
map("n", "<leader>To", "<cmd>tabnew<CR>", { desc = "Open new tab" })
map("n", "<leader>Tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
map("n", "<leader>Tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
map("n", "<leader>Tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
map("n", "<leader>Tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- ── Toggles ────────────────────────────────────────────────────────────────
map("n", "<leader>nr", "<cmd>set relativenumber!<CR>", { desc = "Toggle relative number" })

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
map("i", "<A-h>", "<Left>", { noremap = true })
map("i", "<A-j>", "<Down>", { noremap = true })
map("i", "<A-k>", "<Up>", { noremap = true })
map("i", "<A-l>", "<Right>", { noremap = true })

-- ── Visual mode ────────────────────────────────────────────────────────────
-- Move the selected lines up/down. Breakdown of `:m '>+1<CR>gv=gv`:
--   :m '>+1  move the selection to just after its last line ('> is the end mark)
--   gv       reselect the block you just moved (`:m` drops the selection)
--   =        re-indent it to fit its new context
--   gv       reselect again, since `=` also drops the selection
-- The `=` is what makes this work in nested JSX and Ruby blocks: dragging a
-- line into or out of a block fixes its indentation automatically, using the
-- bundled filetype indent scripts.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Stay in visual mode when shifting, so you can press > > > instead of
-- > gv > gv >. This is a re-map of an existing key, not a new binding.
map("v", "<", "<gv", { desc = "Indent left, keep selection" })
map("v", ">", ">gv", { desc = "Indent right, keep selection" })

-- ── Search ─────────────────────────────────────────────────────────────────
-- Clear search highlight. 'hlsearch' is on by default in Neovim and stays lit
-- until the next search; this gives it an off switch on a key you already hit
-- reflexively.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Keep the cursor centred while cycling matches and half-page scrolling, so
-- your eyes stay in one place instead of tracking up and down the screen.
-- `zv` additionally opens any fold the match landed inside.
map("n", "n", "nzzzv", { desc = "Next match, centred" })
map("n", "N", "Nzzzv", { desc = "Prev match, centred" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down, centred" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up, centred" })

-- ── System clipboard ───────────────────────────────────────────────────────
-- Explicit opt-in, because options.lua deliberately does NOT set
-- clipboard=unnamedplus. `"+` is the system clipboard register; every `d`, `x`
-- and `c` you type stays in the unnamed register and leaves it alone.
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })

-- Paste over a visual selection WITHOUT the replaced text overwriting your
-- register — so you can paste the same thing repeatedly. `"_` is the black
-- hole register: the deleted text goes nowhere.
map("v", "<leader>P", '"_dP', { desc = "Paste over selection, keep register" })

-- ── Quickfix ───────────────────────────────────────────────────────────────
-- ]q / [q mirror the built-in ]d / [d diagnostic pair. The quickfix list is
-- what :grep (ripgrep, wired up in options.lua) and the picker's
-- send-to-quickfix (<C-q>) both populate.
map("n", "]q", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
map("n", "[q", "<cmd>cprev<CR>zz", { desc = "Prev quickfix item" })
map("n", "<leader>q", "<cmd>copen<CR>", { desc = "Open quickfix list" })
