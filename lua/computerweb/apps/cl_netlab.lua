--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Réseau" (système Cipher)
      * scanne les ordinateurs, écrans et radios posés dans la scène
      * ping (latence calculée d'après la distance), ports, intrusion SIMULÉE
      * 100 % cosmétique : aucune requête réseau réelle, aucune action sur les cibles.
        Les serveurs RP peuvent écouter le hook serveur ComputerWeb_HackSimulated.
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local OS = CW.OS

CW.Net = CW.Net or {}
local Net = CW.Net

Net.MaxRange = 2500        -- unités Source (~48 m)
Net.MaxTargets = 40

local KIND_NAME = { pc = "Ordinateur", screen = "Écran web", radio = "Radio" }
local PORTS = {
    pc     = { { 22, "ssh" }, { 80, "http" }, { 443, "https" } },
    screen = { { 80, "http" }, { 554, "rtsp" } },
    radio  = { { 8000, "icecast" } },
}

---------------------------------------------------------------------------
-- Modèle de données (pur, testé hors jeu)
---------------------------------------------------------------------------
function Net.KindName(kind) return KIND_NAME[kind] or "Appareil" end
function Net.Ports(kind) return PORTS[kind] or {} end

--- Adresse IP fictive et stable (192.168.x.y) dérivée de l'index de l'entité.
function Net.IP(ent)
    local idx = ent:EntIndex()
    return string.format("192.168.%d.%d", 10 + (idx * 7) % 40, 10 + idx % 200)
end

function Net.Host(ent)
    return string.format("%s-%d", tostring(ent.CWTheme or ent.CWKind or "hote"), ent:EntIndex())
end

function Net.Meters(dist) return dist / 52.5 end

--- Appareils ComputerWeb proches du joueur, du plus proche au plus lointain.
function Net.Targets()
    local out = {}
    local lp = LocalPlayer()
    if not IsValid(lp) then return out end
    local pos = lp:GetPos()
    for _, e in ipairs(ents.GetAll()) do
        if IsValid(e) and e.CWKind then
            local d = pos:Distance(e:GetPos())
            if d <= Net.MaxRange then
                out[#out + 1] = {
                    ent = e, kind = e.CWKind, ip = Net.IP(e), host = Net.Host(e), dist = d,
                    ports = Net.Ports(e.CWKind),
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    while #out > Net.MaxTargets do out[#out] = nil end
    return out
end

--- Retrouve une cible par IP, nom d'hôte ou numéro d'entité.
function Net.Resolve(text, list)
    text = CW.Trim(tostring(text or "")):lower()
    if text == "" then return nil end
    for _, t in ipairs(list) do
        if t.ip == text or t.host:lower() == text or tostring(t.ent:EntIndex()) == text:gsub("^#", "") then return t end
    end
    return nil
end

function Net.Latency(dist)
    return 0.5 + dist / 70 + math.random() * 1.2
end

--- Lignes d'un ping (4 paquets) : { {texte, genre}, ... }
function Net.PingLines(t, count)
    count = count or 4
    local lines = { { string.format("PING %s (%s) : 56 octets de données", t.host, t.ip) } }
    local sum, minv, maxv = 0, math.huge, 0
    for i = 1, count do
        local ms = Net.Latency(t.dist)
        sum, minv, maxv = sum + ms, math.min(minv, ms), math.max(maxv, ms)
        lines[#lines + 1] = { string.format("64 octets de %s : icmp_seq=%d ttl=64 temps=%.2f ms", t.ip, i, ms) }
    end
    lines[#lines + 1] = { string.format("--- %d paquets émis, %d reçus, 0%% de perte ; min/moy/max = %.2f/%.2f/%.2f ms",
        count, count, minv, sum / count, maxv), "dim" }
    return lines
end

--- Script d'intrusion fictif : { {délai, texte, genre}, ... }
function Net.HackScript(t)
    local L = {
        { 0.3, string.format("[*] Cible : %s (%s)", t.host, t.ip) },
        { 0.5, "[*] Résolution de l'hôte... OK" },
        { 0.7, "[*] Scan des ports :" },
    }
    for _, p in ipairs(t.ports) do
        L[#L + 1] = { 0.25, string.format("      %d/tcp  ouvert  %s", p[1], p[2]), "accent" }
    end
    L[#L + 1] = { 0.8, "[*] Recherche de failles (simulation)..." }
    L[#L + 1] = { 0.9, "[+] Faille fictive CVE-0000-0000 détectée", "ok" }
    for _, pct in ipairs({ 25, 50, 75, 100 }) do
        L[#L + 1] = { 0.6, string.format("[*] Dictionnaire : %3d%%  [%s%s]", pct, string.rep("#", pct / 5), string.rep(".", 20 - pct / 5)) }
    end
    L[#L + 1] = { 0.7, "[+] ACCÈS ACCORDÉ (simulation)", "ok" }
    L[#L + 1] = { 0.4, "[i] Aucune donnée n'a été touchée : tout ceci est un jeu.", "dim" }
    return L
end

--- Joue un script ligne par ligne. alive() : false => on s'arrête ; done() : à la fin.
function Net.RunScript(lines, out, alive, done)
    local i = 0
    local function nextLine()
        i = i + 1
        local l = lines[i]
        if not l then
            if done then done() end
            return
        end
        timer.Simple(l[1], function()
            if alive and not alive() then return end
            out(l[2], l[3])
            nextLine()
        end)
    end
    nextLine()
end

--- Prévient le serveur qu'une intrusion simulée est terminée (hook RP, optionnel).
function Net.Notify(t)
    if not t or not IsValid(t.ent) then return end
    net.Start("cw_hack_done")
        net.WriteEntity(t.ent)
    net.SendToServer()
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function openNetlab(desktop, args)
    local win = UI.Window(desktop, {
        title = "Réseau", icon = "netlab", app = "netlab",
        w = S(880), h = S(540), minW = S(660), minH = S(380),
    })
    local content = win:GetContent()
    local targets, selected = {}, nil
    local lines, busy = {}, false
    local listPanel, rebuildList

    local function log(text, kind)
        lines[#lines + 1] = { tostring(text), kind }
        if #lines > 300 then table.remove(lines, 1) end
    end
    local function alive() return IsValid(win) end

    -- Console (à droite) ---------------------------------------------------
    local console = vgui.Create("DPanel", content)
    console:Dock(FILL)
    console:DockMargin(0, S(4), S(4), S(4))
    console.Paint = function(_, w, h)
        local c = UI.T.c
        if UI.T.bevel then UI.Bevel(0, 0, w, h, false, Color(0, 0, 0)) else
            draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, Color(4, 8, 12))
        end
        local lh = S(17)
        local n = math.max(1, math.floor((h - S(12)) / lh))
        local first = math.max(1, #lines - n + 1)
        local y = S(8)
        for i = first, #lines do
            local ln = lines[i]
            local col = (ln[2] == "ok" and c.ok) or (ln[2] == "err" and c.danger) or (ln[2] == "dim" and Color(120, 150, 140))
                or (ln[2] == "accent" and c.accent) or Color(190, 255, 220)
            draw.SimpleText(ln[1], "CW.MonoSmall", S(10), y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + lh
        end
    end

    -- Liste des cibles (à gauche) ------------------------------------------
    local left = vgui.Create("DPanel", content)
    left:Dock(LEFT)
    left:SetWide(S(290))
    left:DockPadding(S(6), S(6), S(6), S(6))
    left.Paint = function(_, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local head = UI.Label(left, "Appareils détectés", "CW.Bold")
    head:Dock(TOP)
    head:SetTall(S(24))

    listPanel = vgui.Create("DScrollPanel", left)
    listPanel:Dock(FILL)

    function rebuildList()
        listPanel:Clear()
        for _, t in ipairs(targets) do
            local label = string.format("%s  -  %.0f m", t.host, Net.Meters(t.dist))
            local b = UI.Button(listPanel, label, nil, function() selected = t end)
            b:Dock(TOP)
            b:SetTall(S(34))
            b:DockMargin(0, 0, 0, S(4))
            b.Think = function(self) self.cwKind = (selected == t) and "accent" or "flat" end
            b:SetTooltip(t.ip .. " - " .. Net.KindName(t.kind))
        end
        if #targets == 0 then
            local l = UI.Label(listPanel, "Aucun appareil à portée.", "CW.Small", "dim")
            l:Dock(TOP)
            l:SetTall(S(30))
        end
    end

    -- Actions ---------------------------------------------------------------
    local function guard()
        if busy then log("[!] Une action est déjà en cours...", "err") return false end
        return true
    end

    local function scan()
        if not guard() then return end
        busy = true
        targets, selected = Net.Targets(), nil
        rebuildList()
        local script = { { 0.1, "$ netscan --local" }, { 0.3, "[*] Balayage du réseau local..." } }
        for _, t in ipairs(targets) do
            script[#script + 1] = { 0.12, string.format("  %-15s %-16s %-11s %4.0f m", t.ip, t.host, Net.KindName(t.kind), Net.Meters(t.dist)) }
        end
        script[#script + 1] = { 0.2, string.format("[+] %d appareil(s) détecté(s)", #targets), "ok" }
        Net.RunScript(script, log, alive, function() busy = false end)
    end

    local function need()
        if not selected then log("[!] Sélectionnez d'abord un appareil dans la liste.", "err") return false end
        if not IsValid(selected.ent) then log("[!] Cet appareil a disparu : relancez un scan.", "err") return false end
        return true
    end

    local function ping()
        if not guard() or not need() then return end
        busy = true
        local script = { { 0.1, "$ ping -c 4 " .. selected.ip, nil } }
        for _, l in ipairs(Net.PingLines(selected, 4)) do script[#script + 1] = { 0.35, l[1], l[2] } end
        Net.RunScript(script, log, alive, function() busy = false end)
    end

    local function ports()
        if not guard() or not need() then return end
        busy = true
        local script = { { 0.1, "$ nmap " .. selected.ip }, { 0.5, "[*] Ports ouverts sur " .. selected.host .. " :" } }
        for _, p in ipairs(selected.ports) do
            script[#script + 1] = { 0.25, string.format("      %d/tcp  ouvert  %s", p[1], p[2]), "accent" }
        end
        Net.RunScript(script, log, alive, function() busy = false end)
    end

    local function intrude()
        if not guard() or not need() then return end
        busy = true
        local target = selected
        local script = Net.HackScript(target)
        table.insert(script, 1, { 0.1, "$ exploit --simulation " .. target.ip })
        Net.RunScript(script, log, alive, function()
            busy = false
            Net.Notify(target)
            if desktop and desktop.Toast then desktop:Toast("Intrusion simulée terminée") end
        end)
    end

    local tb = vgui.Create("DPanel", content)
    tb:Dock(TOP)
    tb:SetTall(S(44))
    tb:DockPadding(S(6), S(6), S(6), S(6))
    tb.Paint = function(_, w, h)
        local c = UI.T.c.panel
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(0, 0, w, h)
    end
    local function tbBtn(text, icon, fn, wide, kind)
        local b = UI.Button(tb, text, icon, fn, kind)
        b:Dock(LEFT)
        b:SetWide(wide)
        b:DockMargin(0, 0, S(6), 0)
        return b
    end
    tbBtn("Scanner", "search", scan, S(116), "accent")
    tbBtn("Ping", "reload", ping, S(88))
    tbBtn("Ports", "menu", ports, S(92))
    tbBtn("Intrusion (simulation)", "power", intrude, S(236), "danger")

    log("ComputerWeb Réseau - outil d'ambiance : tout est simulé, rien n'est envoyé sur Internet.", "dim")
    timer.Simple(0, function() if IsValid(win) then scan() end end)
    win.OnAppArgs = function() end
    return win
end

OS.RegisterApp("netlab", {
    name = "Réseau", icon = "netlab", order = 40, single = true, themes = { "cipher" },
    open = openNetlab,
})
