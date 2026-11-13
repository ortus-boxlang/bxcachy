-- Written by bxcachy (editor lazyvim). Applies a theme change live: `bxcachy theme set` rewrites the file lua/plugins/theme.lua links to,
-- this watches its folder and re-applies the colourscheme it names (no restart).
return {
  {
    name = "bxcachy-theme-reload",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    priority = 1000,
    config = function()
      local link = vim.fn.stdpath("config") .. "/lua/plugins/theme.lua"
      local target = vim.fn.resolve(link)
      if target == link or vim.fn.filereadable(target) == 0 then return end

      local function colorscheme()
        local ok, spec = pcall(dofile, link)
        if not ok or type(spec) ~= "table" then return nil end
        for _, entry in ipairs(spec) do
          if entry[1] == "LazyVim/LazyVim" and entry.opts and entry.opts.colorscheme then return entry.opts.colorscheme end
        end
      end

      local function apply()
        local name = colorscheme()
        if not name then return end
        vim.schedule(function()
          vim.cmd("highlight clear")
          if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
          pcall(vim.cmd.colorscheme, name)
        end)
      end

      local watcher = (vim.uv or vim.loop).new_fs_event()
      local pending = false
      watcher:start(vim.fn.fnamemodify(target, ":h"), {}, function()
        if pending then return end
        pending = true
        vim.defer_fn(function()
          pending = false
          apply()
        end, 150)
      end)
    end,
  },
}
