--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Musique"
      * radios / flux audio directs via sound.PlayURL (indépendant du moteur web)
      * favoris personnels (data/computerweb/users/<id>/favorites.json)
      * visualiseur FFT, volume, lecture auto de la piste suivante
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS
local OS = CW.OS

---------------------------------------------------------------------------
-- Moteur audio (partagé : la musique continue si la fenêtre est réduite)
---------------------------------------------------------------------------
CW.Audio = CW.Audio or { token = 0, status = "stopped", volume = 0.7 }
local Audio = CW.Audio

function Audio.Stop()
    Audio.token = Audio.token + 1
    if IsValid(Audio.channel) then Audio.channel:Stop() end
    Audio.channel = nil
    Audio.status = "stopped"
    Audio.err = nil
end

function Audio.SetVolume(v)
    Audio.volume = math.Clamp(v, 0, 1)
    if IsValid(Audio.channel) then Audio.channel:SetVolume(Audio.volume) end
end

--- station = { name, url, genre?, preset = true|false }
function Audio.Play(station)
    Audio.Stop()
    local ok, why = CW.CheckURL(station.url, { skipAllowlist = station.preset })
    if not ok then
        Audio.status, Audio.err, Audio.current = "error", why, station
        return
    end

    Audio.current = station
    Audio.status = "loading"
    local tok = Audio.token

    sound.PlayURL(station.url, "noplay", function(chan, code, err)
        if tok ~= Audio.token then
            if IsValid(chan) then chan:Stop() end
            return
        end
        if not IsValid(chan) then
            Audio.status = "error"
            Audio.err = (err and err ~= "") and err or ("Flux indisponible (code " .. tostring(code) .. ")")
            return
        end
        chan:SetVolume(Audio.volume)
        chan:Play()
        Audio.channel = chan
        Audio.status = "playing"
    end)
end

function Audio.TogglePause()
    local ch = Audio.channel
    if not IsValid(ch) then return end
    if Audio.status == "playing" then
        ch:Pause()
        Audio.status = "paused"
    elseif Audio.status == "paused" then
        ch:Play()
        Audio.status = "playing"
    end
end

---------------------------------------------------------------------------
-- Favoris
---------------------------------------------------------------------------
local Favs = {}
local function favPath() return FS.UserDir() .. "/favorites.json" end

