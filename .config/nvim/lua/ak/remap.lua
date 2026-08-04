vim.g.mapleader = " "

local keymap = vim.keymap

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

--window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab
keymap.set("n", "<leader>nr", ":set relativenumber!<CR>", { desc = "Toggle relative number" })

keymap.set("i", "<A-h>", "<Left>", { noremap = true })
keymap.set("i", "<A-j>", "<Down>", { noremap = true })
keymap.set("i", "<A-k>", "<Up>", { noremap = true })
keymap.set("i", "<A-l>", "<Right>", { noremap = true })

keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Map 'K' to show hover information (documentation and function signature)
keymap.set("n", "K", vim.lsp.buf.hover, { buffer = 0 })


keymap.set("v", "<leader>ac", function()
  -- yank selection to register
  vim.cmd('noau normal! "vy"')
  local selection = vim.fn.getreg("v")
  local filename = vim.fn.expand("%:t")
  local line_start = vim.fn.line("v")
  local line_end = vim.fn.line(".")

  -- ask for a prompt
  local prompt = vim.fn.input("Ask Claude: ")
  if prompt == "" then return end

  -- build the message
  local msg = string.format(
    "[%s lines %d-%d]\n%s\n\n%s",
    filename, line_start, line_end,
    selection,
    prompt
  )

  -- send to the right tmux pane (pane 1 = right)
  vim.fn.system(string.format(
    "tmux send-keys -t .+ %q Enter",
    msg
  ))
end, { desc = "Ask Claude about selection" })
