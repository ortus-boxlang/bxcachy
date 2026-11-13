-- Written by bxcachy (editor lazyvim). Every theme's colourscheme plugin is listed (lazy, not loaded) so `bxcachy theme set` never has to
-- clone anything while you work: the specs come from the theme files `bxcachy theme` keeps in ~/.config/bxcachy/nvim-themes/.
local dir = (os.getenv("BXCACHY_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/bxcachy/nvim-themes"
local specs = {}
for _, file in ipairs(vim.fn.glob(dir .. "/*.lua", false, true)) do
  local ok, theme = pcall(dofile, file)
  if ok and type(theme) == "table" then
    for _, spec in ipairs(theme) do
      if type(spec) == "table" and spec[1] ~= "LazyVim/LazyVim" then
        local lazy_spec = vim.deepcopy(spec)
        lazy_spec.lazy = true
        table.insert(specs, lazy_spec)
      end
    end
  end
end
return specs
