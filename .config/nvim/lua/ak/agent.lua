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
-- everything the two keys need — message formatting, delivery policy — is here,
-- next to the bindings it backs. keymaps.lua is for maps whose whole
-- implementation is one <cmd> string.
--
-- ── The multiplexer seam ───────────────────────────────────────────────────
-- Pane discovery and delivery are NOT here. They live in ak/mux.lua, which owns
-- everything multiplexer-shaped in this config — the same module the
-- <C-h/j/k/l> navigation maps go through. `mux.backends()` hands back the
-- adapters worth trying, nearest first, each exposing:
--
--   find(agent)                     -> pane target, or nil
--   send(agent, target, msg, quiet) -> ok; notifies unless quiet
--   fallback                        -> target to guess at, or nil for "don't"
--
-- What stays here is the delivery POLICY built on top of that: try a pinned
-- pane, then discovery, then a guess.
--
-- $<AGENT>_PANE (CLAUDE_PANE, OPENCODE_PANE) pins a destination pane: a tmux
-- target-pane ("%3", "session:win.0") or a herdr pane id ("wF:p6"). The two
-- formats aren't interchangeable, so a pinned target that the active backend
-- rejects is not fatal — we fall through to discovery rather than fail on a
-- stale export left in a shell profile. Unset, we go straight to discovery.

local mux = require("ak.mux")

local M = {}

-- ── The one public function ────────────────────────────────────────────────
-- Call from visual mode: prompts for a question, then delivers selection +
-- question to `agent` ("Claude", "OpenCode" — matched case-insensitively).
function M.ask(agent)
	-- Resolved once and used by all three delivery attempts below, rather than
	-- re-asked per attempt: the answer cannot change inside one keystroke.
	local backends = mux.backends()
	if #backends == 0 then
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
		if pinned and backends[1].send(agent, pinned, msg, true) then
			return
		end
		if pinned then
			vim.notify(
				("$%s (%s) was rejected; looking for a %s pane instead."):format(env_name, pinned, agent),
				vim.log.levels.WARN
			)
		end

		for _, backend in ipairs(backends) do
			local target = backend.find(agent)
			if target then
				return backend.send(agent, target, msg)
			end
		end

		-- Nothing found. tmux can still guess "the pane next door"; herdr's
		-- `agent prompt` needs a real agent target, so it offers no guess.
		for _, backend in ipairs(backends) do
			if backend.fallback then
				vim.notify(
					("No %s pane found; falling back to the next pane. Set $%s to pin one."):format(agent, env_name),
					vim.log.levels.WARN
				)
				return backend.send(agent, backend.fallback, msg)
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
