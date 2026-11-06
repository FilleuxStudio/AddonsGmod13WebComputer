--[[----------------------------------------------------------------------------
    ComputerWeb - Bibliothèque d'interface (client)
      * échelle + polices
      * thèmes (5 "systèmes" : nova, terra, cipher, sandbox, retro)
      * widgets : bouton, champ de texte, curseur, fenêtre déplaçable
------------------------------------------------------------------------------]]

local CW = ComputerWeb
CW.UI = CW.UI or {}
local UI = CW.UI

---------------------------------------------------------------------------
-- Échelle et polices
---------------------------------------------------------------------------
UI.Scale = 1

function UI.S(n)
    return math.floor(n * UI.Scale + 0.5)
end
local S = UI.S

function UI.RefreshScale()
    UI.Scale = math.Clamp(ScrH() / 1080, 0.8, 1.6)
    local ui = "Roboto"
    surface.CreateFont("CW.Small",     { font = ui, size = S(13), weight = 500, extended = true })
    surface.CreateFont("CW.Body",      { font = ui, size = S(15), weight = 500, extended = true })
    surface.CreateFont("CW.Bold",      { font = ui, size = S(15), weight = 800, extended = true })
    surface.CreateFont("CW.Title",     { font = ui, size = S(19), weight = 700, extended = true })
    surface.CreateFont("CW.Big",       { font = ui, size = S(34), weight = 300, extended = true })
    surface.CreateFont("CW.Huge",      { font = ui, size = S(52), weight = 700, extended = true })
    surface.CreateFont("CW.Tile",      { font = ui, size = S(30), weight = 800, extended = true })
    surface.CreateFont("CW.Mono",      { font = "Courier New", size = S(16), weight = 500, extended = true })
    surface.CreateFont("CW.MonoBold",  { font = "Courier New", size = S(16), weight = 800, extended = true })
    surface.CreateFont("CW.MonoSmall", { font = "Courier New", size = S(13), weight = 500, extended = true })
end

---------------------------------------------------------------------------
-- Couleurs utilitaires
---------------------------------------------------------------------------
function UI.Mix(a, b, t)
    t = math.Clamp(t, 0, 1)
    return Color(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        (a.a or 255) + ((b.a or 255) - (a.a or 255)) * t)
end

function UI.Alpha(c, a)
    return Color(c.r, c.g, c.b, a)
end

