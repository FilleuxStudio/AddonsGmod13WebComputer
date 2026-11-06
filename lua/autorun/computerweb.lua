--[[----------------------------------------------------------------------------
    ComputerWeb 2.1 - chargeur
    Auteur : FilleuxStudio (didifx60)
------------------------------------------------------------------------------]]

ComputerWeb = ComputerWeb or {}

local SHARED = {
    "computerweb/config.lua",
    "computerweb/sh_core.lua",
}

local SERVER_FILES = {
    "computerweb/sv_main.lua",
}

-- L'ordre compte : ui -> fs -> os -> applications
local CLIENT_FILES = {
    "computerweb/cl_ui.lua",
    "computerweb/cl_fs.lua",
    "computerweb/cl_shortcuts.lua",
    "computerweb/cl_os.lua",
    "computerweb/apps/cl_files.lua",
    "computerweb/apps/cl_notepad.lua",
    "computerweb/apps/cl_browser.lua",
    "computerweb/apps/cl_music.lua",
    "computerweb/apps/cl_editor.lua",
    "computerweb/apps/cl_calc.lua",
    "computerweb/apps/cl_mines.lua",
    "computerweb/apps/cl_paint.lua",
    "computerweb/apps/cl_netlab.lua",
    "computerweb/apps/cl_matrix.lua",
    "computerweb/apps/cl_terminal.lua",
    "computerweb/apps/cl_settings.lua",
    "computerweb/cl_screen_remote.lua",
    "computerweb/cl_radio_remote.lua",
}

if SERVER then
    for _, f in ipairs(SHARED) do AddCSLuaFile(f) end
    for _, f in ipairs(CLIENT_FILES) do AddCSLuaFile(f) end
end

for _, f in ipairs(SHARED) do include(f) end

if SERVER then
    for _, f in ipairs(SERVER_FILES) do include(f) end
else
    for _, f in ipairs(CLIENT_FILES) do include(f) end
end

if SERVER then
    MsgC(Color(80, 200, 255), "[ComputerWeb] ", color_white, "v" .. ComputerWeb.Version .. " chargé.\n")
end
