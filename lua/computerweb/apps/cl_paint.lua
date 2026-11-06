--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Dessin"
      * crayon, gomme, 12 couleurs, 4 épaisseurs, annuler, tout effacer
      * enregistre dans Documents sous forme de fichier texte (rouvrable depuis Fichiers)
      * coordonnées normalisées 0..1000 : le dessin s'adapte à la taille de la fenêtre
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS
local OS = CW.OS

CW.Paint = CW.Paint or {}
local P = CW.Paint

P.MaxStrokes = 300
P.MaxPoints = 6000
P.Header = "CWPAINT1"

P.Colors = {
    Color(0, 0, 0), Color(110, 110, 110), Color(255, 255, 255), Color(220, 40, 40),
    Color(250, 140, 30), Color(250, 214, 40), Color(60, 180, 75), Color(30, 190, 190),
    Color(40, 110, 230), Color(120, 70, 200), Color(235, 90, 170), Color(130, 80, 40),
}
P.Sizes = { 2, 5, 10, 18 }

---------------------------------------------------------------------------
-- Sérialisation (pure)
---------------------------------------------------------------------------
--- strokes = { { r=, g=, b=, size=, pts = {x1, y1, x2, y2, ...} } }
function P.Serialize(strokes)
    local lines = { P.Header }
    for _, st in ipairs(strokes) do
        local parts = { st.r, st.g, st.b, st.size }
        for _, v in ipairs(st.pts) do parts[#parts + 1] = v end
        lines[#lines + 1] = table.concat(parts, " ")
    end
    return table.concat(lines, "\n")
end

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

--- Relit un dessin en revalidant tout. Renvoie strokes ou nil, erreur.
function P.Parse(text)
    text = tostring(text or "")
    local first = text:match("^[^\n]*")
    if first ~= P.Header then return nil, "Ce fichier n'est pas un dessin" end
    local strokes, total = {}, 0
    for line in text:gmatch("[^\n]+") do
        if line ~= P.Header then
            if #strokes >= P.MaxStrokes then break end
            local nums = {}
            for tok in line:gmatch("%-?%d+") do
                nums[#nums + 1] = tonumber(tok)
                if #nums > 4 + P.MaxPoints * 2 then break end
            end
            if #nums >= 6 and (#nums - 4) % 2 == 0 then
                local st = {
                    r = clamp(nums[1], 0, 255), g = clamp(nums[2], 0, 255), b = clamp(nums[3], 0, 255),
                    size = clamp(nums[4], 1, 30), pts = {},
                }
                for i = 5, #nums do st.pts[#st.pts + 1] = clamp(nums[i], 0, 1000) end
                total = total + #st.pts / 2
                if total > P.MaxPoints then break end
                strokes[#strokes + 1] = st
            end
        end
    end
    return strokes
end

function P.PointCount(strokes)
    local n = 0
    for _, st in ipairs(strokes) do n = n + #st.pts / 2 end
    return n
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function openPaint(desktop, args)
    local win = UI.Window(desktop, {
        title = "Dessin", icon = "paint", app = "paint",
        w = S(760), h = S(560), minW = S(520), minH = S(380),
    })
    local content = win:GetContent()

    local strokes = {}
    local colorIdx, sizeIdx = 1, 2
    local erasing = false
    local current
    local path
    local canvas

    local function setTitle() win:SetWinTitle((path and FS.Basename(path) or "Sans titre") .. " - Dessin") end

    ---------------------------------------------------------------------
    -- Barre d'outils
    ---------------------------------------------------------------------
    local tb = vgui.Create("DPanel", content)
    tb:Dock(TOP)
    tb:SetTall(S(48))
    tb:DockPadding(S(6), S(6), S(6), S(6))
    tb.Paint = function(_, w, h)
        local c = UI.T.c.panel
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local function tbButton(text, icon, fn, wide, kind)
        local b = UI.Button(tb, text, icon, fn, kind)
        b:Dock(LEFT)
        b:SetWide(wide)
        b:DockMargin(0, 0, S(6), 0)
        return b
    end

    tbButton("Ouvrir", "open", function()
        desktop:OpenApp("files", { path = "Documents", pick = function(p)
            local text, err = FS.Read(p)
            if not text then desktop:Toast(err or "Lecture impossible") return end
            local parsed, perr = P.Parse(text)
            if not parsed then desktop:Toast(perr) return end
            strokes, path = parsed, p
            setTitle()
        end })
    end, S(100))

    tbButton("Enregistrer", "save", function()
        Derma_StringRequest("Enregistrer le dessin", "Nom du fichier (dans Documents) :",
            path and FS.Basename(path) or "dessin", function(txt)
                local name = FS.FileName(txt)
                if not name then desktop:Toast("Nom invalide") return end
                local p = FS.Join("Documents", name)
                local ok, err = FS.Write(p, P.Serialize(strokes))
                if not ok then desktop:Toast(err or "Erreur d'enregistrement") return end
                path = p
                setTitle()
                desktop:Toast("Dessin enregistré : " .. p)
            end)
    end, S(132), "accent")

    tbButton("Annuler", "back", function() strokes[#strokes] = nil end, S(104))
    tbButton("Effacer", "trash", function() strokes, path = {}, nil; setTitle() end, S(100))

    local eraser = tbButton("Gomme", nil, function() erasing = not erasing end, S(84))
    eraser.Think = function(self) self.cwKind = erasing and "accent" or "flat" end

    ---------------------------------------------------------------------
    -- Palette (à gauche)
    ---------------------------------------------------------------------
    local side = vgui.Create("DPanel", content)
    side:Dock(LEFT)
    side:SetWide(S(96))
    side:DockPadding(S(6), S(6), S(6), S(6))
    side.Paint = function(_, w, h)
        local c = UI.T.c.panel
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local pal = vgui.Create("DIconLayout", side)
    pal:Dock(TOP)
    pal:SetTall(S(150))
    pal:SetSpaceX(S(4))
    pal:SetSpaceY(S(4))
    for i, col in ipairs(P.Colors) do
        local b = vgui.Create("DButton", pal)
        b:SetText("")
        b:SetSize(S(38), S(38))
        b.Paint = function(self, w, h)
            local sel = (colorIdx == i and not erasing)
            if UI.T.bevel then
                UI.Bevel(0, 0, w, h, not sel, col)
            else
                draw.RoundedBox(S(5), 0, 0, w, h, sel and UI.T.c.accent or UI.T.c.border)
                draw.RoundedBox(S(4), 2, 2, w - 4, h - 4, col)
            end
        end
        b.DoClick = function() colorIdx, erasing = i, false end
    end

    for i, size in ipairs(P.Sizes) do
        local b = vgui.Create("DButton", side)
        b:SetText("")
        b:Dock(TOP)
        b:SetTall(S(34))
        b:DockMargin(0, i == 1 and S(8) or S(4), 0, 0)
        b.Paint = function(self, w, h)
            local c = UI.T.c
            if UI.T.bevel then
                UI.Bevel(0, 0, w, h, sizeIdx ~= i, c.panel)
            else
                draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, sizeIdx == i and c.accentHi or c.panelHi)
            end
            UI.Circle(w / 2, h / 2, math.max(size * UI.Scale / 2, 1), c.windowText, 16)
        end
        b.DoClick = function() sizeIdx = i end
    end

    ---------------------------------------------------------------------
    -- Toile
    ---------------------------------------------------------------------
    canvas = vgui.Create("DPanel", content)
    canvas:Dock(FILL)
    canvas:DockMargin(S(6), S(6), S(6), S(6))
    canvas:SetCursor("crosshair")

    local function normPos()
        local mx, my = canvas:CursorPos()
        local w, h = math.max(canvas:GetWide(), 1), math.max(canvas:GetTall(), 1)
        return clamp(math.floor(mx / w * 1000 + 0.5), 0, 1000), clamp(math.floor(my / h * 1000 + 0.5), 0, 1000)
    end

    canvas.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        if #strokes >= P.MaxStrokes or P.PointCount(strokes) >= P.MaxPoints then
            desktop:Toast("Toile pleine : annulez ou effacez pour continuer")
            return
        end
        local col = erasing and Color(255, 255, 255) or P.Colors[colorIdx]
        local size = P.Sizes[sizeIdx] * (erasing and 2 or 1)
        local x, y = normPos()
        current = { r = col.r, g = col.g, b = col.b, size = size, pts = { x, y } }
        strokes[#strokes + 1] = current
        self:MouseCapture(true)
    end
    canvas.OnMouseReleased = function(self)
        current = nil
        self:MouseCapture(false)
    end
    canvas.Think = function(self)
        if not current then return end
        if P.PointCount(strokes) >= P.MaxPoints then current = nil return end
        local x, y = normPos()
        local n = #current.pts
        if math.abs(current.pts[n - 1] - x) + math.abs(current.pts[n] - y) >= 2 then
            current.pts[n + 1], current.pts[n + 2] = x, y
        end
    end

    canvas.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(0, 0, w, h)
        draw.NoTexture()
        for _, st in ipairs(strokes) do
            surface.SetDrawColor(st.r, st.g, st.b, 255)
            local pts = st.pts
            local half = math.max(st.size * UI.Scale / 2, 0.5)
            local x1, y1 = pts[1] / 1000 * w, pts[2] / 1000 * h
            if #pts == 2 then
                UI.Circle(x1, y1, half, Color(st.r, st.g, st.b), 12)
            end
            for i = 3, #pts - 1, 2 do
                local x2, y2 = pts[i] / 1000 * w, pts[i + 1] / 1000 * h
                local dx, dy = x2 - x1, y2 - y1
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0.01 then
                    local nx, ny = -dy / len * half, dx / len * half
                    surface.DrawPoly({
                        { x = x1 + nx, y = y1 + ny }, { x = x1 - nx, y = y1 - ny },
                        { x = x2 - nx, y = y2 - ny }, { x = x2 + nx, y = y2 + ny },
                    })
                end
                x1, y1 = x2, y2
            end
        end
        surface.SetDrawColor(UI.T.c.border.r, UI.T.c.border.g, UI.T.c.border.b, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    win.OnAppArgs = function(_, a)
        if a and a.path then
            local text = FS.Read(a.path)
            local parsed = text and P.Parse(text)
            if parsed then strokes, path = parsed, a.path; setTitle() end
        end
    end
    if args.path then win:OnAppArgs(args) end
    setTitle()
    return win
end

OS.RegisterApp("paint", {
    name = "Dessin", icon = "paint", order = 61, single = false,
    open = openPaint,
})
