return {
  -- Add the vscode.nvim plugin
  {
    "Mofiqul/vscode.nvim",
    priority = 1000, -- Ensure it loads before other plugins
    config = function()
      -- Optional: VS Code specific configuration
      require("vscode").setup({
        style = "dark", -- Options: 'dark', 'light'
        transparent = false, -- Set to true if you want a transparent background
        italic_comments = true,
        disable_nvimtree_bg = true, -- Make NvimTree background same as editor
      })

      -- Activate the theme
      vim.cmd.colorscheme("vscode")
    end,
  },
}
