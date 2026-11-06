--[[----------------------------------------------------------------------------
    ComputerWeb - Raccourcis du bureau (client)
      * un raccourci = application, site web ou fichier
      * enregistré sur le PC du joueur (data/computerweb/shortcuts_<steamid>.txt)
      * toutes les données lues sont revalidées (jamais de confiance au fichier)
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS

CW.Shortcuts = CW.Shortcuts or {}
local SC = CW.Shortcuts

SC.Max = 40
SC.List = SC.List or {}

-- Icônes proposées pour un raccourci
SC.Icons = {
    "browser", "files", "notepad", "editor", "calc", "mines", "paint", "music",
    "terminal", "settings", "folder", "file", "home", "search", "save", "power",
}
local ICONSET = {}
for _, n in ipairs(SC.Icons) do ICONSET[n] = true end
SC.IconSet = ICONSET

local DEFAULT_ICON = { app = "settings", url = "browser", file = "file" }

---------------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------------
local function cleanLabel(s)
    s = tostring(s or ""):gsub("%c", "")
    s = CW.Trim(s)
    if utf8 and utf8.len and utf8.offset then
        local n = utf8.len(s)
        if n and n > 24 then s = s:sub(1, utf8.offset(s, 25) - 1) end
        if not n then s = s:sub(1, 24) end
    else
        s = s:sub(1, 24)
    end
    return s
end

--- Renvoie un raccourci propre ou nil, raison.
function SC.Sanitize(e)
    if type(e) ~= "table" then return nil, "Raccourci invalide" end
    local kind = e.type
    if kind ~= "app" and kind ~= "url" and kind ~= "file" then return nil, "Type de raccourci inconnu" end
    local out = { type = kind }

    if kind == "app" then
        local id = tostring(e.app or "")
        if #id > 32 or not id:match("^[%w_]+$") then return nil, "Application invalide" end
        out.app = id
    elseif kind == "url" then
        local url = CW.Trim(e.url or "")
        if url == "" then return nil, "Adresse vide" end
        if url:find("%c") then return nil, "Adresse invalide" end
        if not url:find("^%a[%w+.-]*:") then url = "https://" .. url end
        local ok, why = CW.CheckURL(url)
        if not ok then return nil, why or "Adresse refusée" end
        out.url = url
    else
        local p = FS.Clean(e.path)
        if not p or p == "" then return nil, "Chemin de fichier invalide" end
        out.path = p
    end

    local label = cleanLabel(e.label)
    if label == "" then
        if kind == "app" then
            local def = CW.OS and CW.OS.Apps and CW.OS.Apps[out.app]
            label = def and def.name or out.app
        elseif kind == "url" then
            local _, host = CW.ParseURL(out.url)
            label = host or "Site web"
        else
            label = FS.Basename(out.path)
        end
        label = cleanLabel(label)
    end
    out.label = label

    local icon = tostring(e.icon or "")
    if not ICONSET[icon] then
        icon = DEFAULT_ICON[kind]
        if kind == "app" then
            local def = CW.OS and CW.OS.Apps and CW.OS.Apps[out.app]
            if def and ICONSET[def.icon] then icon = def.icon end
        end
    end
    out.icon = icon
    return out
end

local function target(e)
    return e.app or e.url or e.path or ""
end

---------------------------------------------------------------------------
-- Enregistrement (une ligne par raccourci : type<TAB>icône<TAB>cible<TAB>nom)
---------------------------------------------------------------------------
local function filePath()
    return "computerweb/shortcuts_" .. FS.UserID() .. ".txt"
end

function SC.Serialize(list)
    local lines = {}
    for _, e in ipairs(list) do
        lines[#lines + 1] = table.concat({ e.type, e.icon, target(e), e.label }, "\t")
    end
    return table.concat(lines, "\n")
end

function SC.Parse(text)
    local list = {}
    for line in tostring(text or ""):gmatch("[^\n]+") do
        if #list >= SC.Max then break end
        local kind, icon, tgt, label = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if kind then
            local e = { type = kind, icon = icon, label = label }
            if kind == "app" then e.app = tgt elseif kind == "url" then e.url = tgt else e.path = tgt end
            local clean = SC.Sanitize(e)
            if clean then list[#list + 1] = clean end
        end
    end
    return list
end

function SC.Save()
    file.CreateDir("computerweb")
    file.Write(filePath(), SC.Serialize(SC.List))
end

function SC.Load()
    local txt = file.Read(filePath(), "DATA")
    SC.List = txt and SC.Parse(txt) or {}
    return SC.List
end

---------------------------------------------------------------------------
-- Gestion
---------------------------------------------------------------------------
function SC.Add(e)
    if #SC.List >= SC.Max then return false, "Trop de raccourcis (" .. SC.Max .. " maximum)" end
    local clean, err = SC.Sanitize(e)
    if not clean then return false, err end
    SC.List[#SC.List + 1] = clean
    SC.Save()
    return true
end

function SC.Remove(index)
    if not SC.List[index] then return false end
    table.remove(SC.List, index)
    SC.Save()
    return true
end

--- Ouvre un raccourci dans le bureau `desktop`.
function SC.Open(desktop, e)
    if not e then return end
    if e.type == "app" then
        local def = CW.OS.Apps[e.app]
        if not def or not CW.OS.AppAllowed(def, desktop.Theme and desktop.Theme.id or UI.T.id) then
            desktop:Toast("Application introuvable sur ce système : " .. e.app)
            return
        end
        return desktop:OpenApp(e.app)
    elseif e.type == "url" then
        return desktop:OpenApp("browser", { input = e.url })
    elseif e.type == "file" then
        if not FS.Exists(e.path) then desktop:Toast("Fichier introuvable : " .. e.path) return end
        local app = CW.OS.Apps.editor and "editor" or "notepad"
        return desktop:OpenApp(app, { path = e.path })
    end
end

---------------------------------------------------------------------------
-- Boîte de dialogue « Nouveau raccourci »
---------------------------------------------------------------------------
function SC.OpenDialog(desktop, preset)
    preset = preset or {}
    local OS = CW.OS
    local win = UI.Window(desktop, {
        title = "Nouveau raccourci", icon = "files",
        w = S(560), h = S(520), minW = S(520), minH = S(480), noMax = true, noResize = true,
    })
    local content = win:GetContent()

    local mode = preset.type or "app"
    local pickedApp = preset.app
    local iconName = preset.icon
    local labelEntry, urlEntry, pathEntry
    local area

    local function section(text)
        local l = UI.Label(content, text, "CW.Bold")
        l:Dock(TOP)
        l:SetTall(S(26))
        l:DockMargin(S(12), S(6), S(12), 0)
        return l
    end

    -- Boutons du bas (créés d'abord pour réserver leur place)
    local bottom = vgui.Create("DPanel", content)
    bottom:Dock(BOTTOM)
    bottom:SetTall(S(54))
    bottom:DockPadding(S(10), S(8), S(10), S(8))
    bottom.Paint = function() end

    local function create()
        local e = { type = mode, label = IsValid(labelEntry) and labelEntry:GetValue() or "", icon = iconName }
        if mode == "app" then
            e.app = pickedApp
        elseif mode == "url" then
            e.url = IsValid(urlEntry) and urlEntry:GetValue() or ""
        else
            e.path = IsValid(pathEntry) and pathEntry:GetValue() or ""
        end
        local ok, err = SC.Add(e)
        if not ok then desktop:Toast(err or "Raccourci invalide") return end
        win:CloseWindow()
        if desktop.BuildDesktopIcons then desktop:BuildDesktopIcons() end
        if desktop.OnShortcutsChanged then pcall(desktop.OnShortcutsChanged) end
        desktop:Toast("Raccourci créé sur le bureau")
    end

    local okBtn = UI.Button(bottom, "Créer le raccourci", "save", create, "accent")
    okBtn:Dock(RIGHT)
    okBtn:SetWide(S(210))
    local cancel = UI.Button(bottom, "Annuler", nil, function() win:CloseWindow() end)
    cancel:Dock(RIGHT)
    cancel:SetWide(S(110))
    cancel:DockMargin(0, 0, S(8), 0)

    -- Type
    section("Type de raccourci")
    local modes = vgui.Create("DPanel", content)
    modes:Dock(TOP)
    modes:SetTall(S(42))
    modes:DockMargin(S(12), 0, S(12), 0)
    modes.Paint = function() end

    -- Nom
    local rebuildArea
    local modeButtons = {}
    for _, m in ipairs({ { "app", "Application" }, { "url", "Site web" }, { "file", "Fichier" } }) do
        local b = UI.Button(modes, m[2], nil, function() mode = m[1]; rebuildArea() end)
        b:Dock(LEFT)
        b:SetWide(S(150))
        b:DockMargin(0, S(4), S(8), S(4))
        b.Think = function(self) self.cwKind = (mode == m[1]) and "accent" or "flat" end
        modeButtons[#modeButtons + 1] = b
    end

    section("Nom affiché (facultatif)")
    labelEntry = UI.Entry(content, "Ex. Mon site")
    labelEntry:Dock(TOP)
    labelEntry:SetTall(S(32))
    labelEntry:DockMargin(S(12), 0, S(12), 0)
    if preset.label then labelEntry:SetText(preset.label) end

    section("Cible")
    area = vgui.Create("DPanel", content)
    area:Dock(TOP)
    area:SetTall(S(120))
    area:DockMargin(S(12), 0, S(12), 0)
    area.Paint = function() end

    function rebuildArea()
        area:Clear()
        urlEntry, pathEntry = nil, nil
        if mode == "app" then
            local sc = vgui.Create("DScrollPanel", area)
            sc:Dock(FILL)
            for _, id in ipairs(OS.VisibleApps(UI.T.id)) do
                local def = OS.Apps[id]
                local b = UI.Button(sc, def.name, def.icon, function()
                    pickedApp = id
                    if not (preset.icon) then iconName = ICONSET[def.icon] and def.icon or iconName end
                end)
                b:Dock(TOP)
                b:SetTall(S(30))
                b:DockMargin(0, 0, 0, S(3))
                b.Think = function(self) self.cwKind = (pickedApp == id) and "accent" or "flat" end
            end
        elseif mode == "url" then
            urlEntry = UI.Entry(area, "https://fr.wikipedia.org")
            urlEntry:Dock(TOP)
            urlEntry:SetTall(S(32))
            if preset.url then urlEntry:SetText(preset.url) end
            local hint = UI.Label(area, "Le site s'ouvrira dans le navigateur (soumis aux règles de sécurité du serveur).", "CW.Small", "dim")
            hint:Dock(TOP)
            hint:SetTall(S(40))
            hint:SetWrap(true)
            hint:DockMargin(0, S(6), 0, 0)
        else
            pathEntry = UI.Entry(area, "Documents/notes.txt")
            pathEntry:Dock(TOP)
            pathEntry:SetTall(S(32))
            if preset.path then pathEntry:SetText(preset.path) end
            local hint = UI.Label(area, "Chemin d'un fichier de vos Documents (voir l'application Fichiers).", "CW.Small", "dim")
            hint:Dock(TOP)
            hint:SetTall(S(40))
            hint:SetWrap(true)
            hint:DockMargin(0, S(6), 0, 0)
        end
    end
    rebuildArea()

    -- Icône
    section("Icône")
    local grid = vgui.Create("DIconLayout", content)
    grid:Dock(TOP)
    grid:SetTall(S(96))
    grid:DockMargin(S(12), 0, S(12), 0)
    grid:SetSpaceX(S(6))
    grid:SetSpaceY(S(6))
    for _, name in ipairs(SC.Icons) do
        local b = vgui.Create("DButton", grid)
        b:SetText("")
        b:SetSize(S(40), S(40))
        b.Paint = function(self, w, h)
            local c = UI.T.c
            local sel = (iconName == name)
            if UI.T.bevel then
                UI.Bevel(0, 0, w, h, not sel, c.panel)
            else
                draw.RoundedBox(S(6), 0, 0, w, h, sel and c.accent or c.panel)
            end
            local isz = S(28)
            local tint = UI.ColorIcons[name] and color_white or c.windowText
            UI.DrawIcon(name, (w - isz) / 2, (h - isz) / 2, isz, isz, tint)
        end
        b.DoClick = function() iconName = name end
    end

    return win
end