---------------------------------------------------------------------------
-- Thèmes
---------------------------------------------------------------------------
-- layout : "bottom" = barre des tâches en bas | "side" = dock à gauche + barre du haut
UI.Themes = {
    nova = {
        id = "nova", name = "Nova", os = "Nova OS", layout = "bottom", mono = false, tintTitle = true,
        wallpaper = "nova", boot = "computerweb/boot_nova.wav", radius = 6,
        startLabel = "Démarrer", shutdownLabel = "Éteindre", prompt = "C:\\>",
        c = {
            window     = Color(246, 248, 252), windowText = Color(24, 32, 48), dim = Color(96, 108, 130),
            title      = Color(34, 92, 190),   titleOff = Color(120, 140, 175), titleText = Color(255, 255, 255),
            bar        = Color(16, 30, 58, 235), barText = Color(235, 242, 255),
            accent     = Color(46, 125, 240),  accentHi = Color(86, 156, 255), accentText = Color(255, 255, 255),
            input      = Color(255, 255, 255), border = Color(180, 195, 220), panel = Color(232, 238, 248),
            panelHi    = Color(214, 226, 246), danger = Color(214, 64, 64), ok = Color(60, 170, 100),
            menu       = Color(22, 38, 70, 245),
        },
    },
    terra = {
        id = "terra", name = "Terra", os = "Terra OS", layout = "side", mono = false, tintTitle = true,
        wallpaper = "terra", boot = "computerweb/boot_terra.wav", radius = 10,
        startLabel = "Applications", shutdownLabel = "Éteindre", prompt = "$",
        c = {
            window     = Color(250, 248, 250), windowText = Color(42, 30, 48), dim = Color(120, 104, 124),
            title      = Color(86, 40, 98),    titleOff = Color(140, 118, 146), titleText = Color(255, 255, 255),
            bar        = Color(40, 20, 48, 240), barText = Color(255, 240, 232),
            accent     = Color(238, 110, 50),  accentHi = Color(255, 142, 84), accentText = Color(255, 255, 255),
            input      = Color(255, 255, 255), border = Color(208, 192, 212), panel = Color(240, 232, 242),
            panelHi    = Color(228, 214, 232), danger = Color(214, 64, 64), ok = Color(80, 170, 100),
            menu       = Color(48, 24, 58, 245),
        },
    },
    cipher = {
        id = "cipher", name = "Cipher", os = "Cipher OS", layout = "bottom", mono = true,
        wallpaper = "cipher", boot = "computerweb/boot_cipher.wav", radius = 2,
        startLabel = "[ menu ]", shutdownLabel = "shutdown", prompt = "root@cipher:~#",
        c = {
            window     = Color(10, 16, 24),    windowText = Color(190, 255, 220), dim = Color(90, 150, 130),
            title      = Color(8, 40, 50),     titleOff = Color(14, 26, 32), titleText = Color(80, 255, 190),
            bar        = Color(4, 10, 16, 240), barText = Color(120, 255, 200),
            accent     = Color(0, 220, 170),   accentHi = Color(60, 255, 210), accentText = Color(4, 14, 18),
            input      = Color(4, 12, 18),     border = Color(0, 120, 100), panel = Color(12, 26, 34),
            panelHi    = Color(16, 44, 54),    danger = Color(255, 70, 90), ok = Color(60, 255, 150),
            menu       = Color(6, 14, 20, 248),
        },
    },
    sandbox = {
        id = "sandbox", name = "Sandbox", os = "Sandbox OS", layout = "bottom", mono = false,
        wallpaper = "sandbox", boot = "computerweb/boot_sandbox.wav", radius = 14,
        startLabel = "Lanceur", shutdownLabel = "Éteindre", prompt = "sandbox>",
        c = {
            window     = Color(38, 44, 54),    windowText = Color(232, 238, 246), dim = Color(150, 160, 176),
            title      = Color(28, 33, 42),    titleOff = Color(46, 52, 62), titleText = Color(255, 255, 255),
            bar        = Color(22, 26, 34, 235), barText = Color(240, 244, 250),
            accent     = Color(255, 150, 40),  accentHi = Color(255, 182, 90), accentText = Color(30, 22, 12),
            input      = Color(26, 31, 40),    border = Color(70, 78, 92), panel = Color(46, 53, 64),
            panelHi    = Color(60, 69, 82),    danger = Color(235, 80, 80), ok = Color(90, 200, 120),
            menu       = Color(26, 31, 40, 248),
        },
    },
}

-- Retro98 : look "années 90" (relief biseauté, barre de titre dégradée). Création originale.
UI.Themes.retro = {
    id = "retro", name = "Retro98", os = "Retro OS 98", layout = "bottom", mono = false,
    bevel = true, tintTitle = true,
    wallpaper = "retro", boot = "computerweb/boot_retro.wav", radius = 0,
    startLabel = "Démarrer", shutdownLabel = "Arrêter...", prompt = "C:\\RETRO>",
    c = {
        window     = Color(192, 192, 192), windowText = Color(0, 0, 0),       dim = Color(96, 96, 96),
        title      = Color(0, 0, 128),     title2 = Color(16, 132, 208),      titleOff = Color(128, 128, 128),
        titleText  = Color(255, 255, 255),
        bar        = Color(192, 192, 192, 255), barText = Color(0, 0, 0),
        accent     = Color(0, 0, 128),     accentHi = Color(16, 70, 176),     accentText = Color(255, 255, 255),
        input      = Color(255, 255, 255), border = Color(128, 128, 128),     panel = Color(192, 192, 192),
        panelHi    = Color(210, 210, 210), danger = Color(180, 0, 0),         ok = Color(0, 120, 0),
        menu       = Color(192, 192, 192, 255),
    },
}

UI.ThemeOrder = { "nova", "terra", "cipher", "sandbox", "retro" }
UI.Wallpapers = { "nova", "terra", "cipher", "sandbox", "retro", "aurora", "graphite" }

-- Couleur d'accent choisie par le joueur (Paramètres > Apparence). Vide = couleur du thème.
UI.CVAccent = CreateClientConVar("cw_accent", "", true, false, "Couleur d'accent des ordinateurs (r g b), vide = thème")

