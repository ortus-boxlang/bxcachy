-- Written by bxrig (editor lazyvim). Loaded from options.lua. Rewritten by `bxrig editor refresh`; keep your own changes in options.lua.
vim.opt.relativenumber = false
vim.g.autoformat = false

-- Over SSH, yank and paste through the terminal (OSC 52, :help clipboard-osc52). Inside tmux add
--   set -as terminal-features ",*:clipboard"
-- to your tmux.conf so tmux passes it on.
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end
