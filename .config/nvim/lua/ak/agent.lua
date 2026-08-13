-- lua/ak/agent.lua
--
-- Ask a coding agent about the visual selection.
--
-- <leader>ac / <leader>ao send the selected lines plus a one-line question to an
-- agent CLI (Claude Code, OpenCode) running in another pane. The message is
-- formatted as
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
-- This module lives outside keymaps.lua for the same reason a plugin's maps do:
-- everything the two keys need — pane discovery, two multiplexer protocols,
-- message formatting — is here, next to the bindings it backs. keymaps.lua is
-- for maps whose whole implementation is one <cmd> string.
--
-- ── The multiplexer seam ───────────────────────────────────────────────────
-- Works under either multiplexer: herdr (detected via $HERDR_ENV) is preferred
-- when present, tmux otherwise. Each backend below exposes the same interface:
--
--   find(agent)                     -> pane target, or nil
--   send(agent, target, msg, quiet) -> ok; notifies unless quiet
--   fallback                        -> target to guess at, or nil for "don't"
--
-- `agent` is passed to send because tmux needs it to name its paste buffer.
--
-- $<AGENT>_PANE (CLAUDE_PANE, OPENCODE_PANE) pins a destination pane: a tmux
-- target-pane ("%3", "session:win.0") or a herdr pane id ("wF:p6"). The two
-- formats aren't interchangeable, so a pinned target that the active backend
-- rejects is not fatal — we fall through to discovery rather than fail on a
-- stale export left in a shell profile. Unset, we go straight to discovery.

local M = {}

-- ── tmux ───────────────────────────────────────────────────────────────────
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
		return title:find("claude", 1, true) or cmd:find("claude", 1, true) or cmd:match("^%d+%.%d+%.%d+$") ~= nil
	end,
	opencode = function(cmd, title)
		return title:find("opencode", 1, true) or cmd:find("opencode", 1, true)
	end,
}

-- Find the pane running `agent`, preferring the current window over the rest of
-- the session over other sessions — so with two agents side by side in this
-- window you always hit the one you asked for. Returns nil when nothing matches.
local function tmux_find(agent)
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

local function tmux_send(agent, target, msg, quiet)
	local function tmux(args, stdin)
		local r = vim.system(vim.list_extend({ "tmux" }, args), { stdin = stdin }):wait()
		if r.code ~= 0 and not quiet then
			vim.notify("tmux: " .. (r.stderr or ""), vim.log.levels.ERROR)
		end
		return r.code == 0
	end

	local buffer = "nvim_" .. string.lower(agent)

	-- bracketed paste keeps newlines from submitting early
	if not tmux({ "load-buffer", "-b", buffer, "-" }, msg) then
		return false
	end
	if not tmux({ "paste-buffer", "-b", buffer, "-t", target, "-d", "-p" }) then
		return false
	end
	return tmux({ "send-keys", "-t", target, "Enter" })
end

-- ── herdr ──────────────────────────────────────────────────────────────────
-- No title/process sniffing here: herdr classifies agents itself and reports a
-- canonical kind ("claude", "opencode") per pane, so `agent list` IS the lookup
-- table that agent_matchers has to reconstruct for tmux.
--
-- Ranking mirrors the tmux one — same tab beats same workspace beats anything
-- else — so two agents side by side resolve to the near one.
local function herdr_find(agent)
	local r = vim.system({ "herdr", "agent", "list" }):wait()
	if r.code ~= 0 then
		return nil
	end
	-- type-check every hop rather than rely on truthiness: vim.json.decode maps
	-- JSON null to vim.NIL, a userdata that is truthy and blows up on index.
	local ok, decoded = pcall(vim.json.decode, r.stdout or "")
	if not ok or type(decoded) ~= "table" or type(decoded.result) ~= "table" then
		return nil
	end
	local agents = decoded.result.agents
	if type(agents) ~= "table" then
		return nil
	end

	local want = string.lower(agent)
	local best, best_rank
	for _, a in ipairs(agents) do
		-- never target ourselves: $HERDR_PANE_ID is this nvim's own pane
		if
			type(a) == "table"
			and a.agent == want
			and type(a.pane_id) == "string"
			and a.pane_id ~= vim.env.HERDR_PANE_ID
		then
			local rank = (a.tab_id == vim.env.HERDR_TAB_ID and 0 or 1)
				+ (a.workspace_id == vim.env.HERDR_WORKSPACE_ID and 0 or 2)
			if not best_rank or rank < best_rank then
				best, best_rank = a.pane_id, rank
			end
		end
	end
	return best
