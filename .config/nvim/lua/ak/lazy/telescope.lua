return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = { "nvim-lua/plenary.nvim" },

	config = function()
		local telescope = require("telescope")
		local builtin = require("telescope.builtin")
		local themes = require("telescope.themes")
		local actions = require("telescope.actions")

		local shared_mapping = function()
			return {
				["<C-h>"] = actions.file_split, -- Open file in horizontal split
				["<A-k>"] = actions.move_selection_previous,
				["<A-j>"] = actions.move_selection_next,
				["<A-f>"] = actions.preview_scrolling_down,
				["<A-b>"] = actions.preview_scrolling_up,
			}
		end

		-- 1. Use ivy theme for all pickers by default
		telescope.setup({
			defaults = themes.get_ivy({
				path_display = { "smart" },
				mappings = {
					-- Insert mode
					i = shared_mapping(),
					-- Normal mode
					n = shared_mapping(),
				},
			}),

			pickers = {
				lsp_references = {
					show_line = false,
				},
			},
			-- If you still want a custom theme for certain pickers, you can configure:
			-- pickers = {
			--   find_files = { theme = "dropdown" },
			--   live_grep  = { theme = "dropdown" },
			-- },
		})

		local opts = { noremap = true, silent = true }

		vim.keymap.set("n", "<leader>ff", builtin.find_files, opts)
		vim.keymap.set("n", "<leader>fr", builtin.lsp_references, opts)
		vim.keymap.set("n", "<leader>fg", builtin.git_files, opts)
		vim.keymap.set("n", "<leader>fl", builtin.live_grep, opts)
		vim.keymap.set("n", "<leader>fb", builtin.buffers, opts)
	end,
}