--- Applique tout de suite une couleur d'accent ("r g b", ou "" = thème). La sauvegarde
--- dans le convar est faite par l'appelant (RunConsoleCommand("cw_accent", UI.AccentOverride)).
function UI.SetAccent(str)
    UI.AccentOverride = tostring(str or "")
    UI.ApplyColors()
end

function UI.GetAccent()
    local raw = UI.AccentOverride
    if raw == nil then raw = UI.CVAccent:GetString() end
    local r, g, b = tostring(raw):match("^%s*(%d+)%s+(%d+)%s+(%d+)%s*$")
    if not r then return nil end
    return Color(math.Clamp(tonumber(r), 0, 255), math.Clamp(tonumber(g), 0, 255), math.Clamp(tonumber(b), 0, 255))
end

local function lum(c) return c.r * 0.299 + c.g * 0.587 + c.b * 0.114 end

--- Recalcule les couleurs du thème courant (copie du thème de base + accent joueur).
function UI.ApplyColors()
    local base, t = UI.Base, UI.T
    if not base or not t then return end
    for k, v in pairs(base.c) do t.c[k] = v end
    local acc = UI.GetAccent()
    if acc then
        local c = t.c
        c.accent = acc
        c.accentHi = UI.Mix(acc, color_white, 0.3)
        c.accentText = lum(acc) > 150 and Color(20, 20, 24) or Color(255, 255, 255)
        if t.tintTitle then
            c.title = UI.Mix(acc, color_black, 0.35)
            if base.c.title2 then c.title2 = UI.Mix(acc, color_white, 0.25) end
        end
    end
end

UI.Base = UI.Themes.nova
UI.T = { c = {} }
for k, v in pairs(UI.Themes.nova) do if k ~= "c" then UI.T[k] = v end end

function UI.SetTheme(id)
    local base = UI.Themes[id] or UI.Themes.nova
    local t = {}
    for k, v in pairs(base) do if k ~= "c" then t[k] = v end end
    t.c = {}
    UI.Base, UI.T = base, t
    UI.ApplyColors()
    return t
end
UI.SetTheme("nova")

---------------------------------------------------------------------------
-- Relief biseauté (thème Retro98) et dégradé horizontal
---------------------------------------------------------------------------
local BV = {
    light = Color(223, 223, 223), white = Color(255, 255, 255),
    gray = Color(128, 128, 128), dark = Color(10, 10, 10),
}

local function frame(x, y, w, h, tl, br, t)
    surface.SetDrawColor(tl.r, tl.g, tl.b, 255)
    surface.DrawRect(x, y, w - t, t)
    surface.DrawRect(x, y, t, h - t)
    surface.SetDrawColor(br.r, br.g, br.b, 255)
    surface.DrawRect(x, y + h - t, w, t)
    surface.DrawRect(x + w - t, y, t, h)
end

--- Rectangle en relief (raised = true) ou en creux (raised = false).
function UI.Bevel(x, y, w, h, raised, face)
    local t = math.max(1, UI.S(1))
    face = face or UI.T.c.panel
    surface.SetDrawColor(face.r, face.g, face.b, 255)
    surface.DrawRect(x, y, w, h)
    if raised then
        frame(x, y, w, h, BV.light, BV.dark, t)
        frame(x + t, y + t, w - 2 * t, h - 2 * t, BV.white, BV.gray, t)
    else
        frame(x, y, w, h, BV.gray, BV.white, t)
        frame(x + t, y + t, w - 2 * t, h - 2 * t, BV.dark, BV.light, t)
    end
end

--- Dégradé horizontal a -> b
function UI.HGradient(x, y, w, h, a, b)
    local n = 28
    for i = 0, n - 1 do
        local col = UI.Mix(a, b, i / (n - 1))
        surface.SetDrawColor(col.r, col.g, col.b, 255)
        local x0 = x + math.floor(w * i / n)
        local x1 = x + math.floor(w * (i + 1) / n)
        surface.DrawRect(x0, y, math.max(x1 - x0, 1), h)
    end
end

---------------------------------------------------------------------------
-- Matériaux
---------------------------------------------------------------------------
local iconCache, wallCache = {}, {}

function UI.Icon(name)
    local m = iconCache[name]
    if m == nil then
        m = Material("computerweb/icons/" .. name .. ".png", "smooth mips")
        iconCache[name] = m
    end
    return m
