--[[----------------------------------------------------------------------------
    ComputerWeb - Serveur
      * messages réseau
      * ouverture d'un ordinateur / d'une télécommande d'écran
      * changement d'URL d'un écran 3D (validé côté serveur)
------------------------------------------------------------------------------]]

local CW = ComputerWeb

util.AddNetworkString("cw_os_open")        -- serveur -> client : ouvre le bureau
util.AddNetworkString("cw_screen_menu")    -- serveur -> client : ouvre la télécommande
util.AddNetworkString("cw_screen_set")     -- client -> serveur : change l'URL d'un écran
util.AddNetworkString("cw_radio_menu")     -- serveur -> client : ouvre la télécommande de la radio
util.AddNetworkString("cw_radio_set")      -- client -> serveur : station / marche-arrêt de la radio
util.AddNetworkString("cw_hack_done")      -- client -> serveur : intrusion SIMULÉE terminée (hook RP)

local lastAction = {}   -- anti-spam par joueur

local function cooldown(ply, key, delay)
    local id = ply:EntIndex() .. "|" .. key
    local now = CurTime()
    if (lastAction[id] or 0) > now then return false end
    lastAction[id] = now + delay
    return true
end

--- Appelé par les entités quand un joueur appuie sur E.
function CW.OpenComputer(ply, ent)
    if not CW.CanUseComputer(ply, ent) then return end
    if not cooldown(ply, "open", 0.75) then return end

    net.Start("cw_os_open")
        net.WriteEntity(ent)
    net.Send(ply)
end

function CW.OpenScreenMenu(ply, ent)
    if not CW.CanUseComputer(ply, ent) then return end
    if not cooldown(ply, "menu", 0.5) then return end

    net.Start("cw_screen_menu")
        net.WriteEntity(ent)
    net.Send(ply)
end

function CW.OpenRadioMenu(ply, ent)
    if not CW.CanUseComputer(ply, ent) then return end
    if not cooldown(ply, "radiomenu", 0.5) then return end

    net.Start("cw_radio_menu")
        net.WriteEntity(ent)
    net.Send(ply)
end

net.Receive("cw_radio_set", function(_, ply)
    if not IsValid(ply) then return end

    local ent = net.ReadEntity()
    local station = net.ReadUInt(8)
    local on = net.ReadBool()

    if not IsValid(ent) or ent.CWKind ~= "radio" then return end
    if not CW.CanUseComputer(ply, ent) then return end
    if not cooldown(ply, "radioset", 0.4) then return end

    local n = #(CW.Config.Radios or {})
    if n == 0 then return end
    if station < 1 or station > n then return end

    ent:SetStation(station)
    ent:SetOn(on)
end)

-- Intrusion simulée (outil Réseau du thème Cipher) : purement cosmétique, mais les serveurs RP
-- peuvent s'y brancher : hook.Add("ComputerWeb_HackSimulated", "x", function(ply, ent) ... end)
net.Receive("cw_hack_done", function(_, ply)
    if not IsValid(ply) then return end

    local ent = net.ReadEntity()
    if not IsValid(ent) or not ent.CWKind then return end
    if ply:GetPos():Distance(ent:GetPos()) > 3000 then return end
    if not cooldown(ply, "hack", 8) then return end

    hook.Run("ComputerWeb_HackSimulated", ply, ent)
end)

net.Receive("cw_screen_set", function(_, ply)
    if not IsValid(ply) then return end

    local ent = net.ReadEntity()
    local url = CW.Trim(net.ReadString())

    if not IsValid(ent) or not ent.IsComputerWebScreen then return end
    if not CW.CanUseComputer(ply, ent) then return end
    if not cooldown(ply, "screenset", 1.5) then return end
    if #url > 512 then return end

    -- URL libre : réservée aux admins sauf si cw_screen_custom_url = 1.
    -- Les URLs de la liste `ScreenPresets` sont ouvertes à tous.
    local isPreset = false
    for _, p in ipairs(CW.Config.ScreenPresets or {}) do
        if p.url == url then isPreset = true break end
    end
    if not isPreset and not (ply:IsAdmin() or CW.CVars.screenurl:GetBool()) then
        ply:ChatPrint("[ComputerWeb] Seuls les administrateurs peuvent saisir une adresse libre.")
        return
    end

    local ok, why = CW.CheckURL(url, { skipAllowlist = isPreset })
    if not ok then
        ply:ChatPrint("[ComputerWeb] Adresse refusée : " .. tostring(why))
        return
    end

    ent:SetScreenURL(url)
end)

hook.Add("PlayerDisconnected", "ComputerWeb_Cleanup", function(ply)
    local prefix = ply:EntIndex() .. "|"
    for k in pairs(lastAction) do
        if k:sub(1, #prefix) == prefix then lastAction[k] = nil end
    end
end)
