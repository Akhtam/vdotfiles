local opt = vim.opt

vim.schedule(function()
	opt.clipboard = "unnamedplus" -- use system keyboard for yank
end)

opt.nu = true -- set line numbers
opt.relativenumber = true

opt.showmode = false

-- Enable break indent
vim.opt.breakindent = true

opt.wrap = false -- disable line wrapping

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

-- cursor line
opt.cursorline = true -- highlight the current cursor line

opt.termguicolors = true
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- set tab size to 2 spaces
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- turn off swapfile
opt.swapfile = false

-- Scroll
opt.scrolloff = 4

vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
vim.g.copilot_enabled = 0 -- disable copilot by default
-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})
