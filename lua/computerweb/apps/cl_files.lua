--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Fichiers" (explorateur)
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS
local OS = CW.OS

local function formatDate(t)
    if not t or t <= 0 then return "" end
    return os.date("%d/%m/%Y %H:%M", t)
end

local PLACES = {
    { "Bureau",    "Bureau"    },
    { "Documents", "Documents" },
    { "Musique",   "Musique"   },
    { "Tout",      ""          },
}

local function openFiles(desktop, args)
    local pick = args.pick
    local win = UI.Window(desktop, {
        title = pick and "Ouvrir un fichier" or "Fichiers", icon = "files", app = "files",
        w = S(800), h = S(500), minW = S(560), minH = S(320),
    })
    local content = win:GetContent()

    local cwd = FS.Clean(args.path or "Documents") or ""
    if not FS.IsDir(cwd) then cwd = "" end
    local selected  -- { name=, isDir=, path= }
    local rows = {}
    local list, status, pathBar

    ---------------------------------------------------------------------
    local function refresh() end

    local function toast(msg) desktop:Toast(msg) end

    local function selectedPath()
        return selected and selected.path or nil
    end

    local function openEntry(entry)
        if entry.isDir then
            cwd = entry.path
            selected = nil
            refresh()
        elseif pick then
            pick(entry.path)
            win:CloseWindow()
        else
            desktop:OpenApp("notepad", { path = entry.path })
        end
    end

    ---------------------------------------------------------------------
    -- Barre d'outils
    ---------------------------------------------------------------------
    local tb = vgui.Create("DPanel", content)
    tb:Dock(TOP)
    tb:SetTall(S(44))
    tb:DockPadding(S(6), S(6), S(6), S(6))
    tb.Paint = function(_, w, h)
        surface.SetDrawColor(UI.T.c.panel.r, UI.T.c.panel.g, UI.T.c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local function tbButton(text, icon, fn, wide, kind)
        local b = UI.Button(tb, text, icon, fn, kind)
        b:Dock(LEFT)
        b:SetWide(wide or S(120))
        b:DockMargin(0, 0, S(6), 0)
        return b
    end

    tbButton("Dossier parent", "up", function()
        cwd = FS.Parent(cwd)
        selected = nil
        refresh()
    end, S(132))

    if not pick then
        tbButton("Nouveau dossier", "newfolder", function()
            Derma_StringRequest("Nouveau dossier", "Nom du dossier :", "", function(txt)
                local name = FS.SanitizeName(txt)
                if not name then toast("Nom invalide") return end
                local ok, err = FS.MkDir(FS.Join(cwd, name))
                if not ok then toast(err or "Erreur") end
                refresh()
            end)
        end, S(150))

        tbButton("Nouveau fichier", "newfile", function()
            Derma_StringRequest("Nouveau fichier", "Nom du fichier texte :", "", function(txt)
                local name = FS.FileName(txt)
                if not name then toast("Nom invalide") return end
                local path = FS.Join(cwd, name)
                if FS.Exists(path) then toast("Ce nom existe déjà") return end
                local ok, err = FS.Write(path, "")
                if not ok then toast(err or "Erreur") return end
                refresh()
                desktop:OpenApp("notepad", { path = path })
            end)
        end, S(140))

        tbButton("Renommer", "rename", function()
            if not selected then toast("Sélectionnez un élément") return end
            local old = selected
            Derma_StringRequest("Renommer", "Nouveau nom :", old.name, function(txt)
                local name = old.isDir and FS.SanitizeName(txt) or FS.FileName(txt)
                if not name then toast("Nom invalide") return end
                local ok, err = FS.Rename(old.path, FS.Join(FS.Parent(old.path), name))
                if not ok then toast(err or "Erreur") end
                selected = nil
                refresh()
            end)
        end, S(110))

        tbButton("Supprimer", "trash", function()
            if not selected then toast("Sélectionnez un élément") return end
            local old = selected
            Derma_Query("Supprimer « " .. old.name .. " » ?" .. (old.isDir and "\nTout son contenu sera perdu." or ""),
                "Confirmation", "Supprimer", function()
                    local ok, err = FS.Delete(old.path)
                    if not ok then toast(err or "Erreur") end
                    selected = nil
                    refresh()
                end, "Annuler")
        end, S(112), "danger")
    end

    ---------------------------------------------------------------------
    -- Raccourcis à gauche
    ---------------------------------------------------------------------
    local side = vgui.Create("DPanel", content)
    side:Dock(LEFT)
    side:SetWide(S(140))
    side:DockPadding(S(8), S(8), S(8), S(8))
    side.Paint = function(_, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(w - 1, 0, 1, h)
    end
    for _, p in ipairs(PLACES) do
        local b = UI.Button(side, p[1], "folder", function()
            if p[2] ~= "" and not FS.IsDir(p[2]) then FS.MkDir(p[2]) end
            cwd = p[2]
            selected = nil
            refresh()
        end, "ghost")
        b:Dock(TOP)
        b:SetTall(S(34))
        b:DockMargin(0, 0, 0, S(4))
    end

    ---------------------------------------------------------------------
    -- Chemin + état
    ---------------------------------------------------------------------
    pathBar = vgui.Create("DPanel", content)
    pathBar:Dock(TOP)
    pathBar:SetTall(S(30))
    pathBar.Paint = function(_, w, h)
        local c = UI.T.c
        local shown = "Mon disque" .. (cwd ~= "" and ("  ›  " .. cwd:gsub("/", "  ›  ")) or "")
        draw.SimpleText(shown, UI.T.mono and "CW.Mono" or "CW.Body", S(12), h / 2, c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(0, h - 1, w, 1)
    end

    status = vgui.Create("DPanel", content)
    status:Dock(BOTTOM)
    status:SetTall(S(26))
    status.cwText = ""
    status.Paint = function(self, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(0, 0, w, 1)
        draw.SimpleText(self.cwText, "CW.Small", S(12), h / 2, c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    ---------------------------------------------------------------------
    -- Liste
    ---------------------------------------------------------------------
    list = vgui.Create("DScrollPanel", content)
    list:Dock(FILL)
    list:DockMargin(S(4), S(4), S(4), S(4))
    list:GetVBar():SetWide(S(8))
    list:GetVBar().Paint = function() end
    list:GetVBar().btnUp.Paint = function() end
    list:GetVBar().btnDown.Paint = function() end
    list:GetVBar().btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(S(4), 0, 0, w, h, UI.Alpha(UI.T.c.dim, 140))
    end

    local function addRow(entry)
        local row = vgui.Create("DButton", list)
        row:SetText("")
        row:Dock(TOP)
        row:SetTall(S(34))
        row:DockMargin(0, 0, 0, S(2))
        row.cwHover = 0
        row.Paint = function(self, w, h)
            local c = UI.T.c
            self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
            if selected and selected.path == entry.path then
                draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, UI.Alpha(c.accent, 70))
            elseif self.cwHover > 0.01 then
                draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, UI.Alpha(c.accent, math.floor(35 * self.cwHover)))
            end
            local isz = S(22)
            UI.DrawIcon(entry.isDir and "folder" or "file", S(10), (h - isz) / 2, isz, isz)
            local font = UI.T.mono and "CW.Mono" or "CW.Body"
            draw.SimpleText(entry.name, font, S(42), h / 2, c.windowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if not entry.isDir then
                draw.SimpleText(FS.FormatSize(entry.size), "CW.Small", w - S(180), h / 2, c.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                draw.SimpleText(formatDate(entry.time), "CW.Small", w - S(12), h / 2, c.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        row.DoClick = function(self)
            local now = SysTime()
            if selected and selected.path == entry.path and self.cwLast and now - self.cwLast < 0.5 then
                openEntry(entry)
                return
            end
            selected = entry
            self.cwLast = now
        end
        row.DoRightClick = function()
            selected = entry
            local m = DermaMenu()
            m:AddOption("Ouvrir", function() openEntry(entry) end):SetIcon("icon16/folder_go.png")
            m:Open()
        end
        rows[#rows + 1] = row
    end

    function refresh()
        if not IsValid(list) then return end
        list:Clear()
        rows = {}
        local res, err = FS.List(cwd)
        if not res then
            cwd = ""
            res = FS.List("") or { dirs = {}, files = {} }
            if err then toast(err) end
        end

        for _, d in ipairs(res.dirs) do
            addRow({ name = d, isDir = true, path = FS.Join(cwd, d) })
        end
        for _, f in ipairs(res.files) do
            addRow({ name = f.name, isDir = false, path = FS.Join(cwd, f.name), size = f.size, time = f.time })
        end

        if #rows == 0 then
            local empty = vgui.Create("DLabel", list)
            empty:Dock(TOP)
            empty:SetTall(S(80))
            empty:SetFont("CW.Body")
            empty:SetTextColor(UI.T.c.dim)
            empty:SetContentAlignment(5)
            empty:SetText("Ce dossier est vide.")
        end
        status.cwText = #res.dirs .. " dossier(s), " .. #res.files .. " fichier(s)" .. (pick and "  -  double-clic pour ouvrir" or "")
    end

    win.OnAppArgs = function(self, a)
        if a and a.path then cwd = FS.Clean(a.path) or cwd; selected = nil; refresh() end
    end

    refresh()
    return win
end

OS.RegisterApp("files", {
    name = "Fichiers", icon = "files", order = 10, single = false,
    open = openFiles,
})
