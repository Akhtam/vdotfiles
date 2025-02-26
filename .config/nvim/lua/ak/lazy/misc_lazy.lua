return {
	{ "nvim-tree/nvim-web-devicons", opts = {} },
	{ "echasnovski/mini.icons", version = "*" },
	{
		"stevearc/dressing.nvim",
		event = "VeryLazy",
	},
	{
		"szw/vim-maximizer",
		keys = {
			{ "<leader>sm", "<cmd>MaximizerToggle<CR>", desc = "Maximize/minimize a split" },
		},
	},

	{
		"lukas-reineke/indent-blankline.nvim",
		event = { "BufReadPre", "BufNewFile" },
		main = "ibl",
		opts = {
			indent = { char = "▏" },
			scope = {
				enabled = false,
			},
		},
	},
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
		-- use opts = {} for passing setup options
		-- this is equivalent to setup({}) function
	},
}
