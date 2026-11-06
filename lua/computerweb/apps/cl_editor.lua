--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Éditeur" (bloc-notes amélioré)
      * rechercher / remplacer, taille de police, police à chasse fixe
      * ligne / colonne, nombre de mots, insertion date et heure
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS
local OS = CW.OS

CW.Editor = CW.Editor or {}
local Ed = CW.Editor

Ed.Sizes = { 12, 14, 16, 18, 22, 28 }

---------------------------------------------------------------------------
-- Fonctions pures (testées hors jeu)
---------------------------------------------------------------------------
--- Remplace toutes les occurrences (texte brut, sensible à la casse). Renvoie texte, nombre.
function Ed.ReplaceAll(text, find, rep)
    text, find, rep = tostring(text or ""), tostring(find or ""), tostring(rep or "")
    if find == "" then return text, 0 end
    local out, i, n = {}, 1, 0
    while true do
        local a, b = text:find(find, i, true)
        if not a then break end
        out[#out + 1] = text:sub(i, a - 1)
        out[#out + 1] = rep
        i = b + 1
        n = n + 1
    end
    out[#out + 1] = text:sub(i)
    return table.concat(out), n
end

--- Positions (index 1) de toutes les occurrences de `find`.
function Ed.FindAll(text, find)
    local res = {}
    text, find = tostring(text or ""), tostring(find or "")
    if find == "" then return res end
    local i = 1
    while #res < 500 do
        local a, b = text:find(find, i, true)
        if not a then break end
        res[#res + 1] = a
        i = b + 1
    end
    return res
end

--- Ligne et colonne (1-based) d'une position de curseur (0 = avant le 1er caractère).
function Ed.LineCol(text, pos)
    text = tostring(text or "")
    pos = math.Clamp(tonumber(pos) or 0, 0, #text)
    local before = text:sub(1, pos)
    local _, nl = before:gsub("\n", "")
    local lastNl = before:match(".*()\n") or 0
    return nl + 1, pos - lastNl + 1
end

function Ed.LineOf(text, index)
    local before = tostring(text or ""):sub(1, math.max(index - 1, 0))
    local _, nl = before:gsub("\n", "")
    return nl + 1
end

function Ed.WordCount(text)
    local n = 0
    for _ in tostring(text or ""):gmatch("%S+") do n = n + 1 end
    return n
end

local fontMade = {}
local function editorFont(size, mono)
    local name = "CW.Editor" .. (mono and "M" or "P") .. size
    if not fontMade[name] or fontMade.scale ~= UI.Scale then
        if fontMade.scale ~= UI.Scale then fontMade = { scale = UI.Scale } end
        surface.CreateFont(name, {
            font = mono and "Courier New" or "Roboto", size = S(size), weight = 500, extended = true,
        })
        fontMade[name] = true
    end
    return name
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function openEditor(desktop, args)
    local win = UI.Window(desktop, {
        title = "Éditeur", icon = "editor", app = "editor",
        w = S(780), h = S(560), minW = S(560), minH = S(340),
    })
    local content = win:GetContent()

    local path = args.path
    local modified = false
    local entry, status, findPanel, findEntry, replEntry
    local sizeIdx = 3
    local mono = UI.T.mono
    local lastFind, matchIdx = nil, 0

    local function title()
        local name = path and FS.Basename(path) or "Sans titre"
        win:SetWinTitle((modified and "* " or "") .. name .. " - Éditeur")
    end
    local function setStatus(msg, bad) status.cwText, status.cwBad = msg, bad end

    local function writeTo(p, thenFn)
        local ok, err = FS.Write(p, entry:GetValue())
        if not ok then setStatus(err or "Erreur d'enregistrement", true) return end
        path, modified = p, false
        title()
        setStatus("Enregistré : " .. p)
        if thenFn then thenFn() end
    end

    local function saveAs(thenFn)
        Derma_StringRequest("Enregistrer sous", "Nom du fichier (dans Documents) :",
            path and FS.Basename(path) or "", function(txt)
                local name = FS.FileName(txt)
                if not name then setStatus("Nom invalide", true) return end
                local p = FS.Join("Documents", name)
                if FS.Exists(p) and p ~= path then
                    Derma_Query("« " .. name .. " » existe déjà. Le remplacer ?", "Confirmation",
                        "Remplacer", function() writeTo(p, thenFn) end, "Annuler")
                else
                    writeTo(p, thenFn)
                end
            end)
    end

    local function save(thenFn)
        if not path then saveAs(thenFn) return end
        writeTo(path, thenFn)
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
        Derma_Query("Les modifications non enregistrées seront perdues.", "Éditeur",
            "Enregistrer", function() save(fn) end, "Ne pas enregistrer", function() fn() end)
    end

    local function applyFont()
        if IsValid(entry) then entry:SetFont(editorFont(Ed.Sizes[sizeIdx], mono)) end
    end

    ---------------------------------------------------------------------
    -- Barre d'outils
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
        b:SetWide(wide or S(110))
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
    end, S(104))
    tbButton("Ouvrir", "open", function()
        confirmDiscard(function() desktop:OpenApp("files", { path = "Documents", pick = loadFile }) end)
    end, S(96))
    tbButton("Enregistrer", "save", function() save() end, S(124), "accent")
    tbButton("Sous...", "save", function() saveAs() end, S(88))

    local fontUp = tbButton("A+", nil, function()
        sizeIdx = math.min(sizeIdx + 1, #Ed.Sizes); applyFont()
    end, S(44))
    fontUp:SetTooltip("Agrandir le texte")
    local fontDown = tbButton("A-", nil, function()
        sizeIdx = math.max(sizeIdx - 1, 1); applyFont()
    end, S(44))
    fontDown:SetTooltip("Réduire le texte")
    local monoBtn = tbButton("Fixe", nil, function() mono = not mono; applyFont() end, S(64))
    monoBtn:SetTooltip("Police à chasse fixe")
    monoBtn.Think = function(self) self.cwKind = mono and "accent" or "flat" end

    local findBtn = tbButton("Chercher", "search", function()
        findPanel:SetVisible(not findPanel:IsVisible())
        findPanel:SetTall(findPanel:IsVisible() and S(84) or 0)
        content:InvalidateLayout()
        if findPanel:IsVisible() then findEntry:RequestFocus() end
    end, S(112))
    findBtn:SetTooltip("Rechercher / remplacer")

    ---------------------------------------------------------------------
    -- Rechercher / remplacer (replié par défaut)
    ---------------------------------------------------------------------
    findPanel = vgui.Create("DPanel", content)
    findPanel:Dock(TOP)
    findPanel:SetTall(0)
    findPanel:SetVisible(false)
    findPanel:DockPadding(S(6), S(6), S(6), S(6))
    findPanel.Paint = function(_, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panelHi.r, c.panelHi.g, c.panelHi.b, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local function frow(parent)
        local r = vgui.Create("DPanel", parent)
        r:Dock(TOP)
        r:SetTall(S(34))
        r:DockMargin(0, 0, 0, S(4))
        r.Paint = function() end
        return r
    end

    local function doFind(forward)
        local term = findEntry:GetValue()
        local text = entry:GetValue()
        local all = Ed.FindAll(text, term)
        if term == "" then setStatus("Saisissez un texte à chercher", true) return end
        if #all == 0 then setStatus("« " .. term .. " » : aucune occurrence", true) return end
        if lastFind ~= term then matchIdx = 0 end
        lastFind = term
        matchIdx = matchIdx + (forward and 1 or -1)
        if matchIdx > #all then matchIdx = 1 end
        if matchIdx < 1 then matchIdx = #all end
        local pos = all[matchIdx]
        if entry.SetCaretPos then entry:SetCaretPos(pos - 1) end
        setStatus(#all .. " occurrence(s) - n°" .. matchIdx .. " ligne " .. Ed.LineOf(text, pos))
    end

    local r1 = frow(findPanel)
    findEntry = UI.Entry(r1, "Rechercher")
    findEntry:Dock(FILL)
    local nextB = UI.Button(r1, "Suivant", nil, function() doFind(true) end)
    nextB:Dock(RIGHT)
    nextB:SetWide(S(96))
    nextB:DockMargin(S(6), 0, 0, 0)
    local prevB = UI.Button(r1, "Précédent", nil, function() doFind(false) end)
    prevB:Dock(RIGHT)
    prevB:SetWide(S(104))
    prevB:DockMargin(S(6), 0, 0, 0)
    findEntry.OnEnter = function() doFind(true) end

    local r2 = frow(findPanel)
    replEntry = UI.Entry(r2, "Remplacer par")
    replEntry:Dock(FILL)
    local allB = UI.Button(r2, "Tout remplacer", nil, function()
        local term = findEntry:GetValue()
        if term == "" then setStatus("Saisissez un texte à chercher", true) return end
        local new, n = Ed.ReplaceAll(entry:GetValue(), term, replEntry:GetValue())
        if n == 0 then setStatus("Aucune occurrence à remplacer", true) return end
        if #new > FS.MaxFileSize then setStatus("Le résultat dépasserait la taille maximale", true) return end
        entry:SetText(new)
        modified = true
        title()
        setStatus(n .. " remplacement(s) effectué(s)")
    end)
    allB:Dock(RIGHT)
    allB:SetWide(S(170))
    allB:DockMargin(S(6), 0, 0, 0)

    ---------------------------------------------------------------------
    -- Barre d'état
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
        if IsValid(entry) then
            local txt = entry:GetValue()
            local pos = entry.GetCaretPos and entry:GetCaretPos() or #txt
            local ln, col = Ed.LineCol(txt, pos)
            draw.SimpleText("Ln " .. ln .. ", Col " .. col .. "   |   " .. Ed.WordCount(txt) .. " mots   |   "
                .. #txt .. " / " .. FS.MaxFileSize, "CW.Small", w - S(12), h / 2, c.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    entry = UI.Entry(content, nil, true)
    entry:Dock(FILL)
    entry:DockMargin(S(6), S(6), S(6), S(6))
    applyFont()
    entry.OnChange = function(self)
        if not modified then modified = true; title() end
        if #self:GetValue() > FS.MaxFileSize then
            setStatus("Limite de taille atteinte : le texte sera refusé à l'enregistrement.", true)
        end
    end
    local baseKey = entry.OnKeyCodeTyped
    entry.OnKeyCodeTyped = function(self, code)
        if input.IsControlDown() then
            if code == KEY_S then save() return true end
            if code == KEY_F then findBtn:DoClick() return true end
            if code == KEY_T then
                self:SetText(self:GetValue() .. os.date("%d/%m/%Y %H:%M"))
                self:OnChange()
                return true
            end
        end
        if baseKey then return baseKey(self, code) end
    end

    ---------------------------------------------------------------------
    local baseClose = win.CloseWindow
    function win:CloseWindow()
        if modified and not self.cwDiscard then
            Derma_Query("Enregistrer les modifications avant de fermer ?", "Éditeur",
                "Enregistrer", function() save(function() baseClose(self) end) end,
                "Ne pas enregistrer", function() self.cwDiscard = true; baseClose(self) end,
                "Annuler", function() end)
            return
        end
        baseClose(self)
    end
    win.OnWindowClose = function(self)
        if modified and path and not self.cwDiscard then FS.Write(path, entry:GetValue()) end
    end
    win.OnAppArgs = function(_, a) if a and a.path then loadFile(a.path) end end

    if path then loadFile(path) else title() end
    entry:RequestFocus()
    return win
end

OS.RegisterApp("editor", {
    name = "Éditeur", icon = "editor", order = 21, single = false,
    open = openEditor,
})
