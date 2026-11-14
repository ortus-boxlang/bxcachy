-- Written by bxrig (editor lazyvim). Makes the editor show the terminal background: the background of these highlight groups is
-- cleared (their other attributes stay), at startup and again after every colourscheme change.
local groups = {
  "Normal", "NormalNC", "NormalFloat", "FloatBorder", "Pmenu", "Terminal", "EndOfBuffer", "FoldColumn", "Folded",
  "SignColumn", "LineNr", "CursorLineNr", "StatusLine", "StatusLineNC", "WhichKeyFloat",
  "TelescopeBorder", "TelescopeNormal", "TelescopePromptBorder", "TelescopePromptTitle",
  "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeVertSplit", "NeoTreeWinSeparator", "NeoTreeEndOfBuffer",
  "NvimTreeNormal", "NvimTreeVertSplit", "NvimTreeEndOfBuffer",
  "NotifyINFOBody", "NotifyERRORBody", "NotifyWARNBody", "NotifyTRACEBody", "NotifyDEBUGBody",
  "NotifyINFOTitle", "NotifyERRORTitle", "NotifyWARNTitle", "NotifyTRACETitle", "NotifyDEBUGTitle",
  "SnacksNormal", "SnacksNormalNC", "SnacksPicter", "SnacksPickerBorder",
}

local function make_transparent(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok then
    hl.bg = nil
    vim.api.nvim_set_hl(0, name, hl)
  end
end

local function apply()
  for _, name in ipairs(groups) do make_transparent(name) end
end

apply()
vim.api.nvim_create_autocmd("ColorScheme", { group = vim.api.nvim_create_augroup("bxrig_transparency", { clear = true }), callback = apply })
