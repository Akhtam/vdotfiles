-- lua/ak/keymaps.lua
--
-- Plugin-independent keymaps only: anything driving a plugin lives in that
-- plugin's file, so a binding sits next to what it controls. Same rule for maps
-- with a real implementation behind them — <leader>ac / <leader>ao are in
-- ak/agent.lua. What's left here is maps whose implementation is one <cmd>.
--
-- NOT DEFINED HERE, because Neovim 0.12 ships them as defaults:
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

-- <C-h/j/k/l> split navigation lives in ak/mux.lua: it's a superset of
-- <C-w>h/j/k/l that also crosses into the neighbouring tmux/herdr pane at the
-- window edge. Defining them here too would shadow (or be shadowed by) that
-- module depending on load order.

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
-- LEFT Option only. Whether Option arrives as Alt is a terminal decision, made
-- in ghostty/config (`macos-option-as-alt = left`) — right Option still types
-- é, # and friends.
map("i", "<A-h>", "<Left>")
map("i", "<A-j>", "<Down>")
map("i", "<A-k>", "<Up>")
map("i", "<A-l>", "<Right>")

-- ── Visual mode ────────────────────────────────────────────────────────────
-- Move selected lines. `:m '>+1<CR>gv=gv` reads as: move past the end mark,
-- reselect (`:m` drops the selection), re-indent, reselect again (`=` drops it
-- too). The `=` is what makes this work in nested JSX and Ruby blocks —
-- dragging a line into or out of a block fixes its indentation.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Stay in visual mode when shifting, so you can press > > > instead of
-- > gv > gv >. This is a re-map of an existing key, not a new binding.
map("v", "<", "<gv", { desc = "Indent left, keep selection" })
map("v", ">", ">gv", { desc = "Indent right, keep selection" })

-- ── Search ─────────────────────────────────────────────────────────────────
-- 'hlsearch' stays lit until the next search; this puts an off switch on a key
-- you already hit reflexively.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Keep the cursor centred while cycling matches and half-page scrolling, so
-- your eyes stay in one place. `zv` also opens any fold the match landed in.
map("n", "n", "nzzzv", { desc = "Next match, centred" })
map("n", "N", "Nzzzv", { desc = "Prev match, centred" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down, centred" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up, centred" })

-- ── System clipboard ───────────────────────────────────────────────────────
-- Explicit opt-in, because options.lua deliberately does NOT set
-- clipboard=unnamedplus: every `d`, `x` and `c` stays in the unnamed register
-- and leaves `"+` alone.
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
