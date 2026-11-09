-- Omarchy-inspired bindings for Hyprland Lua configurations.
-- Copy these lines into your existing hyprland.lua AFTER `hl` is initialized.
-- Do not overwrite your existing hl.config({}) or startup hooks.
local omarchy_ipc = 'noctalia msg '
hl.bind('SUPER + Space', hl.dsp.exec_cmd(omarchy_ipc .. 'panel-toggle launcher'))
hl.bind('SUPER + Return', hl.dsp.exec_cmd('ghostty'))
hl.bind('SUPER + E', hl.dsp.exec_cmd('dolphin'))
hl.bind('SUPER + S', hl.dsp.exec_cmd(omarchy_ipc .. 'panel-toggle control-center'))
hl.bind('SUPER + comma', hl.dsp.exec_cmd(omarchy_ipc .. 'settings-toggle'))
hl.bind('SUPER + Escape', hl.dsp.exec_cmd(omarchy_ipc .. 'panel-toggle session'))
-- Window management and workspaces: keep your CachyOS Lua bindings unless
-- you have confirmed the correct dispatcher API for your installed version.
