-- Written by bxrig (editor lazyvim). Rewritten by `bxrig editor refresh`; add your own plugins in other files.
return {
  -- no news popups on startup
  { "LazyVim/LazyVim", opts = { news = { lazyvim = false, neovim = false } } },
  -- no scroll animation
  { "folke/snacks.nvim", opts = { scroll = { enabled = false } } },
  -- let the status line show the terminal background: lualine's auto theme paints its middle sections a solid colour,
  -- so they are cleared on every theme it builds (it builds again on each colourscheme change)
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.theme = function()
        local theme = require("lualine.utils.loader").load_theme("auto")
        for _, mode in pairs(theme) do
          for _, section in ipairs({ "b", "c" }) do
            if mode[section] then mode[section].bg = "None" end
          end
        end
        return theme
      end
    end,
  },
}
