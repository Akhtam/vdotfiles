return {
	"alexghergh/nvim-tmux-navigation",
	config = function()
		-- local nvim_tmux_nav = require("nvim-tmux-navigation")
		require("nvim-tmux-navigation").setup({})
		-- nvim_tmux_nav.setup({
		-- 	disable_when_zoomed = true, -- defaults to false
		-- })
		--
		-- vim.keymap.set("n", "<C-h>", nvim_tmux_nav.NvimTmuxNavigateLeft)
		-- vim.keymap.set("n", "<C-j>", nvim_tmux_nav.NvimTmuxNavigateDown)
		-- vim.keymap.set("n", "<C-k>", nvim_tmux_nav.NvimTmuxNavigateUp)
		-- vim.keymap.set("n", "<C-l>", nvim_tmux_nav.NvimTmuxNavigateRight)
		-- vim.keymap.set("n", "<C-\\>", nvim_tmux_nav.NvimTmuxNavigateLastActive)
		-- vim.keymap.set("n", "<C-Space>", nvim_tmux_nav.NvimTmuxNavigateNext)
		vim.keymap.set("n", "<C-h>", "<Cmd>NvimTmuxNavigateLeft<CR>", {})
		vim.keymap.set("n", "<C-j>", "<Cmd>NvimTmuxNavigateDown<CR>", {})
		vim.keymap.set("n", "<C-k>", "<Cmd>NvimTmuxNavigateUp<CR>", {})
		vim.keymap.set("n", "<C-l>", "<Cmd>NvimTmuxNavigateRight<CR>", {})
	end,
}