end

function UI.Wallpaper(name)
    local m = wallCache[name]
    if m == nil then
        m = Material("computerweb/wall/" .. name .. ".jpg", "smooth")
        wallCache[name] = m
    end
    return m
end

-- Icônes en couleur (tuiles d'applications, dossier, fichier) : jamais teintées.
-- Toutes les autres sont des glyphes blancs que l'appelant teinte (couleur du texte du thème).
UI.ColorIcons = {
    browser = true, files = true, notepad = true, music = true, terminal = true, settings = true,
    folder = true, file = true, editor = true, calc = true, mines = true, paint = true,
}

function UI.DrawIcon(name, x, y, w, h, col)
    col = col or color_white
    surface.SetMaterial(UI.Icon(name))
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawTexturedRect(x, y, w, h)
end

function UI.Circle(cx, cy, r, col, seg)
    seg = seg or 28
    local poly = {}
    for i = 0, seg - 1 do
        local a = math.rad(i / seg * 360)
        poly[#poly + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
    end
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawPoly(poly)
end

--- Logo "orbe" original de l'OS (remplace les logos de marques de la v1).
function UI.DrawOrb(cx, cy, r, col)
    UI.Circle(cx, cy, r, col, 32)
    local inner = UI.Alpha(UI.T.c.bar, 255)
    UI.Circle(cx, cy, r * 0.62, inner, 32)
    UI.Circle(cx, cy, r * 0.34, col, 32)
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function enterHover(self)
    self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover or 0, self:IsHovered() and 1 or 0)
    return self.cwHover
end

--- Bouton thémé. kind : "flat" | "accent" | "danger" | "ghost"
function UI.Button(parent, text, icon, onClick, kind)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.cwText, b.cwIcon, b.cwKind = text, icon, kind or "flat"
    b.cwHover = 0

    b.Paint = function(self, w, h)
        local T = UI.T
        local c = T.c
        local hv = enterHover(self)
        local bg, fg
        if self.cwKind == "accent" then
            bg, fg = UI.Mix(c.accent, c.accentHi, hv), c.accentText
        elseif self.cwKind == "danger" then
            bg, fg = UI.Mix(c.danger, UI.Mix(c.danger, color_white, 0.25), hv), color_white
        elseif self.cwKind == "ghost" then
            bg, fg = UI.Alpha(c.accent, math.floor(hv * 70)), c.windowText
        else
            bg, fg = UI.Mix(c.panel, c.panelHi, hv), c.windowText
        end
        if self.cwDisabled then fg = UI.Alpha(fg, 110) end
        if self:IsDown() then bg = UI.Mix(bg, color_black, 0.12) end

        local ox, oy = 0, 0
        if T.bevel then
            local down = self:IsDown()
            if self.cwKind == "accent" then
                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                UI.Bevel(1, 1, w - 2, h - 2, not down, c.panel)
            else
                UI.Bevel(0, 0, w, h, not down, c.panel)
            end
            fg = self.cwKind == "danger" and c.danger or c.windowText
            if self.cwDisabled then fg = c.dim end
            if down then ox, oy = 1, 1 end
        else
            draw.RoundedBox(S(T.radius), 0, 0, w, h, bg)
        end

        local ic = self.cwIcon
        local pad = S(8)
        if self.cwText and self.cwText ~= "" then
            local font = T.mono and "CW.Mono" or "CW.Body"
            surface.SetFont(font)
            local tw = surface.GetTextSize(self.cwText)
            local isz = ic and math.floor(h * 0.56) or 0
            local total = tw + (ic and (isz + S(7)) or 0)
            local x = math.floor((w - total) / 2) + ox
            if ic then
                UI.DrawIcon(ic, x, math.floor((h - isz) / 2) + oy, isz, isz, UI.ColorIcons[ic] and color_white or fg)
                x = x + isz + S(7)
            end
            draw.SimpleText(self.cwText, font, x, h / 2 + oy, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        elseif ic then
            local isz = math.floor(math.min(w, h) - pad)
            UI.DrawIcon(ic, math.floor((w - isz) / 2) + ox, math.floor((h - isz) / 2) + oy, isz, isz, UI.ColorIcons[ic] and color_white or fg)
        end
    end

    b.DoClick = function(self)
        if self.cwDisabled then return end
        if onClick then onClick(self) end
    end
    return b
end

function UI.Label(parent, text, font, colorKey)
    local l = vgui.Create("DLabel", parent)
    l:SetText(text or "")
    l:SetFont(font or "CW.Body")
    l.cwColorKey = colorKey or "windowText"
    l.Think = function(self)
        local col = UI.T.c[self.cwColorKey] or UI.T.c.windowText
        if self.cwLastCol ~= col then
            self.cwLastCol = col
            self:SetTextColor(col)
        end
    end
    l:SetTextColor(UI.T.c[l.cwColorKey])
    return l
end

--- Champ de texte thémé (une ligne, ou multiligne si multiline = true)
function UI.Entry(parent, placeholder, multiline)
    local e = vgui.Create("DTextEntry", parent)
    e:SetFont(UI.T.mono and "CW.Mono" or "CW.Body")
    e:SetPaintBackground(false)
    e:SetDrawLanguageID(false)
    if multiline then e:SetMultiline(true) end
    e.cwPlaceholder = placeholder

    e.Paint = function(self, w, h)
        local T = UI.T
        local c = T.c
        if T.bevel then
            UI.Bevel(0, 0, w, h, false, c.input)
        else
            draw.RoundedBox(S(T.radius), 0, 0, w, h, c.border)
            draw.RoundedBox(S(T.radius), 1, 1, w - 2, h - 2, c.input)
        end
        if self:HasFocus() and not T.bevel then
            surface.SetDrawColor(c.accent.r, c.accent.g, c.accent.b, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
        self:DrawTextEntryText(c.windowText, c.accent, c.windowText)
        if self.cwPlaceholder and self:GetText() == "" and not self:HasFocus() then
            draw.SimpleText(self.cwPlaceholder, "CW.Body", S(6), multiline and S(8) or h / 2, c.dim,
                TEXT_ALIGN_LEFT, multiline and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
        end
    end
    return e
end

--- Curseur horizontal 0..1
function UI.Slider(parent, value, onChange)
    local s = vgui.Create("DPanel", parent)
    s.cwValue = math.Clamp(value or 0, 0, 1)
    s:SetCursor("hand")

    local function setFromMouse(self)
        local x = self:CursorPos()
        local pad = S(8)
        self.cwValue = math.Clamp((x - pad) / math.max(self:GetWide() - pad * 2, 1), 0, 1)
        if onChange then onChange(self.cwValue) end
    end

    s.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.cwDrag = true
        self:MouseCapture(true)
        setFromMouse(self)
    end
    s.OnMouseReleased = function(self)
        self.cwDrag = false
        self:MouseCapture(false)
    end
    s.OnCursorMoved = function(self)
        if self.cwDrag then setFromMouse(self) end
    end
    s.Paint = function(self, w, h)
        local c = UI.T.c
        local pad = S(8)
        local ty = math.floor(h / 2) - S(2)
        local fw = (w - pad * 2) * self.cwValue
        if UI.T.bevel then
            UI.Bevel(pad, ty - 1, w - pad * 2, S(6), false, c.panelHi)
            UI.Bevel(math.floor(pad + fw - S(5)), math.floor(h / 2 - S(10)), S(10), S(20), true, c.panel)
            return
        end
        draw.RoundedBox(S(2), pad, ty, w - pad * 2, S(4), c.panelHi)
        draw.RoundedBox(S(2), pad, ty, fw, S(4), c.accent)
        UI.Circle(pad + fw, h / 2, S(7), c.accent, 20)
    end
    return s
end

---------------------------------------------------------------------------
-- Fenêtre déplaçable / redimensionnable (à l'intérieur du bureau)
---------------------------------------------------------------------------
function UI.Window(desktop, opts)
    local T = UI.T
    local TB = S(T.bevel and 27 or 32)
    local parent = desktop.Area

    local win = vgui.Create("DPanel", parent)
    win.cwIsWindow = true
    win.cwTitle = opts.title or "Fenêtre"
    win.cwIcon = opts.icon
    win.cwApp = opts.app
    win.cwMinW, win.cwMinH = opts.minW or S(360), opts.minH or S(240)
    win.cwDesktop = desktop

    local aw, ah = parent:GetSize()
    local w = math.min(opts.w or S(800), aw - S(10))
    local h = math.min(opts.h or S(520), ah - S(10))
    win:SetSize(w, h)
    local n = #desktop.Windows
    local x = math.Clamp(S(70) + (n % 7) * S(28), 0, math.max(aw - w, 0))
    local y = math.Clamp(S(20) + (n % 7) * S(28), 0, math.max(ah - h, 0))
    win:SetPos(x, y)

    function win:IsActive() return desktop.Active == self end
    function win:SetWinTitle(t) self.cwTitle = t end

    win.Paint = function(self, w2, h2)
        local th = UI.T
        local c = th.c
        local r = S(th.radius)
        local active = self:IsActive()
        if th.bevel then
            UI.Bevel(0, 0, w2, h2, true, c.window)
            local m = S(3)
            local a = active and c.title or c.titleOff
            local b = active and (c.title2 or c.title) or UI.Mix(c.titleOff, color_white, 0.35)
            UI.HGradient(m, m, w2 - m * 2, TB - m, a, b)
        else
            -- ombre
            draw.RoundedBox(r + S(3), -S(3), -S(1), w2 + S(6), h2 + S(6), Color(0, 0, 0, active and 70 or 40))
            draw.RoundedBox(r, 0, 0, w2, h2, c.border)
            draw.RoundedBox(r, 1, 1, w2 - 2, h2 - 2, c.window)
            draw.RoundedBoxEx(r, 1, 1, w2 - 2, TB, active and c.title or c.titleOff, true, true, false, false)
        end

        local tx = S(10)
        if self.cwIcon then
            UI.DrawIcon(self.cwIcon, tx, math.floor((TB - S(20)) / 2) + 1, S(20), S(20))
            tx = tx + S(28)
        end
        draw.SimpleText(self.cwTitle, th.mono and "CW.Mono" or "CW.Bold", tx, TB / 2 + 1,
            c.titleText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Barre de titre (zone de glisser)
    local bar = vgui.Create("DPanel", win)
    bar:Dock(TOP)
    bar:SetTall(TB)
    bar:SetCursor("sizeall")
    bar.Paint = function() end
    win.TitleBar = bar

    bar.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        local now = SysTime()
        if self.cwLastClick and now - self.cwLastClick < 0.35 then
            win:ToggleMaximize()
            self.cwLastClick = nil
            return
        end
        self.cwLastClick = now
        if win.cwMax then return end
        local mx, my = win:CursorPos()
        self.cwOff = { mx, my }
        self:MouseCapture(true)
    end
    bar.OnMouseReleased = function(self)
        self.cwOff = nil
        self:MouseCapture(false)
    end
    bar.Think = function(self)
        if not self.cwOff then return end
        local px, py = win:GetParent():CursorPos()
        local pw, ph = win:GetParent():GetSize()
        local nx = math.Clamp(px - self.cwOff[1], -win:GetWide() + S(80), pw - S(80))
        local ny = math.Clamp(py - self.cwOff[2], 0, ph - TB)
        win:SetPos(nx, ny)
    end

    -- Boutons de fenêtre (à droite)
    local function winBtn(kind, fn)
        local b = vgui.Create("DButton", bar)
        b:SetText("")
        b:Dock(RIGHT)
        if T.bevel then
            b:SetWide(S(22))
            b:DockMargin(0, S(5), kind == "close" and S(5) or S(2), S(3))
        else
            b:SetWide(S(38))
        end
        b.cwHover = 0
        b.Paint = function(self, bw, bh)
            local hv = enterHover(self)
            local cc = UI.T.c
            if UI.T.bevel then
                local down = self:IsDown()
                UI.Bevel(0, 0, bw, bh, not down, cc.panel)
                local o = down and 1 or 0
                local cx, cy, s2 = bw / 2 + o, bh / 2 + o, S(4)
                surface.SetDrawColor(0, 0, 0, 255)
                if kind == "close" then
                    for d = 0, 1 do
                        surface.DrawLine(cx - s2 + d, cy - s2, cx + s2 + 1 + d, cy + s2 + 1)
                        surface.DrawLine(cx - s2 + d, cy + s2, cx + s2 + 1 + d, cy - s2 - 1)
                    end
                elseif kind == "min" then
                    surface.DrawRect(cx - s2, cy + s2 - 2, s2 * 2, 3)
                else
                    surface.DrawOutlinedRect(cx - s2, cy - s2, s2 * 2, s2 * 2, 2)
                end
                return
            end
            if hv > 0.01 then
                local col = kind == "close" and cc.danger or Color(255, 255, 255, 40)
                draw.RoundedBox(0, 0, 0, bw, bh, UI.Alpha(col, math.floor(hv * (kind == "close" and 255 or 60))))
            end
            surface.SetDrawColor(cc.titleText.r, cc.titleText.g, cc.titleText.b, 255)
            local cx, cy, s2 = bw / 2, bh / 2, S(5)
            if kind == "close" then
                surface.DrawLine(cx - s2, cy - s2, cx + s2 + 1, cy + s2 + 1)
                surface.DrawLine(cx - s2, cy + s2, cx + s2 + 1, cy - s2 - 1)
            elseif kind == "min" then
                surface.DrawRect(cx - s2, cy + s2 - 1, s2 * 2, 2)
            else
                surface.DrawOutlinedRect(cx - s2, cy - s2, s2 * 2, s2 * 2, 2)
            end
        end
        b.DoClick = fn
        return b
    end
    winBtn("close", function() win:CloseWindow() end)
    if not opts.noMax then winBtn("max", function() win:ToggleMaximize() end) end
    winBtn("min", function() win:Minimize() end)

    -- Zone de contenu
    local content = vgui.Create("DPanel", win)
    content:Dock(FILL)
    if T.bevel then content:DockMargin(S(4), 0, S(4), S(4)) else content:DockMargin(1, 0, 1, 1) end
    content.Paint = function() end
    win.Content = content
    function win:GetContent() return self.Content end

    -- Poignée de redimensionnement
    if not opts.noResize then
        local grip = vgui.Create("DPanel", win)
        local gs = S(16)
        grip:SetSize(gs, gs)
        grip:SetCursor("sizenwse")
        grip.Paint = function(self, gw, gh)
            local cc = UI.T.c
            surface.SetDrawColor(cc.dim.r, cc.dim.g, cc.dim.b, 160)
            for i = 1, 3 do
                local o = i * S(4)
                surface.DrawLine(gw - o, gh - 1, gw - 1, gh - o)
            end
        end
        grip.OnMousePressed = function(self, code)
            if code ~= MOUSE_LEFT or win.cwMax then return end
            local px, py = win:GetParent():CursorPos()
            self.cwStart = { px, py, win:GetWide(), win:GetTall() }
            self:MouseCapture(true)
        end
        grip.OnMouseReleased = function(self)
            self.cwStart = nil
            self:MouseCapture(false)
        end
        grip.Think = function(self)
            if not self.cwStart then return end
            local px, py = win:GetParent():CursorPos()
            local pw, ph = win:GetParent():GetSize()
            local wx, wy = win:GetPos()
            local nw = math.Clamp(self.cwStart[3] + (px - self.cwStart[1]), win.cwMinW, pw - wx)
            local nh = math.Clamp(self.cwStart[4] + (py - self.cwStart[2]), win.cwMinH, ph - wy)
            win:SetSize(nw, nh)
        end
        win.OnSizeChanged = function(self, nw, nh)
            grip:SetPos(nw - gs - 1, nh - gs - 1)
            grip:MoveToFront()
        end
        grip:SetPos(w - gs - 1, h - gs - 1)
    end

    -- Comportements
    function win:Minimize()
        self:SetVisible(false)
        if desktop.Active == self then desktop.Active = nil end
        desktop:RefreshTaskbar()
    end

    function win:Restore()
        self:SetVisible(true)
        desktop:Activate(self)
    end

    function win:ToggleMaximize()
        if self.cwMax then
            self.cwMax = false
            local r = self.cwRestore
            if r then self:SetPos(r[1], r[2]); self:SetSize(r[3], r[4]) end
        else
            self.cwRestore = { self:GetX(), self:GetY(), self:GetWide(), self:GetTall() }
            self.cwMax = true
            self:SetPos(0, 0)
            self:SetSize(parent:GetWide(), parent:GetTall())
        end
    end

    function win:CloseWindow()
        if self.OnWindowClose then
            local ok, err = pcall(self.OnWindowClose, self)
            if not ok then ErrorNoHalt("[ComputerWeb] ", err, "\n") end
        end
        desktop:UnregisterWindow(self)
        self:Remove()
    end

    desktop:RegisterWindow(win)
    return win
end
