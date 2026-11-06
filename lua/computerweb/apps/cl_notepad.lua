--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Bloc-notes"
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS
local OS = CW.OS

local function openNotepad(desktop, args)
    local win = UI.Window(desktop, {
        title = "Bloc-notes", icon = "notepad", app = "notepad",
        w = S(680), h = S(480), minW = S(420), minH = S(280),
    })
    local content = win:GetContent()

    local path = args.path          -- chemin virtuel du fichier ouvert (ou nil)
    local modified = false
    local entry, status

    local function title()
        local name = path and FS.Basename(path) or "Sans titre"
        win:SetWinTitle((modified and "● " or "") .. name .. " - Bloc-notes")
    end

    local function setStatus(msg, bad)
        status.cwText, status.cwBad = msg, bad
    end

    local function save(thenFn)
        if not path then
            Derma_StringRequest("Enregistrer sous", "Nom du fichier (dans Documents) :", "", function(txt)
                local name = FS.FileName(txt)
                if not name then setStatus("Nom invalide", true) return end
                local p = FS.Join("Documents", name)
                local function doSave()
                    local ok, err = FS.Write(p, entry:GetValue())
                    if not ok then setStatus(err or "Erreur", true) return end
                    path, modified = p, false
                    title()
                    setStatus("Enregistré : " .. p)
                    if thenFn then thenFn() end
                end
                if FS.Exists(p) then
                    Derma_Query("« " .. name .. " » existe déjà. Le remplacer ?", "Confirmation", "Remplacer", doSave, "Annuler")
                else
                    doSave()
                end
            end)
            return
        end
        local ok, err = FS.Write(path, entry:GetValue())
        if not ok then setStatus(err or "Erreur", true) return end
        modified = false
        title()
        setStatus("Enregistré : " .. path)
        if thenFn then thenFn() end
    end

    local function loadFile(p)
        local text, err = FS.Read(p)
        if not text then setStatus(err or "Lecture impossible", true) return end
        entry:SetText(text)
        path, modified = p, false
        title()
        setStatus("Ouvert : " .. p)
    end

    local function confirmDiscard(fn)
        if not modified then fn() return end
        Derma_Query("Les modifications non enregistrées seront perdues.", "Bloc-notes",
            "Enregistrer", function() save(fn) end,
            "Ne pas enregistrer", function() fn() end)
    end

    ---------------------------------------------------------------------
    local tb = vgui.Create("DPanel", content)
    tb:Dock(TOP)
    tb:SetTall(S(44))
    tb:DockPadding(S(6), S(6), S(6), S(6))
    tb.Paint = function(_, w, h)
        local c = UI.T.c.panel
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local function tbButton(text, icon, fn, wide, kind)
        local b = UI.Button(tb, text, icon, fn, kind)
        b:Dock(LEFT)
        b:SetWide(wide or S(120))
        b:DockMargin(0, 0, S(6), 0)
        return b
    end

    tbButton("Nouveau", "newfile", function()
        confirmDiscard(function()
            entry:SetText("")
            path, modified = nil, false
            title()
            setStatus("Nouveau document")
        end)
    end, S(112))

    tbButton("Ouvrir", "open", function()
        confirmDiscard(function()
            desktop:OpenApp("files", { path = "Documents", pick = loadFile })
        end)
    end, S(104))

    tbButton("Enregistrer", "save", function() save() end, S(132), "accent")

    tbButton("Enregistrer sous", "save", function()
        local old = path
        path = nil
        Derma_StringRequest("Enregistrer sous", "Nom du fichier (dans Documents) :",
            old and FS.Basename(old) or "", function(txt)
                path = old
                local name = FS.FileName(txt)
                if not name then setStatus("Nom invalide", true) return end
                local p = FS.Join("Documents", name)
                local ok, err = FS.Write(p, entry:GetValue())
                if not ok then setStatus(err or "Erreur", true) return end
                path, modified = p, false
                title()
                setStatus("Enregistré : " .. p)
            end, function() path = old end)
    end, S(168))

    ---------------------------------------------------------------------
    status = vgui.Create("DPanel", content)
    status:Dock(BOTTOM)
    status:SetTall(S(26))
    status.cwText = "Prêt  -  Ctrl+S pour enregistrer"
    status.Paint = function(self, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(0, 0, w, 1)
        draw.SimpleText(self.cwText, "CW.Small", S(12), h / 2, self.cwBad and c.danger or c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local len = IsValid(entry) and #entry:GetValue() or 0
        draw.SimpleText(len .. " / " .. FS.MaxFileSize .. " car.", "CW.Small", w - S(12), h / 2, c.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    entry = UI.Entry(content, nil, true)
    entry:Dock(FILL)
    entry:DockMargin(S(6), S(6), S(6), S(6))
    entry:SetFont(UI.T.mono and "CW.Mono" or "CW.Body")
    entry.OnChange = function(self)
        if not modified then
            modified = true
            title()
        end
        if #self:GetValue() > FS.MaxFileSize then
            setStatus("Limite de taille atteinte : le texte sera refusé à l'enregistrement.", true)
        end
    end

    local baseKey = entry.OnKeyCodeTyped
    entry.OnKeyCodeTyped = function(self, code)
        if code == KEY_S and input.IsControlDown() then
            save()
            return true
        end
        if baseKey then return baseKey(self, code) end
    end

    ---------------------------------------------------------------------
    -- Fermeture : demande si modifié ; sauvegarde silencieuse à l'extinction
    ---------------------------------------------------------------------
    local baseClose = win.CloseWindow
    function win:CloseWindow()
        if modified and not self.cwDiscard then
            Derma_Query("Enregistrer les modifications avant de fermer ?", "Bloc-notes",
                "Enregistrer", function() save(function() baseClose(self) end) end,
                "Ne pas enregistrer", function() self.cwDiscard = true; baseClose(self) end,
                "Annuler", function() end)
            return
        end
        baseClose(self)
    end

    win.OnWindowClose = function(self)
        if modified and path and not self.cwDiscard then
            FS.Write(path, entry:GetValue())
        end
    end

    win.OnAppArgs = function(_, a)
        if a and a.path then loadFile(a.path) end
    end

    if path then loadFile(path) else title() end
    entry:RequestFocus()
    return win
end

OS.RegisterApp("notepad", {
    name = "Bloc-notes", icon = "notepad", order = 20, single = false,
    open = openNotepad,
})
