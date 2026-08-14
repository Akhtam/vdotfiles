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
-- the implementation behind the two keys — capturing the selection, formatting
-- the message — is here, next to the bindings it backs. keymaps.lua is for maps
-- whose whole implementation is one <cmd> string.
--
-- ── The multiplexer seam ───────────────────────────────────────────────────
-- Nothing multiplexer-shaped is here. Finding the agent's pane, choosing
-- between a pinned target and discovery and a guess, and speaking tmux or
-- herdr to actually deliver — all of it is behind ak/mux.lua, the same module
-- the <C-h/j/k/l> navigation maps go through. Two calls is the whole seam:
--
--   mux.reachable()          is there a multiplexer to deliver through?
--   mux.deliver(agent, msg)  -> ok, err
--
-- It used to be more, and that was the bug: this file held backends[1], read
-- .fallback off an adapter, and called .find/.send itself, so the delivery
-- ladder lived here while every fact it reasoned about lived there. Adding a
-- third multiplexer meant editing both files.
--
-- What is genuinely this module's own: what a message to an agent LOOKS like.

local mux = require("ak.mux")

local M = {}

-- ── The one public function ────────────────────────────────────────────────
-- Call from visual mode: prompts for a question, then delivers selection +
-- question to `agent` ("Claude", "OpenCode" — matched case-insensitively).
function M.ask(agent)
	-- Checked BEFORE prompting, not at delivery time: taking your question and
	-- only then admitting there is nowhere to send it wastes the typing.
	--
	-- deliver() checks this too and would return the same message, so the text
	-- is mux's to own — asking for it here rather than restating it keeps the
	-- two paths from drifting into two different wordings of one condition.
	if not mux.reachable() then
		return vim.notify(mux.no_backend_error, vim.log.levels.ERROR)
	end

	-- capture region while still in visual mode (0.10+ handles v/V/<C-v> correctly)
	local mode = vim.fn.mode()
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
	local srow = math.min(vim.fn.line("v"), vim.fn.line("."))
	local erow = math.max(vim.fn.line("v"), vim.fn.line("."))

	local file = vim.fn.expand("%:.")
	local ft = vim.bo.filetype
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

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

		-- err is nil when mux already reported the failure itself, with the
		-- multiplexer's own stderr — better than anything we could add here.
		local ok, err = mux.deliver(agent, msg)
		if not ok and err then
			vim.notify(err, vim.log.levels.ERROR)
		end
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
