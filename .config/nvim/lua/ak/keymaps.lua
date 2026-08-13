-- lua/ak/keymaps.lua
--
-- Plugin-independent keymaps only. Anything that drives a plugin (picker,
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

-- ── Claude / OpenCode ───────────────────────────────────────────────────────
-- Send the visual selection plus a one-line question to an agent CLI (Claude
-- Code, OpenCode) running in another tmux pane. The message is formatted as
--
--     path/to/file.lua:12-20
--     ```lua
--     <selected lines>
--     ```
--
--     <your prompt>
--
-- so the agent gets the file/line context along with the code.
--
-- Requires nvim to be running inside tmux. The destination pane is $<AGENT>_PANE
-- (any tmux target-pane, e.g. "%3" or "session:win.0") when set; otherwise we
-- go looking for the pane that is actually running that agent — see
-- find_agent_pane below. Only if that fails do we fall back to ".+", the next
-- pane in the current window.
--
-- Delivery goes through a named tmux buffer rather than `send-keys` so the
-- text arrives as a bracketed paste (-p): the agent's prompt sees the
-- newlines as literal newlines instead of submitting on the first one. `-d`
-- deletes the buffer after pasting. A separate `send-keys Enter` submits.
-- How to recognise each agent from `tmux list-panes` output. Both agents set a
-- pane title, but only OpenCode keeps a recognisable process name:
--
--   opencode  cmd=opencode   title=OpenCode
--   claude    cmd=2.1.229    title=◐ Fix Claude default selection in split view
--
-- Claude Code renames its process to its own version number, so the version
-- pattern IS the signature. The title is checked first for both, since it is
-- the one field the agent sets deliberately.
local agent_matchers = {
	claude = function(cmd, title)
		return title:find("claude", 1, true)
			or cmd:find("claude", 1, true)
			or cmd:match("^%d+%.%d+%.%d+$") ~= nil
	end,
	opencode = function(cmd, title)
		return title:find("opencode", 1, true) or cmd:find("opencode", 1, true)
	end,
}

-- Find the pane running `agent`, preferring the current window over the rest of
-- the session over other sessions — so with two agents side by side in this
-- window you always hit the one you asked for. Returns nil when nothing matches.
local function find_agent_pane(agent)
	local matches = agent_matchers[string.lower(agent)]
	local fmt = "#{pane_id}\t#{window_active}\t#{session_attached}\t#{pane_current_command}\t#{pane_title}"
	local r = vim.system({ "tmux", "list-panes", "-a", "-F", fmt }):wait()
	if r.code ~= 0 or not matches then
		return nil
	end

	local best, best_rank
	for line in vim.gsplit(r.stdout or "", "\n", { trimempty = true }) do
		local id, win_active, sess_attached, cmd, title = line:match("^(%S+)\t(%d)\t(%d)\t([^\t]*)\t(.*)$")
		-- never target ourselves: $TMUX_PANE is this nvim's own pane
		if id and id ~= vim.env.TMUX_PANE and matches(string.lower(cmd), string.lower(title)) then
			local rank = (win_active == "1" and 0 or 1) + (sess_attached == "1" and 0 or 2)
			if not best_rank or rank < best_rank then
				best, best_rank = id, rank
			end
		end
	end
	return best
end

local function ask_agent(agent)
	return function()
		if not vim.env.TMUX then
			return vim.notify("Not inside tmux", vim.log.levels.ERROR)
		end

		-- capture region while still in visual mode (0.10+ handles v/V/<C-v> correctly)
		local mode = vim.fn.mode()
		local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
		local srow = math.min(vim.fn.line("v"), vim.fn.line("."))
		local erow = math.max(vim.fn.line("v"), vim.fn.line("."))

		local file = vim.fn.expand("%:.")
		local ft = vim.bo.filetype
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

		local buffer = "nvim_" .. string.lower(agent)
		local env_name = string.upper(agent) .. "_PANE"

		vim.ui.input({ prompt = "Ask " .. agent .. ": " }, function(prompt)
			if not prompt or prompt == "" then
				return
			end

			local msg = string.format(
				"%s:%d-%d\n```%s\n%s\n```\n\n%s",
				file ~= "" and file or "[No Name]",
				srow,
				erow,
				ft,
				table.concat(lines, "\n"),
				prompt
			)

			local target = vim.env[env_name] or find_agent_pane(agent)
			if not target then
				vim.notify(
					("No %s pane found; falling back to the next pane. Set $%s to pin one."):format(agent, env_name),
					vim.log.levels.WARN
				)
				target = ".+"
			end

			local function tmux(args, stdin)
				local r = vim.system(vim.list_extend({ "tmux" }, args), { stdin = stdin }):wait()
				if r.code ~= 0 then
					vim.notify("tmux: " .. (r.stderr or ""), vim.log.levels.ERROR)
				end
				return r.code == 0
			end

			-- bracketed paste keeps newlines from submitting early
			if not tmux({ "load-buffer", "-b", buffer, "-" }, msg) then
				return
			end
			if not tmux({ "paste-buffer", "-b", buffer, "-t", target, "-d", "-p" }) then
				return
			end
			tmux({ "send-keys", "-t", target, "Enter" })
		end)
	end
end

map("x", "<leader>ac", ask_agent("Claude"), { desc = "Ask Claude about selection" })
map("x", "<leader>ao", ask_agent("OpenCode"), { desc = "Ask OpenCode about selection" })
