--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Paramètres"
      * Apparence (fond d'écran), Navigateur (moteur), Son
      * Diagnostic du moteur web : dit pourquoi YouTube / un site ne charge pas
      * À propos
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local OS = CW.OS

---------------------------------------------------------------------------
-- Diagnostic du moteur web
---------------------------------------------------------------------------
CW.Diag = CW.Diag or {}
local Diag = CW.Diag

local DIAG_JS = [[
(function () {
  try {
    var v = document.createElement('video'), a = document.createElement('audio');
    var gl = false;
    try { var c = document.createElement('canvas'); gl = !!(c.getContext('webgl') || c.getContext('experimental-webgl')); } catch (e) {}
    var r = {
      ua: navigator.userAgent,
      h264: v.canPlayType('video/mp4; codecs="avc1.42E01E"'),
      vp9:  v.canPlayType('video/webm; codecs="vp9"'),
      aac:  a.canPlayType('audio/mp4; codecs="mp4a.40.2"'),
      opus: a.canPlayType('audio/ogg; codecs="opus"'),
      mse:  !!window.MediaSource,
      webgl: gl
    };
    cwdiag.report(JSON.stringify(r));
  } catch (e) { cwdiag.report(JSON.stringify({ error: String(e) })); }
})();
]]

--- Analyse le résultat brut du test. Renvoie { rows = {{label, value, ok}}, verdict, level }
function Diag.Analyze(t)
    if not t or t.error then
        return {
            rows = {},
            level = "bad",
            verdict = "Le moteur web n'a pas répondu. Sous Linux/macOS, installez GModPatchTool (GitHub : solsticegamestudios/GModPatchTool) ; "
                .. "sur Windows, vérifiez que Garry's Mod est à jour et relancez-le.",
        }
    end

    local ua = tostring(t.ua or "")
    local engine, version = "Inconnu", ""
    if ua:find("Awesomium", 1, true) then
        engine = "Awesomium (ancien moteur)"
    elseif ua:match("Chrome/([%d%.]+)") then
        engine = "Chromium (CEF)"
        version = ua:match("Chrome/([%d%.]+)")
    end

    local function yes(v) return v == "probably" or v == "maybe" end
    local rows = {
        { "Moteur",                engine .. (version ~= "" and (" " .. version) or ""), engine ~= "Awesomium (ancien moteur)" },
        { "Vidéo H.264 (MP4)",     yes(t.h264) and "Oui" or "Non", yes(t.h264) },
        { "Vidéo VP9 (WebM)",      yes(t.vp9)  and "Oui" or "Non", yes(t.vp9) },
        { "Audio AAC",             yes(t.aac)  and "Oui" or "Non", yes(t.aac) },
        { "Audio Opus",            yes(t.opus) and "Oui" or "Non", yes(t.opus) },
        { "Media Source (YouTube)",t.mse and "Oui" or "Non", t.mse },
        { "WebGL",                 t.webgl and "Oui" or "Non", t.webgl },
    }

    local verdict, level
    if engine == "Awesomium (ancien moteur)" then
        verdict, level = "Ancien moteur détecté : la plupart des sites modernes et YouTube ne fonctionneront pas. "
            .. "Passez sur la branche x86-64 de Garry's Mod (Propriétés > Bêtas).", "bad"
    elseif not t.mse or (not yes(t.h264) and not yes(t.vp9)) then
        verdict, level = "La lecture vidéo (YouTube) risque d'échouer : codecs ou Media Source absents. "
            .. "GModPatchTool (GitHub : solsticegamestudios/GModPatchTool) met à jour CEF et active H.264/AAC.", "warn"
    elseif not yes(t.h264) then
        verdict, level = "Le moteur est correct, mais sans H.264 : certaines vidéos pourraient ne pas se lancer. GModPatchTool peut l'activer.", "warn"
    else
        verdict, level = "Tout est en ordre : le moteur web et les codecs nécessaires sont disponibles.", "ok"
    end
    return { rows = rows, verdict = verdict, level = level, ua = ua }
end

--- Lance le test dans un panneau web invisible (jamais exposé à un site distant).
function Diag.Run(parent, callback)
    local done = false
    local p = vgui.Create("DHTML", parent)
    p:SetSize(8, 8)
    p:SetPos(0, 0)
    p:SetAlpha(0)
    p:SetMouseInputEnabled(false)
    p:SetKeyboardInputEnabled(false)
    p:SetAllowLua(false)
    p.ConsoleMessage = function() end

    local function finish(result)
        if done then return end
        done = true
        callback(result)
        timer.Simple(0, function() if IsValid(p) then p:Remove() end end)
    end

    p:AddFunction("cwdiag", "report", function(json)
        local t = util.JSONToTable(tostring(json or "")) or { error = "réponse illisible" }
        finish(t)
    end)

    local ready = false
    p.OnDocumentReady = function(self)
        ready = true
        self:QueueJavascript(DIAG_JS)
    end
    p:SetHTML("<!DOCTYPE html><html><body>ComputerWeb</body></html>")

    -- Deuxième tentative puis abandon
    timer.Simple(2, function()
        if not done and IsValid(p) and ready then p:QueueJavascript(DIAG_JS) end
    end)
    timer.Simple(6, function() finish(nil) end)
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local PAGES = {
    { "look",  "Apparence"  },
    { "color", "Couleurs"   },
    { "desk",  "Bureau"     },
    { "web",   "Navigateur" },
    { "sound", "Son"        },
    { "diag",  "Diagnostic web" },
    { "about", "À propos"   },
}

local function openSettings(desktop, args)
    local win = UI.Window(desktop, {
        title = "Paramètres", icon = "settings", app = "settings",
        w = S(780), h = S(520), minW = S(600), minH = S(400),
    })
    local content = win:GetContent()

    local nav = vgui.Create("DPanel", content)
    nav:Dock(LEFT)
    nav:SetWide(S(180))
    nav:DockPadding(S(8), S(8), S(8), S(8))
    nav.Paint = function(_, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(w - 1, 0, 1, h)
    end

    local page = vgui.Create("DPanel", content)
    page:Dock(FILL)
    page:DockPadding(S(18), S(14), S(18), S(14))
    page.Paint = function() end

    local current

    local function heading(parent, text)
        local l = UI.Label(parent, text, "CW.Title")
        l:Dock(TOP)
        l:SetTall(S(34))
        return l
    end

    local function paragraph(parent, text, tall, colorKey)
        local l = UI.Label(parent, text, "CW.Body", colorKey or "dim")
        l:Dock(TOP)
        l:SetWrap(true)
        l:SetAutoStretchVertical(true)
        l:DockMargin(0, 0, 0, S(8))
        return l
    end

    local builders = {}

    ---------------------------------------------------------------------
    builders.look = function(p)
        heading(p, "Fond d'écran")
        paragraph(p, "Choisissez le fond d'écran de vos ordinateurs (enregistré sur votre PC).")
        local grid = vgui.Create("DIconLayout", p)
        grid:Dock(TOP)
        grid:SetTall(S(260))
        grid:SetSpaceX(S(12))
        grid:SetSpaceY(S(12))
        local cur = OS.CV.wallpaper:GetString()
        local function thumb(name, label)
            local b = vgui.Create("DButton", grid)
            b:SetText("")
            b:SetSize(S(190), S(128))
            b.Paint = function(self, w, h)
                local c = UI.T.c
                local active = OS.CV.wallpaper:GetString() == name
                draw.RoundedBox(S(8), 0, 0, w, h, active and c.accent or c.border)
                surface.SetMaterial(UI.Wallpaper(name ~= "" and name or UI.T.wallpaper))
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(3, 3, w - 6, h - 6)
                draw.RoundedBox(0, 3, h - S(26), w - 6, S(23), Color(0, 0, 0, 150))
                draw.SimpleText(label, "CW.Small", w / 2, h - S(14), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function() RunConsoleCommand("cw_wallpaper", name) end
        end
        thumb("", "Thème (défaut)")
        for _, name in ipairs(UI.Wallpapers) do
            thumb(name, name:sub(1, 1):upper() .. name:sub(2))
        end
    end

    ---------------------------------------------------------------------
    -- Couleur du système (accent) : appliquée en direct, enregistrée après 0.5 s
    ---------------------------------------------------------------------
    local PRESETS = {
        { "Bleu", 46, 125, 240 }, { "Cyan", 0, 175, 215 }, { "Turquoise", 0, 150, 136 }, { "Vert", 60, 170, 100 },
        { "Citron", 140, 190, 40 }, { "Jaune", 240, 190, 30 }, { "Orange", 238, 110, 50 }, { "Rouge", 214, 64, 64 },
        { "Rose", 232, 80, 150 }, { "Violet", 130, 80, 210 }, { "Ardoise", 110, 120, 140 },
    }

    builders.color = function(p)
        heading(p, "Couleur du système")
        paragraph(p, "Change la couleur d'accent (boutons, barres de titre, sélection) de tous vos ordinateurs. Appliqué immédiatement.")

        local dirty
        p.Think = function(self)
            if dirty and SysTime() - dirty > 0.5 then
                dirty = nil
                RunConsoleCommand("cw_accent", UI.AccentOverride or "")
            end
        end
        local function setColor(str)
            UI.SetAccent(str)
            dirty = SysTime()
        end

        local grid = vgui.Create("DIconLayout", p)
        grid:Dock(TOP)
        grid:SetTall(S(120))
        grid:SetSpaceX(S(10))
        grid:SetSpaceY(S(10))
        local function swatch(label, r, g, b)
            local btn = vgui.Create("DButton", grid)
            btn:SetText("")
            btn:SetSize(S(100), S(50))
            btn.Paint = function(self, w, h)
                local c = UI.T.c
                local cur = UI.GetAccent()
                local active = (r == nil and cur == nil) or (cur and r and cur.r == r and cur.g == g and cur.b == b)
                if UI.T.bevel then
                    UI.Bevel(0, 0, w, h, not active, c.panel)
                    if r then
                        surface.SetDrawColor(r, g, b, 255)
                        surface.DrawRect(S(6), S(6), S(24), h - S(12))
                    end
                    draw.SimpleText(label, "CW.Small", r and S(36) or w / 2, h / 2, c.windowText, r and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    return
                end
                draw.RoundedBox(S(8), 0, 0, w, h, active and c.windowText or c.border)
                draw.RoundedBox(S(7), 2, 2, w - 4, h - 4, r and Color(r, g, b) or c.panel)
                local lum = r and (r * 0.299 + g * 0.587 + b * 0.114) or 0
                draw.SimpleText(label, "CW.Small", w / 2, h / 2, (r and lum < 150) and color_white or ((r and Color(20, 20, 24)) or c.windowText),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function()
                setColor(r and string.format("%d %d %d", r, g, b) or "")
            end
        end
        swatch("Thème (défaut)")
        for _, pr in ipairs(PRESETS) do swatch(pr[1], pr[2], pr[3], pr[4]) end

        paragraph(p, "Couleur personnalisée (rouge / vert / bleu) :")
        local cur = UI.GetAccent() or UI.Base.c.accent
        local rgb = { cur.r, cur.g, cur.b }
        for i, name in ipairs({ "Rouge", "Vert", "Bleu" }) do
            local row = vgui.Create("DPanel", p)
            row:Dock(TOP)
            row:SetTall(S(34))
            row.Paint = function(_, w, h)
                draw.SimpleText(name, "CW.Body", 0, h / 2, UI.T.c.windowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(rgb[i]), "CW.Bold", w, h / 2, UI.T.c.windowText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local sl = UI.Slider(row, rgb[i] / 255, function(v)
                rgb[i] = math.floor(v * 255 + 0.5)
                setColor(string.format("%d %d %d", rgb[1], rgb[2], rgb[3]))
            end)
            sl:Dock(FILL)
            sl:DockMargin(S(70), 0, S(50), 0)
        end
    end

    ---------------------------------------------------------------------
    -- Bureau : raccourcis
    ---------------------------------------------------------------------
    builders.desk = function(p)
        local SC = CW.Shortcuts
        heading(p, "Raccourcis du bureau")
        paragraph(p, "Ajoutez des raccourcis vers une application, un site web ou un fichier. Ils s'affichent sur le bureau (clic droit sur un raccourci pour le supprimer).")

        local add = UI.Button(p, "Nouveau raccourci...", "newfile", function()
            if SC then SC.OpenDialog(desktop) end
        end, "accent")
        add:Dock(TOP)
        add:SetTall(S(38))
        add:DockMargin(0, 0, 0, S(10))

        local list = vgui.Create("DScrollPanel", p)
        list:Dock(FILL)

        local function build()
            list:Clear()
            local items = SC and SC.List or {}
            if #items == 0 then
                local l = UI.Label(list, "Aucun raccourci pour le moment.", "CW.Body", "dim")
                l:Dock(TOP)
                l:SetTall(S(30))
            end
            for i, e in ipairs(items) do
                local row = vgui.Create("DPanel", list)
                row:Dock(TOP)
                row:SetTall(S(46))
                row:DockMargin(0, 0, S(6), S(4))
                row.Paint = function(_, w, h)
                    local c = UI.T.c
                    if UI.T.bevel then UI.Bevel(0, 0, w, h, true, c.panel)
                    else draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, c.panel) end
                    UI.DrawIcon(e.icon, S(8), (h - S(30)) / 2, S(30), S(30), UI.ColorIcons[e.icon] and color_white or c.windowText)
                    draw.SimpleText(e.label, "CW.Bold", S(48), h / 2 - S(8), c.windowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local kind = (e.type == "app" and "Application : " or e.type == "url" and "Site : " or "Fichier : ") .. (e.app or e.url or e.path)
                    draw.SimpleText(kind, "CW.Small", S(48), h / 2 + S(9), c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                local del = UI.Button(row, nil, "trash", function()
                    SC.Remove(i)
                    if desktop.BuildDesktopIcons then desktop:BuildDesktopIcons() end
                    build()
                end, "danger")
                del:Dock(RIGHT)
                del:SetWide(S(40))
                del:DockMargin(0, S(5), S(6), S(5))
            end
        end
        build()
        desktop.OnShortcutsChanged = function() if IsValid(list) then build() end end
    end

    ---------------------------------------------------------------------
    builders.web = function(p)
        heading(p, "Navigateur")
        paragraph(p, "Moteur de recherche utilisé par la barre d'adresse et la page d'accueil.")
        local current = OS.CV.engine:GetString()
        if not (CW.Config.SearchEngines or {})[current] then current = CW.Config.DefaultSearchEngine end
        for key, eng in SortedPairs(CW.Config.SearchEngines or {}) do
            local b = UI.Button(p, eng.name, nil, function() RunConsoleCommand("cw_search_engine", key) end)
            b:Dock(TOP)
            b:SetTall(S(38))
            b:DockMargin(0, 0, 0, S(6))
            b.Think = function(self)
                local cur = OS.CV.engine:GetString()
                if not (CW.Config.SearchEngines or {})[cur] then cur = CW.Config.DefaultSearchEngine end
                self.cwKind = (cur == key) and "accent" or "flat"
            end
        end
        paragraph(p, "Recherche protégée : " .. (CW.CVars.safe:GetBool() and "activée" or "désactivée")
            .. "  -  Filtrage des sites : " .. (CW.CVars.filter:GetBool() and "liste blanche" or "libre")
            .. "  (réglé par l'administrateur du serveur)")
    end

    ---------------------------------------------------------------------
    builders.sound = function(p)
        heading(p, "Son")
        paragraph(p, "Volume de l'application Musique.")
        local row = vgui.Create("DPanel", p)
        row:Dock(TOP)
        row:SetTall(S(40))
        row.Paint = function(_, w, h)
            draw.SimpleText(math.floor(OS.CV.volume:GetFloat() * 100) .. "%", "CW.Bold", w, h / 2, UI.T.c.windowText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        local sl = UI.Slider(row, OS.CV.volume:GetFloat(), function(v)
            RunConsoleCommand("cw_volume", string.format("%.2f", v))
            if CW.Audio then CW.Audio.SetVolume(v) end
        end)
        sl:Dock(FILL)
        sl:DockMargin(0, 0, S(60), 0)

        local c24 = UI.Button(p, "", nil, function()
            RunConsoleCommand("cw_clock24", OS.CV.clock24:GetBool() and "0" or "1")
        end)
        c24:Dock(TOP)
        c24:SetTall(S(38))
        c24:DockMargin(0, S(14), 0, 0)
        c24.Think = function(self) self.cwText = "Horloge : " .. (OS.CV.clock24:GetBool() and "24 heures" or "12 heures") end
    end

    ---------------------------------------------------------------------
    builders.diag = function(p)
        heading(p, "Diagnostic du moteur web")
        paragraph(p, "Teste le navigateur intégré de Garry's Mod (moteur, codecs vidéo) pour expliquer pourquoi une page ou YouTube ne s'affiche pas.")

        local result, verdict
        local running = false

        -- Bouton (TOP) d'abord, panneau de résultat (FILL) ensuite : ordre de docking
        local btn = UI.Button(p, "Lancer le diagnostic", "search", function()
            if running then return end
            running, result = true, nil
            Diag.Run(page, function(t)
                running = false
                result = Diag.Analyze(t)
                if IsValid(verdict) then
                    verdict:SetText(result.verdict)
                    verdict.cwColorKey = result.level == "ok" and "ok" or (result.level == "warn" and "windowText" or "danger")
                end
            end)
        end, "accent")
        btn:Dock(TOP)
        btn:SetTall(S(40))
        btn:DockMargin(0, 0, 0, S(12))

        local resultPanel = vgui.Create("DPanel", p)
        resultPanel:Dock(FILL)
        resultPanel.Paint = function(self, w, h)
            local c = UI.T.c
            if running then
                draw.SimpleText("Test en cours…", "CW.Body", S(4), S(10), c.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                return
            end
            if not result then
                draw.SimpleText("Cliquez sur « Lancer le diagnostic ».", "CW.Body", S(4), S(10), c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                return
            end
            local y = S(4)
            for _, row in ipairs(result.rows) do
                UI.Circle(S(12), y + S(11), S(6), row[3] and c.ok or c.danger, 16)
                draw.SimpleText(row[1], "CW.Body", S(30), y + S(11), c.windowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(row[2], "CW.Bold", S(260), y + S(11), c.windowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                y = y + S(26)
            end
            self.cwVerdictY = y + S(8)
        end

        verdict = UI.Label(resultPanel, "", "CW.Body", "windowText")
        verdict:SetWrap(true)
        verdict:SetAutoStretchVertical(true)
        verdict:SetVisible(false)

        resultPanel.Think = function(self)
            if result and self.cwVerdictY and not running then
                verdict:SetVisible(true)
                verdict:SetPos(S(4), self.cwVerdictY)
                verdict:SetWide(self:GetWide() - S(8))
            else
                verdict:SetVisible(false)
            end
        end
    end

    ---------------------------------------------------------------------
    builders.about = function(p)
        heading(p, "ComputerWeb " .. CW.Version)
        paragraph(p, "Des ordinateurs jouables pour Garry's Mod : navigateur, fichiers, bloc-notes, musique, terminal.")
        paragraph(p, "Auteur : FilleuxStudio (didifx60). Projet communautaire et open source.", nil, "windowText")
        paragraph(p, "Les noms de sites affichés (YouTube, Wikipédia, Steam…) appartiennent à leurs propriétaires respectifs. "
            .. "Cet add-on est indépendant et n'est pas affilié à Facepunch Studios ni à Valve.")
        paragraph(p, "Système actuel : " .. (UI.T.os or "?") .. "  -  écran " .. ScrW() .. "x" .. ScrH())
    end

    ---------------------------------------------------------------------
    local navButtons = {}
    local function show(id)
        current = id
        page:Clear()
        local b = builders[id]
        if b then b(page) end
    end

    for _, pg in ipairs(PAGES) do
        local b = UI.Button(nav, pg[2], nil, function() show(pg[1]) end)
        b:Dock(TOP)
        b:SetTall(S(36))
        b:DockMargin(0, 0, 0, S(4))
        b.Think = function(self) self.cwKind = (current == pg[1]) and "accent" or "flat" end
        navButtons[#navButtons + 1] = b
    end

    win.OnAppArgs = function(_, a)
        if a and a.page and builders[a.page] then show(a.page) end
    end

    show((args and args.page and builders[args.page]) and args.page or "look")
    return win
end

OS.RegisterApp("settings", {
    name = "Paramètres", icon = "settings", order = 90, single = true,
    open = openSettings,
})
