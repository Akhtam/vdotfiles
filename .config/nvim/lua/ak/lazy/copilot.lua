return {
  "github/copilot.vim",
  event = "VeryLazy",
  config = function()
    -- Define a function or inline logic to toggle Copilot
    local function toggle_copilot()
      if vim.g.copilot_enabled == nil or vim.g.copilot_enabled == 1 then
        vim.cmd("Copilot disable")
        vim.g.copilot_enabled = 0
        print("Copilot disabled")
      else
        vim.cmd("Copilot enable")
        vim.g.copilot_enabled = 1
        print("Copilot enabled")
      end
    end

    -- Create a keymap for toggling
    -- <leader>ct is just an example; pick whatever you like
    vim.keymap.set("n", "<leader>ct", toggle_copilot, {
      desc = "Toggle GitHub Copilot",
      silent = true,
      noremap = true,
    })
  end,
}
