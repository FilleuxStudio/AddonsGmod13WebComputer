--[[----------------------------------------------------------------------------
    ComputerWeb - Bureau (client)
      * écran "moniteur" avec fond d'écran, démarrage, barre des tâches / dock
      * menu démarrer, icônes du bureau, horloge, menu clic droit
      * gestion des applications (OS.RegisterApp) et des fenêtres
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS

CW.OS = CW.OS or {}
local OS = CW.OS

OS.Apps = OS.Apps or {}
OS.AppOrder = OS.AppOrder or {}

OS.CV = {
    wallpaper = CreateClientConVar("cw_wallpaper",    "",    true, false, "Fond d'écran des ordinateurs (vide = celui du thème)"),
    clock24   = CreateClientConVar("cw_clock24",      "1",   true, false, "1 = horloge 24 h"),
    skipBoot  = CreateClientConVar("cw_skip_boot",    "0",   true, false, "1 = pas d'écran de démarrage"),
    volume    = CreateClientConVar("cw_volume",       "0.7", true, false, "Volume de la musique (0 à 1)"),
    engine    = CreateClientConVar("cw_search_engine","",    true, false, "Moteur de recherche (vide = défaut serveur)"),
}

---------------------------------------------------------------------------
-- Enregistrement des applications
---------------------------------------------------------------------------
--- def = { name, icon, order, single, desktopIcon, enabled = fn, open = fn(desktop, args) -> window }
function OS.RegisterApp(id, def)
    def.id = id
    def.order = def.order or 50
    if def.desktopIcon == nil then def.desktopIcon = true end
    if not OS.Apps[id] then OS.AppOrder[#OS.AppOrder + 1] = id end
    OS.Apps[id] = def
    table.sort(OS.AppOrder, function(a, b)
        local oa, ob = OS.Apps[a].order, OS.Apps[b].order
        if oa == ob then return a < b end
        return oa < ob
    end)
end

local function wallpaperName(T)
    local wp = OS.CV.wallpaper:GetString()
    for _, name in ipairs(UI.Wallpapers) do
        if name == wp then return wp end
    end
    return T.wallpaper
end

local function removeValue(tbl, val)
    for i = #tbl, 1, -1 do
        if tbl[i] == val then table.remove(tbl, i) end
    end
end

---------------------------------------------------------------------------
-- Ouverture du bureau
---------------------------------------------------------------------------
function OS.Close()
    if IsValid(OS.Desktop) then OS.Desktop:Remove() end
    OS.Desktop = nil
end

function OS.Open(ent)
    OS.Close()
    UI.RefreshScale()
    local T = UI.SetTheme((ent and ent.CWTheme) or "nova")
    FS.Init()

    local sw, sh = ScrW(), ScrH()
    local w = math.floor(sw * 0.84)
    local h = math.floor(w * 9 / 16)
    if h > sh * 0.9 then
        h = math.floor(sh * 0.9)
        w = math.floor(h * 16 / 9)
    end
    local bez = S(10)

    local root = vgui.Create("DPanel")
    root:SetSize(w + bez * 2, h + bez * 2)
    root:Center()
    root:MakePopup()
    root:SetKeyboardInputEnabled(true)
    root.Windows = {}
    root.Entity = ent
    root.HadEntity = IsValid(ent)
    root.Theme = T
    OS.Desktop = root

    root.Paint = function(self, pw, ph)
        draw.RoundedBox(S(20), -S(6), -S(2), pw + S(12), ph + S(14), Color(0, 0, 0, 120))
        draw.RoundedBox(S(16), 0, 0, pw, ph, Color(16, 18, 22))
        draw.RoundedBox(S(14), 2, 2, pw - 4, ph - 4, Color(32, 36, 44))
        UI.Circle(pw / 2, bez / 2, S(2), Color(90, 100, 112), 12)
    end

    -- L'écran lui-même
    local screen = vgui.Create("DPanel", root)
    screen:SetPos(bez, bez)
    screen:SetSize(w, h)
    root.Screen = screen
    screen.Paint = function(self, pw, ph)
        surface.SetMaterial(UI.Wallpaper(wallpaperName(UI.T)))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, pw, ph)
    end

    ---------------------------------------------------------------------
    -- Méthodes du bureau
    ---------------------------------------------------------------------
    function root:RegisterWindow(win)
        self.Windows[#self.Windows + 1] = win
        self:Activate(win)
    end

    function root:UnregisterWindow(win)
        removeValue(self.Windows, win)
        if self.Active == win then self.Active = nil end
        self:RefreshTaskbar()
    end

    function root:Activate(win)
        if not IsValid(win) then return end
        self.Active = win
        win:SetVisible(true)
        win:MoveToFront()
        self:RefreshTaskbar()
    end

    function root:Toast(text)
        if IsValid(self.ToastPanel) then self.ToastPanel:Remove() end
        local t = vgui.Create("DPanel", self.Screen)
        local tw
        surface.SetFont("CW.Body")
        tw = surface.GetTextSize(text)
        t:SetSize(tw + S(40), S(38))
        t:SetPos((w - t:GetWide()) / 2, h - S(130))
        t.Paint = function(_, pw, ph)
            draw.RoundedBox(S(10), 0, 0, pw, ph, UI.Alpha(UI.T.c.menu, 240))
            draw.SimpleText(text, "CW.Body", pw / 2, ph / 2, UI.T.c.barText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        t:MoveToFront()
        t:AlphaTo(0, 0.4, 2.4, function(_, p) if IsValid(p) then p:Remove() end end)
        self.ToastPanel = t
    end

    function root:OpenApp(id, args)
        local def = OS.Apps[id]
        if not def then return end
        self:CloseStartMenu()

        if def.enabled and not def.enabled() then
            self:Toast(def.name .. " est désactivé par l'administrateur.")
            return
        end

        if def.single then
            for _, win in ipairs(self.Windows) do
                if IsValid(win) and win.cwApp == id then
                    if not win:IsVisible() then win:Restore() else self:Activate(win) end
                    if args and win.OnAppArgs then win:OnAppArgs(args) end
                    return win
                end
            end
        end

        local ok, win = pcall(def.open, self, args or {})
        if not ok then
            ErrorNoHalt("[ComputerWeb] Erreur à l'ouverture de '" .. id .. "' : ", tostring(win), "\n")
            self:Toast("Erreur dans l'application " .. def.name)
            return
        end
        if IsValid(win) then
            win.cwApp = id
            win.cwIcon = win.cwIcon or def.icon
            self:Activate(win)
        end
        return win
    end

    function root:Shutdown()
        OS.Close()
    end

    root.OnRemove = function(self)
        for _, win in ipairs(self.Windows) do
            if IsValid(win) and win.OnWindowClose then
                pcall(win.OnWindowClose, win)
            end
        end
    end

    ---------------------------------------------------------------------
    -- Barres et zone de travail selon le thème
    ---------------------------------------------------------------------
    local barH = S(46)
    local topH = S(30)
    local dockW = S(72)
    local startW = S(124)

    local function clockText()
        if OS.CV.clock24:GetBool() then return os.date("%H:%M") end
        return os.date("%I:%M %p")
    end

    local function appRunning(id)
        for _, win in ipairs(root.Windows) do
            if IsValid(win) and win.cwApp == id then return win end
        end
    end

    local Area
    root.StartButton = nil

    if T.layout == "bottom" then
        local bar = vgui.Create("DPanel", screen)
        bar:Dock(BOTTOM)
        bar:SetTall(barH)
        bar.Paint = function(self, pw, ph)
            local c = UI.T.c
            surface.SetDrawColor(c.bar.r, c.bar.g, c.bar.b, c.bar.a)
            surface.DrawRect(0, 0, pw, ph)
            surface.SetDrawColor(c.accent.r, c.accent.g, c.accent.b, 120)
            surface.DrawRect(0, 0, pw, 1)
        end

        local start = vgui.Create("DButton", bar)
        start:SetText("")
        start:Dock(LEFT)
        start:SetWide(startW)
        start.cwHover = 0
        start.Paint = function(self, pw, ph)
            local c = UI.T.c
            local hv = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, (self:IsHovered() or root.MenuOpen) and 1 or 0)
            self.cwHover = hv
            if hv > 0.01 then draw.RoundedBox(0, 0, 0, pw, ph, UI.Alpha(c.accent, math.floor(60 * hv + (root.MenuOpen and 40 or 0)))) end
            UI.DrawOrb(S(26), ph / 2, S(11), c.accent)
            draw.SimpleText(UI.T.startLabel, UI.T.mono and "CW.MonoBold" or "CW.Bold", S(48), ph / 2, c.barText,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        start.DoClick = function() root:ToggleStartMenu() end
        root.StartButton = start

        local tray = vgui.Create("DPanel", bar)
        tray:Dock(RIGHT)
        tray:SetWide(S(110))
        tray.Paint = function(self, pw, ph)
            local c = UI.T.c
            draw.SimpleText(clockText(), "CW.Bold", pw / 2, ph / 2 - S(8), c.barText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(os.date("%d/%m/%Y"), "CW.Small", pw / 2, ph / 2 + S(10), UI.Alpha(c.barText, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local list = vgui.Create("DPanel", bar)
        list:Dock(FILL)
        list.Paint = function() end
        root.TaskList = list

        Area = vgui.Create("DPanel", screen)
        Area:Dock(FILL)
    else
        -- thème "side" : barre du haut + dock à gauche
        local top = vgui.Create("DPanel", screen)
        top:Dock(TOP)
        top:SetTall(topH)
        top.Paint = function(self, pw, ph)
            local c = UI.T.c
            surface.SetDrawColor(c.bar.r, c.bar.g, c.bar.b, c.bar.a)
            surface.DrawRect(0, 0, pw, ph)
            draw.SimpleText(UI.T.os, "CW.Bold", S(14), ph / 2, c.barText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(os.date("%d/%m  ") .. clockText(), "CW.Bold", pw / 2, ph / 2, c.barText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local power = UI.Button(top, nil, "power", function() root:Shutdown() end, "ghost")
        power:Dock(RIGHT)
        power:SetWide(S(36))
        power:DockMargin(0, S(2), S(6), S(2))
        power:SetTooltip(T.shutdownLabel)

        local dock = vgui.Create("DPanel", screen)
        dock:Dock(LEFT)
        dock:SetWide(dockW)
        dock.Paint = function(self, pw, ph)
            local c = UI.T.c
            surface.SetDrawColor(c.bar.r, c.bar.g, c.bar.b, c.bar.a)
            surface.DrawRect(0, 0, pw, ph)
        end

        local grid = vgui.Create("DButton", dock)
        grid:SetText("")
        grid:Dock(BOTTOM)
        grid:SetTall(S(62))
        grid:SetTooltip(T.startLabel)
        grid.cwHover = 0
        grid.Paint = function(self, pw, ph)
            local c = UI.T.c
            self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, (self:IsHovered() or root.MenuOpen) and 1 or 0)
            if self.cwHover > 0.01 then draw.RoundedBox(S(8), S(8), S(6), pw - S(16), ph - S(12), UI.Alpha(c.accent, math.floor(80 * self.cwHover))) end
            surface.SetDrawColor(c.barText.r, c.barText.g, c.barText.b, 255)
            local d, gap, x0, y0 = S(6), S(5), pw / 2 - S(10), ph / 2 - S(10)
            for i = 0, 2 do for j = 0, 2 do
                surface.DrawRect(x0 + i * (d + gap) - S(2), y0 + j * (d + gap) - S(2), d, d)
            end end
        end
        grid.DoClick = function() root:ToggleStartMenu() end
        root.StartButton = grid

        root.DockPanel = dock
        Area = vgui.Create("DPanel", screen)
        Area:Dock(FILL)
    end

    Area.Paint = function() end
    root.Area = Area

    function root:RefreshTaskbar()
        if T.layout == "bottom" then
            local list = self.TaskList
            if not IsValid(list) then return end
            list:Clear()
            for _, win in ipairs(self.Windows) do
                if IsValid(win) then
                    local b = vgui.Create("DButton", list)
                    b:SetText("")
                    b:Dock(LEFT)
                    b:SetWide(S(180))
                    b:DockMargin(S(3), S(5), 0, S(5))
                    b.cwHover = 0
                    b.Paint = function(self, pw, ph)
                        local c = UI.T.c
                        local active = root.Active == win and win:IsVisible()
                        self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
                        local a = active and 90 or math.floor(40 * self.cwHover)
                        draw.RoundedBox(S(UI.T.radius), 0, 0, pw, ph, UI.Alpha(c.accent, a))
                        if active then
                            surface.SetDrawColor(c.accent.r, c.accent.g, c.accent.b, 255)
                            surface.DrawRect(S(6), ph - 2, pw - S(12), 2)
                        end
                        local tx = S(8)
                        if win.cwIcon then
                            UI.DrawIcon(win.cwIcon, tx, (ph - S(20)) / 2, S(20), S(20))
                            tx = tx + S(26)
                        end
                        draw.SimpleText(win.cwTitle or "", UI.T.mono and "CW.MonoSmall" or "CW.Small", tx, ph / 2,
                            c.barText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    b.DoClick = function()
                        if root.Active == win and win:IsVisible() then win:Minimize() else win:Restore() end
                    end
                end
            end
        end
    end

    -- Dock (thème "side") : une icône par application
    if T.layout == "side" then
        for _, id in ipairs(OS.AppOrder) do
            local def = OS.Apps[id]
            local b = vgui.Create("DButton", root.DockPanel)
            b:SetText("")
            b:Dock(TOP)
            b:SetTall(S(60))
            b:SetTooltip(def.name)
            b.cwHover = 0
            b.Paint = function(self, pw, ph)
                local c = UI.T.c
                self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
                if self.cwHover > 0.01 then
                    draw.RoundedBox(S(10), S(8), S(5), pw - S(16), ph - S(10), UI.Alpha(color_white, math.floor(40 * self.cwHover)))
                end
                local isz = S(40)
                UI.DrawIcon(def.icon, (pw - isz) / 2, (ph - isz) / 2, isz, isz)
                local win = appRunning(id)
                if win then
                    draw.RoundedBox(S(2), S(2), ph / 2 - S(8), S(4), S(16), c.accent)
                end
            end
            b.DoClick = function()
                local win = appRunning(id)
                if win then
                    if root.Active == win and win:IsVisible() then win:Minimize() else win:Restore() end
                else
                    root:OpenApp(id)
                end
            end
        end
    end

    ---------------------------------------------------------------------
    -- Icônes du bureau (thèmes "bottom")
    ---------------------------------------------------------------------
    if T.layout == "bottom" then
        timer.Simple(0, function()
            if not IsValid(Area) then return end
            local x, y = S(18), S(14)
            local cellW, cellH = S(96), S(98)
            local ah = Area:GetTall()
            for _, id in ipairs(OS.AppOrder) do
                local def = OS.Apps[id]
                if def.desktopIcon then
                    if y + cellH > ah then x = x + cellW; y = S(14) end
                    local b = vgui.Create("DButton", Area)
                    b:SetText("")
                    b:SetPos(x, y)
                    b:SetSize(cellW - S(8), cellH - S(6))
                    b.cwHover = 0
                    b.Paint = function(self, pw, ph)
                        self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
                        local sel = (root.SelectedIcon == self)
                        if sel or self.cwHover > 0.01 then
                            draw.RoundedBox(S(8), 0, 0, pw, ph, Color(255, 255, 255, sel and 55 or math.floor(30 * self.cwHover)))
                        end
                        local isz = S(52)
                        UI.DrawIcon(def.icon, (pw - isz) / 2, S(6), isz, isz)
                        local font = UI.T.mono and "CW.MonoSmall" or "CW.Small"
                        draw.SimpleText(def.name, font, pw / 2 + 1, S(66) + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                        draw.SimpleText(def.name, font, pw / 2, S(66), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    end
                    b.DoClick = function(self)
                        local now = SysTime()
                        if root.SelectedIcon == self and self.cwLast and now - self.cwLast < 0.5 then
                            root.SelectedIcon = nil
                            root:OpenApp(id)
                        else
                            root.SelectedIcon = self
                            self.cwLast = now
                        end
                    end
                    y = y + cellH
                end
            end
        end)
    end

    ---------------------------------------------------------------------
    -- Menu démarrer / lanceur
    ---------------------------------------------------------------------
    local menuW, menuItemH = S(300), S(44)
    local menu

    local function buildMenu()
        if IsValid(menu) then menu:Remove() end
        local count = #OS.AppOrder
        local menuH = S(64) + count * menuItemH + S(64)
        menu = vgui.Create("DPanel", screen)
        menu:SetSize(menuW, menuH)
        if T.layout == "bottom" then
            menu:SetPos(S(6), h - barH - menuH - S(6))
        else
            menu:SetPos(dockW + S(8), topH + S(8))
        end
        menu:SetVisible(false)
        menu.Paint = function(self, pw, ph)
            local c = UI.T.c
            draw.RoundedBox(S(UI.T.radius + 4), -1, -1, pw + 2, ph + 2, Color(0, 0, 0, 90))
            draw.RoundedBox(S(UI.T.radius + 4), 0, 0, pw, ph, c.menu)
            -- en-tête
            UI.DrawOrb(S(34), S(32), S(14), c.accent)
            draw.SimpleText(UI.T.os, "CW.Title", S(58), S(24), c.barText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local nick = IsValid(LocalPlayer()) and LocalPlayer():Nick() or "Invité"
            draw.SimpleText(nick, "CW.Small", S(58), S(44), UI.Alpha(c.barText, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(255, 255, 255, 30)
            surface.DrawRect(S(12), S(62), pw - S(24), 1)
        end

        local function menuButton(parent, text, icon, y, fn, tall, danger)
            local b = vgui.Create("DButton", parent)
            b:SetText("")
            b:SetPos(S(8), y)
            b:SetSize(menuW - S(16), tall or menuItemH)
            b.cwHover = 0
            b.Paint = function(self, pw, ph)
                local c = UI.T.c
                self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
                if self.cwHover > 0.01 then
                    draw.RoundedBox(S(UI.T.radius), 0, 0, pw, ph, UI.Alpha(danger and c.danger or c.accent, math.floor((danger and 200 or 90) * self.cwHover)))
                end
                local isz = S(28)
                if icon then UI.DrawIcon(icon, S(10), (ph - isz) / 2, isz, isz) end
                draw.SimpleText(text, UI.T.mono and "CW.Mono" or "CW.Body", S(10) + (icon and S(40) or 0), ph / 2,
                    c.barText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            b.DoClick = fn
            return b
        end

        local y = S(68)
        for _, id in ipairs(OS.AppOrder) do
            local def = OS.Apps[id]
            menuButton(menu, def.name, def.icon, y, function() root:OpenApp(id) end)
            y = y + menuItemH
        end
        menuButton(menu, UI.T.shutdownLabel, "power", menuH - S(54), function() root:Shutdown() end, S(44), true)
    end

    function root:CloseStartMenu()
        root.MenuOpen = false
        if IsValid(menu) then menu:SetVisible(false) end
    end

    function root:ToggleStartMenu()
        if root.MenuOpen then self:CloseStartMenu() return end
        buildMenu()
        menu:SetVisible(true)
        menu:MoveToFront()
        root.MenuOpen = true
    end

    ---------------------------------------------------------------------
    -- Clic droit sur le bureau
    ---------------------------------------------------------------------
    Area.OnMousePressed = function(self, code)
        root:CloseStartMenu()
        root.SelectedIcon = nil
        if code ~= MOUSE_RIGHT then return end

        local m = DermaMenu()
        m:AddOption("Ouvrir le navigateur", function() root:OpenApp("browser") end):SetIcon("icon16/world.png")
        m:AddOption("Ouvrir mes fichiers", function() root:OpenApp("files") end):SetIcon("icon16/folder.png")
        local sub, opt = m:AddSubMenu("Fond d'écran")
        opt:SetIcon("icon16/picture.png")
        for _, name in ipairs(UI.Wallpapers) do
            sub:AddOption(name:sub(1, 1):upper() .. name:sub(2), function()
                RunConsoleCommand("cw_wallpaper", name)
            end)
        end
        sub:AddSpacer()
        sub:AddOption("Par défaut du thème", function() RunConsoleCommand("cw_wallpaper", "") end)
        m:AddOption("Paramètres", function() root:OpenApp("settings") end):SetIcon("icon16/wrench.png")
        m:AddSpacer()
        m:AddOption(T.shutdownLabel, function() root:Shutdown() end):SetIcon("icon16/door_out.png")
        m:Open()
    end

    ---------------------------------------------------------------------
    -- Boucle : focus des fenêtres, fermeture du menu, garde de session
    ---------------------------------------------------------------------
    root.Think = function(self)
        -- clic gauche / droit : amène la fenêtre sous le curseur au premier plan
        local down = input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT)
        if down and not self.WasDown then
            local hov = vgui.GetHoveredPanel()
            if self.MenuOpen and IsValid(menu) then
                local inside = IsValid(hov) and (hov == menu or hov:HasParent(menu))
                local onStart = IsValid(hov) and IsValid(self.StartButton) and (hov == self.StartButton)
                if not inside and not onStart then self:CloseStartMenu() end
            end
            if IsValid(Area) then
                local kids = Area:GetChildren()
                for i = #kids, 1, -1 do
                    local win = kids[i]
                    if IsValid(win) and win.cwIsWindow and win:IsVisible() then
                        local cx, cy = win:CursorPos()
                        if cx >= 0 and cy >= 0 and cx <= win:GetWide() and cy <= win:GetTall() then
                            if self.Active ~= win then self:Activate(win) else win:MoveToFront() end
                            break
                        end
                    end
                end
            end
        end
        self.WasDown = down

        -- garde de session (toutes les 0.5 s)
        local now = CurTime()
        if now < (self.NextGuard or 0) then return end
        self.NextGuard = now + 0.5

        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() then self:Shutdown() return end

        if self.HadEntity then
            if not IsValid(self.Entity) then self:Shutdown() return end
            local lim = CW.CVars.sessdist:GetFloat()
            if lim > 0 and lp:GetPos():Distance(self.Entity:GetPos()) > lim then
                chat.AddText(Color(255, 170, 60), "[ComputerWeb] ", color_white, "Vous vous êtes éloigné de l'ordinateur : session fermée.")
                self:Shutdown()
                return
            end
        end
    end

    ---------------------------------------------------------------------
    -- Écran de démarrage
    ---------------------------------------------------------------------
    if not OS.CV.skipBoot:GetBool() then
        surface.PlaySound(T.boot)
        local boot = vgui.Create("DPanel", screen)
        boot:SetSize(w, h)
        boot:SetPos(0, 0)
        boot:MoveToFront()
        local t0 = SysTime()
        local DURATION = 2.0
        boot.Paint = function(self, pw, ph)
            local c = UI.T.c
            surface.SetDrawColor(6, 8, 12, 255)
            surface.DrawRect(0, 0, pw, ph)
            local p = math.Clamp((SysTime() - t0) / DURATION, 0, 1)
            UI.DrawOrb(pw / 2, ph / 2 - S(34), S(34), c.accent)
            draw.SimpleText(UI.T.os, "CW.Big", pw / 2, ph / 2 + S(28), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local bw = S(240)
            draw.RoundedBox(S(3), pw / 2 - bw / 2, ph / 2 + S(72), bw, S(6), Color(255, 255, 255, 35))
            draw.RoundedBox(S(3), pw / 2 - bw / 2, ph / 2 + S(72), bw * p, S(6), c.accent)
            draw.SimpleText("ComputerWeb " .. CW.Version, "CW.Small", pw / 2, ph - S(24), Color(255, 255, 255, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        boot.Think = function(self)
            if SysTime() - t0 >= DURATION and not self.cwFading then
                self.cwFading = true
                self:AlphaTo(0, 0.35, 0, function(_, p) if IsValid(p) then p:Remove() end end)
            end
        end
    end

    root:RefreshTaskbar()
    return root
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
net.Receive("cw_os_open", function()
    local ent = net.ReadEntity()
    OS.Open(ent)
end)

-- Aperçu des thèmes sans entité (superadmin) : cw_desktop <nova|terra|cipher|sandbox>
concommand.Add("cw_desktop", function(ply, _, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local theme = args[1] or "nova"
    OS.Open({ CWTheme = theme, IsValid = function() return false end })
end)
