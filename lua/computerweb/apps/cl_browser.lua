--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Navigateur"
      * page d'accueil NATIVE (aucune dépendance au moteur web)
      * barre d'adresse : URL ou recherche (moteur configurable, SafeSearch)
      * chaque navigation passe par la garde d'URL (CW.CheckURL)
      * aucun pont JavaScript exposé aux sites visités
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local OS = CW.OS

local function htmlEscape(s)
    return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
CW.HTMLEscape = htmlEscape

local function blockedPage(reason, url)
    return string.format([[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
        body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f4f5f8;color:#222;
             display:flex;align-items:center;justify-content:center;height:100vh}
        .box{max-width:520px;padding:32px 40px;background:#fff;border-radius:14px;
             box-shadow:0 6px 24px rgba(0,0,0,.12);text-align:center}
        h1{margin:0 0 10px;font-size:22px;color:#c0392b}
        p{margin:6px 0;color:#555;line-height:1.4}
        code{display:block;margin-top:14px;padding:8px;background:#f0f1f4;border-radius:6px;
             font-size:12px;color:#777;word-break:break-all}
    </style></head><body><div class="box"><h1>Page bloquée</h1>
    <p>%s</p><code>%s</code></div></body></html>]], htmlEscape(reason), htmlEscape(url))
end

local function currentEngine()
    local key = OS.CV.engine:GetString()
    local engines = CW.Config.SearchEngines or {}
    if not engines[key] then key = CW.Config.DefaultSearchEngine end
    return key, engines[key]
end

local function openBrowser(desktop, args)
    local win = UI.Window(desktop, {
        title = "Navigateur", icon = "browser", app = "browser",
        w = S(980), h = S(600), minW = S(560), minH = S(340),
    })
    local content = win:GetContent()

    local html, start, address, body
    local loading = false
    local engineKey = (currentEngine())

    ---------------------------------------------------------------------
    -- Navigation
    ---------------------------------------------------------------------
    local function showStart(message)
        if IsValid(html) then
            html:SetVisible(false)
            html.cwInternal = false
            html:OpenURL("about:blank")   -- coupe le son / la vidéo
        end
        start:SetVisible(true)
        start.cwMessage = message
        address:SetText("")
        win:SetWinTitle("Navigateur")
        loading = false
    end

    local function ensureHTML()
        if IsValid(html) then return html end

        html = vgui.Create("DHTML", body)
        html:Dock(FILL)
        html:SetAllowLua(false)            -- une page web ne peut JAMAIS exécuter de Lua
        html.ConsoleMessage = function() end

        html.OnBeginLoadingDocument = function(self, url)
            if url == "about:blank" then return end
            if self.cwInternal then return end        -- page interne (page bloquée)
            local ok, why = CW.CheckURL(url)
            if not ok then
                self:StopLoading()
                self.cwInternal = true
                self:SetHTML(blockedPage(why, url))
                address:SetText(url)
                return
            end
            address:SetText(url)
            loading = true
        end
        html.OnFinishLoadingDocument = function(self)
            loading = false
        end
        html.OnDocumentReady = function(self, url)
            loading = false
            if url and url ~= "about:blank" and not self.cwInternal then address:SetText(url) end
        end
        html.OnChangeTitle = function(_, title)
            if title and title ~= "" and not title:find("^about:") then
                win:SetWinTitle(title)
            end
        end
        -- Liens target=_blank / popups : on reste dans la même fenêtre (et on re-vérifie l'URL)
        html.OnChildViewCreated = function(self, _, targetURL)
            local ok, why = CW.CheckURL(targetURL)
            if ok then
                self.cwInternal = false
                self:OpenURL(targetURL)
            else
                desktop:Toast("Lien bloqué : " .. tostring(why))
            end
        end
        return html
    end

    local function navigate(text)
        local url, why = CW.ResolveInput(text, engineKey)
        if not url then
            if not IsValid(html) or not html:IsVisible() then
                start.cwMessage = why
            end
            desktop:Toast(why or "Adresse refusée")
            return
        end
        ensureHTML()
        html.cwInternal = false
        html:SetVisible(true)
        start:SetVisible(false)
        address:SetText(url)
        loading = true
        html:OpenURL(url)
    end

    ---------------------------------------------------------------------
    -- Barre d'outils
    ---------------------------------------------------------------------
    local tb = vgui.Create("DPanel", content)
    tb:Dock(TOP)
    tb:SetTall(S(44))
    tb:DockPadding(S(6), S(6), S(6), S(6))
    tb.Paint = function(_, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
        if loading then
            local p = (SysTime() * 0.9) % 1
            surface.SetDrawColor(c.accent.r, c.accent.g, c.accent.b, 255)
            surface.DrawRect(w * p - w * 0.15, h - 3, w * 0.3, 3)
        else
            surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
            surface.DrawRect(0, h - 1, w, 1)
        end
    end

    local function iconBtn(icon, tip, fn, side)
        local b = UI.Button(tb, nil, icon, fn, "ghost")
        b:Dock(side or LEFT)
        b:SetWide(S(32))
        b:DockMargin(0, 0, S(4), 0)
        b:SetTooltip(tip)
        return b
    end

    iconBtn("back", "Précédent", function() if IsValid(html) and html:IsVisible() then html:QueueJavascript("history.back()") end end)
    iconBtn("forward", "Suivant", function() if IsValid(html) and html:IsVisible() then html:QueueJavascript("history.forward()") end end)
    iconBtn("reload", "Actualiser", function()
        if IsValid(html) and html:IsVisible() then html:QueueJavascript("location.reload()") end
    end)
    iconBtn("home", "Accueil", function() showStart() end)

    -- Menu (à droite)
    iconBtn("menu", "Menu", function()
        local m = DermaMenu()
        m:AddOption("Accueil", function() showStart() end):SetIcon("icon16/house.png")

        local sub, opt = m:AddSubMenu("Moteur de recherche")
        opt:SetIcon("icon16/magnifier.png")
        for key, eng in SortedPairs(CW.Config.SearchEngines or {}) do
            local o = sub:AddOption(eng.name, function()
                engineKey = key
                RunConsoleCommand("cw_search_engine", key)
                start.cwEngineName = eng.name
            end)
            if key == engineKey then o:SetChecked(true) end
        end

        m:AddOption("Ouvrir dans le navigateur Steam", function()
            local url = IsValid(html) and html:IsVisible() and address:GetValue() or ""
            if url ~= "" and CW.CheckURL(url) then gui.OpenURL(url) else desktop:Toast("Aucune page à ouvrir") end
        end):SetIcon("icon16/application_go.png")

        m:AddSpacer()
        m:AddOption("Diagnostic du moteur web…", function() desktop:OpenApp("settings", { page = "diag" }) end)
            :SetIcon("icon16/stethoscope.png")
        m:Open()
    end, RIGHT)

    -- Badge de filtrage
    if CW.CVars.filter:GetBool() then
        local badge = vgui.Create("DPanel", tb)
        badge:Dock(RIGHT)
        badge:SetWide(S(110))
        badge:DockMargin(0, S(3), S(6), S(3))
        badge.Paint = function(_, w, h)
            draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, UI.Alpha(UI.T.c.ok, 50))
            draw.SimpleText("Filtré", "CW.Small", w / 2, h / 2, UI.T.c.ok, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    address = UI.Entry(tb, "Rechercher ou saisir une adresse")
    address:Dock(FILL)
    address:DockMargin(S(4), 0, S(6), 0)
    address.OnEnter = function(self)
        navigate(self:GetValue())
    end

    ---------------------------------------------------------------------
    -- Corps : page d'accueil native + (plus tard) panneau web
    ---------------------------------------------------------------------
    body = vgui.Create("DPanel", content)
    body:Dock(FILL)
    body.Paint = function() end

    start = vgui.Create("DPanel", body)
    start:Dock(FILL)
    start.cwMessage = nil
    start.cwEngineName = (select(2, currentEngine()) or {}).name or "le web"

    local searchEntry, tiles

    start.Paint = function(self, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.window.r, c.window.g, c.window.b, 255)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("Rechercher", "CW.Huge", w / 2, S(46), c.windowText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("avec " .. (self.cwEngineName or "le web") .. (CW.CVars.safe:GetBool() and "  -  recherche protégée" or ""),
            "CW.Small", w / 2, S(82), c.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if self.cwMessage then
            draw.SimpleText(self.cwMessage, "CW.Body", w / 2, S(186), c.danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        draw.SimpleText("Un souci de chargement ? Menu ⋮ > Diagnostic du moteur web", "CW.Small",
            w / 2, h - S(16), c.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    searchEntry = UI.Entry(start, "Tapez votre recherche ou une adresse, puis Entrée")
    searchEntry:SetFont("CW.Title")
    searchEntry.OnEnter = function(self)
        local v = self:GetValue()
        self:SetText("")
        navigate(v)
    end

    tiles = vgui.Create("DIconLayout", start)
    tiles:SetSpaceX(S(14))
    tiles:SetSpaceY(S(14))
    local TW, TH = S(124), S(104)

    for _, tile in ipairs(CW.Config.HomeTiles or {}) do
        local b = vgui.Create("DButton", tiles)
        b:SetText("")
        b:SetSize(TW, TH)
        b.cwHover = 0
        b.Paint = function(self, w, h)
            local c = UI.T.c
            self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
            draw.RoundedBox(S(UI.T.radius + 4), 0, 0, w, h, UI.Mix(c.panel, c.panelHi, self.cwHover))
            local sz = S(52)
            draw.RoundedBox(S(12), (w - sz) / 2, S(10), sz, sz, tile.color or c.accent)
            draw.SimpleText(string.upper(string.sub(tile.name, 1, 1)), "CW.Tile", w / 2, S(10) + sz / 2,
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(tile.name, "CW.Small", w / 2, h - S(16), c.windowText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function() navigate(tile.url) end
    end

    start.OnSizeChanged = function(self, w, h)
        local ew = math.min(S(620), w - S(60))
        searchEntry:SetSize(ew, S(46))
        searchEntry:SetPos((w - ew) / 2, S(106))

        local n = #(CW.Config.HomeTiles or {})
        local cols = math.max(1, math.min(n, math.floor((w - S(40)) / (TW + S(14)))))
        local tw = cols * TW + (cols - 1) * S(14)
        tiles:SetSize(tw, h - S(230))
        tiles:SetPos((w - tw) / 2, S(214))
    end

    -- Appel initial / arguments (ex. depuis le terminal : browse <recherche>)
    win.OnAppArgs = function(_, a)
        if a and a.input then navigate(a.input) end
    end
    if args.input then
        timer.Simple(0, function() if IsValid(win) then navigate(args.input) end end)
    end

    win.OnWindowClose = function()
        if IsValid(html) then html:OpenURL("about:blank") end
    end

    searchEntry:RequestFocus()
    return win
end

OS.RegisterApp("browser", {
    name = "Navigateur", icon = "browser", order = 1, single = false,
    enabled = function() return CW.CVars.browser:GetBool() end,
    open = openBrowser,
})