end

-- `agent prompt` submits text and Enter in one call, honouring the pane's live
-- bracketed-paste mode — so it needs none of the tmux buffer dance. No --wait:
-- we hand the prompt over and get out of the way.
local function herdr_send(_agent, target, msg, quiet)
	local r = vim.system({ "herdr", "agent", "prompt", target, msg }):wait()
	if r.code ~= 0 and not quiet then
		vim.notify("herdr: " .. (r.stderr or ""), vim.log.levels.ERROR)
	end
	return r.code == 0
end

local herdr_backend = { find = herdr_find, send = herdr_send, fallback = nil }
local tmux_backend = { find = tmux_find, send = tmux_send, fallback = ".+" }

-- Backends to try, most likely first. This is a LIST rather than a single
-- pick because "inside herdr" doesn't prove the agents are herdr's: nvim can
-- sit in a tmux session nested inside a herdr pane, with claude/opencode in
-- tmux panes. herdr is asked first, and when it has nothing we fall through
-- instead of hard-failing a setup that worked before.
local function backends()
	local list = {}
	if vim.env.HERDR_ENV == "1" then
		list[#list + 1] = herdr_backend
	end
	if vim.env.TMUX then
		list[#list + 1] = tmux_backend
	end
	return list
end

-- ── The one public function ────────────────────────────────────────────────
-- Call from visual mode: prompts for a question, then delivers selection +
-- question to `agent` ("Claude", "OpenCode" — matched case-insensitively).
function M.ask(agent)
	local bes = backends()
	if #bes == 0 then
		return vim.notify("Not inside tmux or herdr", vim.log.levels.ERROR)
	end

	-- capture region while still in visual mode (0.10+ handles v/V/<C-v> correctly)
	local mode = vim.fn.mode()
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
	local srow = math.min(vim.fn.line("v"), vim.fn.line("."))
	local erow = math.max(vim.fn.line("v"), vim.fn.line("."))

	local file = vim.fn.expand("%:.")
	local ft = vim.bo.filetype
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

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

		-- A pinned pane is a hint, not a contract: it may be in the other
		-- multiplexer's id format. Try it quietly, and on rejection carry
		-- on to discovery rather than surfacing a raw CLI error.
		local pinned = vim.env[env_name]
		if pinned and bes[1].send(agent, pinned, msg, true) then
			return
		end
		if pinned then
			vim.notify(
				("$%s (%s) was rejected; looking for a %s pane instead."):format(env_name, pinned, agent),
				vim.log.levels.WARN
			)
		end

		for _, be in ipairs(bes) do
			local target = be.find(agent)
			if target then
				return be.send(agent, target, msg)
			end
		end

		-- Nothing found. tmux can still guess "the pane next door"; herdr's
		-- `agent prompt` needs a real agent target, so it offers no guess.
		for _, be in ipairs(bes) do
			if be.fallback then
				vim.notify(
					("No %s pane found; falling back to the next pane. Set $%s to pin one."):format(agent, env_name),
					vim.log.levels.WARN
				)
				return be.send(agent, be.fallback, msg)
			end
		end

		vim.notify(("No %s agent pane found. Set $%s to pin one."):format(agent, env_name), vim.log.levels.ERROR)
	end)
end

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Defined here, not in keymaps.lua, so the binding sits next to the thing it
-- controls. <leader>a is otherwise unclaimed.
vim.keymap.set("x", "<leader>ac", function()
	M.ask("Claude")
end, { desc = "Ask Claude about selection" })

vim.keymap.set("x", "<leader>ao", function()
	M.ask("OpenCode")
end, { desc = "Ask OpenCode about selection" })

return M