function Favs.Load()
    local raw = file.Read(favPath(), "DATA")
    local t = raw and util.JSONToTable(raw)
    local out = {}
    if istable(t) then
        for _, f in ipairs(t) do
            if istable(f) and isstring(f.url) and isstring(f.name) and #out < 50 then
                out[#out + 1] = { name = f.name:sub(1, 48), url = f.url, genre = "Favori", preset = false }
            end
        end
    end
    return out
end

function Favs.Save(list)
    local clean = {}
    for _, f in ipairs(list) do clean[#clean + 1] = { name = f.name, url = f.url } end
    file.CreateDir(FS.UserDir())
    file.Write(favPath(), util.TableToJSON(clean))
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function openMusic(desktop)
    Audio.volume = math.Clamp(OS.CV.volume:GetFloat(), 0, 1)

    local win = UI.Window(desktop, {
        title = "Musique", icon = "music", app = "music",
        w = S(780), h = S(500), minW = S(560), minH = S(360),
    })
    local content = win:GetContent()

    local favs = Favs.Load()
    local stations = {}

    local function rebuildStations()
        stations = {}
        for _, r in ipairs(CW.Config.Radios or {}) do
            stations[#stations + 1] = { name = r.name, url = r.url, genre = r.genre or "Radio", preset = true }
        end
        for _, f in ipairs(favs) do stations[#stations + 1] = f end
    end
    rebuildStations()

    local list, urlEntry

    local function indexOf(st)
        for i, s2 in ipairs(stations) do
            if s2.url == st.url then return i end
        end
    end

    local function playIndex(i)
        if #stations == 0 then return end
        i = ((i - 1) % #stations) + 1
        Audio.Play(stations[i])
    end

    ---------------------------------------------------------------------
    -- Colonne de droite : lecteur
    ---------------------------------------------------------------------
    local player = vgui.Create("DPanel", content)
    player:Dock(RIGHT)
    player:SetWide(S(300))
    player:DockPadding(S(14), S(14), S(14), S(14))
    local fft = {}
    player.Paint = function(self, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(0, 0, 1, h)

        local st = Audio.current
        draw.SimpleText(st and st.name or "Aucune lecture", "CW.Title", w / 2, S(30), c.windowText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local label, col = "Arrêté", c.dim
        if Audio.status == "loading" then label, col = "Connexion…", c.accent
        elseif Audio.status == "playing" then label, col = "En lecture", c.ok
        elseif Audio.status == "paused" then label, col = "En pause", c.dim
        elseif Audio.status == "error" then label, col = Audio.err or "Erreur", c.danger end
        draw.SimpleText(label, "CW.Small", w / 2, S(54), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- visualiseur
        local vx, vy, vw, vh = S(14), S(76), w - S(28), S(120)
        draw.RoundedBox(S(UI.T.radius), vx, vy, vw, vh, c.input)
        local bars = 24
        local bw = (vw - S(16)) / bars
        local have = false
        if Audio.status == "playing" and IsValid(Audio.channel) then
            local okf, n = pcall(Audio.channel.FFT, Audio.channel, fft, FFT_256)
            have = okf and n and n > 0
        end
        for i = 1, bars do
            local v
            if have then
                v = math.min((fft[i * 2] or 0) * 6, 1)
            elseif Audio.status == "loading" then
                v = 0.1 + 0.08 * math.abs(math.sin(SysTime() * 3 + i * 0.5))
            else
                v = 0.03
            end
            local bh = math.max(S(3), (vh - S(12)) * v)
            draw.RoundedBox(S(2), vx + S(8) + (i - 1) * bw + 1, vy + vh - S(6) - bh, bw - 2, bh, UI.Mix(c.accent, c.accentHi, v))
        end
    end

    local btnRow = vgui.Create("DPanel", player)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(S(46))
    btnRow:DockMargin(0, S(8), 0, 0)
    btnRow.Paint = function() end

    local function transport(icon, tip, fn, kind)
        local b = UI.Button(btnRow, nil, icon, fn, kind)
        b:Dock(LEFT)
        b:SetWide(S(52))
        b:DockMargin(0, 0, S(6), 0)
        b:SetTooltip(tip)
        return b
    end

    local playBtn
    transport("prev", "Précédent", function()
        local i = Audio.current and indexOf(Audio.current) or 1
        playIndex((i or 1) - 1)
    end)
    playBtn = transport("play", "Lecture / pause", function()
        if Audio.status == "playing" or Audio.status == "paused" then
            Audio.TogglePause()
        elseif Audio.current then
            Audio.Play(Audio.current)
        else
            playIndex(1)
        end
    end, "accent")
    playBtn.Think = function(self)
        self.cwIcon = (Audio.status == "playing" or Audio.status == "loading") and "pause" or "play"
    end
    transport("stop", "Arrêter", function() Audio.Stop() end)
    transport("next", "Suivant", function()
        local i = Audio.current and indexOf(Audio.current) or 0
        playIndex((i or 0) + 1)
    end)

    local volRow = vgui.Create("DPanel", player)
    volRow:Dock(BOTTOM)
    volRow:SetTall(S(34))
    volRow.Paint = function(_, w, h)
        UI.DrawIcon("volume", 0, (h - S(20)) / 2, S(20), S(20), UI.T.c.dim)
        draw.SimpleText(math.floor(Audio.volume * 100) .. "%", "CW.Small", w, h / 2, UI.T.c.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    local slider = UI.Slider(volRow, Audio.volume, function(v)
        Audio.SetVolume(v)
        RunConsoleCommand("cw_volume", string.format("%.2f", v))
    end)
    slider:Dock(FILL)
    slider:DockMargin(S(26), 0, S(40), 0)

    ---------------------------------------------------------------------
    -- Colonne de gauche : liste + URL personnalisée
    ---------------------------------------------------------------------
    local left = vgui.Create("DPanel", content)
    left:Dock(FILL)
    left.Paint = function() end

    local addRow = vgui.Create("DPanel", left)
    addRow:Dock(BOTTOM)
    addRow:SetTall(S(50))
    addRow:DockPadding(S(8), S(8), S(8), S(8))
    addRow.Paint = function(_, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
        surface.DrawRect(0, 0, w, 1)
    end

    local function playURL(url)
        local ok, why = CW.CheckURL(url)
        if not ok then desktop:Toast(why or "Adresse refusée") return end
        Audio.Play({ name = url:gsub("^https?://", ""):sub(1, 40), url = url, genre = "URL", preset = false })
    end

    local favBtn = UI.Button(addRow, "★ Favori", nil, function()
        local url = CW.Trim(urlEntry:GetValue())
        local ok, why = CW.CheckURL(url)
        if not ok then desktop:Toast(why or "Adresse refusée") return end
        Derma_StringRequest("Ajouter aux favoris", "Nom de la station :", "", function(txt)
            txt = CW.Trim(txt)
            if txt == "" then return end
            favs[#favs + 1] = { name = txt:sub(1, 48), url = url, genre = "Favori", preset = false }
            Favs.Save(favs)
            rebuildStations()
            list.Rebuild()
        end)
    end)
    favBtn:Dock(RIGHT)
    favBtn:SetWide(S(96))
    favBtn:DockMargin(S(6), 0, 0, 0)

    local playUrlBtn = UI.Button(addRow, "Lire", "play", function()
        playURL(CW.Trim(urlEntry:GetValue()))
    end, "accent")
    playUrlBtn:Dock(RIGHT)
    playUrlBtn:SetWide(S(80))
    playUrlBtn:DockMargin(S(6), 0, 0, 0)

    urlEntry = UI.Entry(addRow, "Adresse d'un flux audio (https://…)")
    urlEntry:Dock(FILL)
    urlEntry.OnEnter = function(self) playURL(CW.Trim(self:GetValue())) end

    list = vgui.Create("DScrollPanel", left)
    list:Dock(FILL)
    list:DockMargin(S(6), S(6), S(6), S(6))
    list:GetVBar():SetWide(S(8))
    list:GetVBar().Paint = function() end
    list:GetVBar().btnUp.Paint = function() end
    list:GetVBar().btnDown.Paint = function() end
    list:GetVBar().btnGrip.Paint = function(_, w, h) draw.RoundedBox(S(4), 0, 0, w, h, UI.Alpha(UI.T.c.dim, 140)) end

    function list.Rebuild()
        list:Clear()
        for i, st in ipairs(stations) do
            local row = vgui.Create("DButton", list)
            row:SetText("")
            row:Dock(TOP)
            row:SetTall(S(46))
            row:DockMargin(0, 0, 0, S(3))
            row.cwHover = 0
            row.Paint = function(self, w, h)
                local c = UI.T.c
                self.cwHover = Lerp(math.min(FrameTime() * 14, 1), self.cwHover, self:IsHovered() and 1 or 0)
                local active = Audio.current and Audio.current.url == st.url and Audio.status ~= "stopped"
                if active then
                    draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, UI.Alpha(c.accent, 70))
                elseif self.cwHover > 0.01 then
                    draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, UI.Alpha(c.accent, math.floor(35 * self.cwHover)))
                end
                local isz = S(26)
                if active then
                    UI.DrawIcon("volume", S(10), (h - isz) / 2, isz, isz, c.accent)
                else
                    UI.DrawIcon("music", S(10), (h - isz) / 2, isz, isz)
                end
                draw.SimpleText(st.name, UI.T.mono and "CW.Mono" or "CW.Bold", S(48), h / 2 - S(8), c.windowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(st.genre or "", "CW.Small", S(48), h / 2 + S(10), c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function() playIndex(i) end
            if not st.preset then
                row.DoRightClick = function()
                    local m = DermaMenu()
                    m:AddOption("Retirer des favoris", function()
                        for k, f in ipairs(favs) do
                            if f.url == st.url then table.remove(favs, k) break end
                        end
                        Favs.Save(favs)
                        rebuildStations()
                        list.Rebuild()
                    end):SetIcon("icon16/delete.png")
                    m:Open()
                end
            end
        end
    end
    list.Rebuild()

    ---------------------------------------------------------------------
    -- Piste suivante automatique (fichiers finis)
    ---------------------------------------------------------------------
    win.Think = function(self)
        if Audio.status == "playing" and IsValid(Audio.channel) then
            if Audio.channel:GetState() == GMOD_CHANNEL_STOPPED then
                local i = Audio.current and indexOf(Audio.current) or 0
                if (self.cwNextAt or 0) < CurTime() then
                    self.cwNextAt = CurTime() + 2
                    playIndex((i or 0) + 1)
                end
            end
        end
    end

    -- Fermer la fenêtre = arrêter la musique
    win.OnWindowClose = function() Audio.Stop() end

    return win
end

OS.RegisterApp("music", {
    name = "Musique", icon = "music", order = 3, single = true,
    enabled = function() return CW.CVars.music:GetBool() end,
    open = openMusic,
})
