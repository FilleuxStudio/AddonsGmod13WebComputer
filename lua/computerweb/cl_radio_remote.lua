--[[----------------------------------------------------------------------------
    ComputerWeb - Télécommande de la radio 3D (touche E sur l'entité cw_radio)
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S

CW.CVars.radiovol = CW.CVars.radiovol or CreateClientConVar("cw_radio_volume", "0.8", true, false,
    "Volume des radios 3D pour vous (0 à 1)")

local remote

local function closeRemote()
    if IsValid(remote) then remote:Remove() end
    remote = nil
end

local function send(ent, station, on)
    net.Start("cw_radio_set")
        net.WriteEntity(ent)
        net.WriteUInt(station, 8)
        net.WriteBool(on)
    net.SendToServer()
end

local function openRemote(ent)
    closeRemote()
    UI.RefreshScale()
    UI.SetTheme("sandbox")
    local c = UI.T.c

    local radios = CW.Config.Radios or {}
    local w = S(440)
    local h = math.min(S(210) + #radios * S(44), ScrH() - S(80))

    local p = vgui.Create("DPanel")
    p:SetSize(w, h)
    p:Center()
    p:MakePopup()
    remote = p

    p.Paint = function(self, pw, ph)
        draw.RoundedBox(S(14), -2, -2, pw + 4, ph + 6, Color(0, 0, 0, 120))
        draw.RoundedBox(S(14), 0, 0, pw, ph, c.window)
        draw.RoundedBoxEx(S(14), 0, 0, pw, S(48), c.title, true, true, false, false)
        UI.DrawIcon("music", S(14), S(12), S(24), S(24))
        draw.SimpleText("Radio", "CW.Title", S(48), S(24), c.titleText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if IsValid(ent) then
            local r = radios[ent:GetStation()]
            local txt = (ent:GetOn() and r) and ("En écoute : " .. r.name .. "  (" .. (r.genre or "") .. ")") or "Éteinte"
            draw.SimpleText(txt, "CW.Small", S(16), S(64), ent:GetOn() and c.ok or c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    p.Think = function(self)
        if not IsValid(ent) or not IsValid(LocalPlayer()) or LocalPlayer():GetPos():Distance(ent:GetPos()) > 300 then
            closeRemote()
        end
    end

    local close = UI.Button(p, nil, "close", closeRemote, "ghost")
    close:SetPos(w - S(44), S(8))
    close:SetSize(S(32), S(32))

    -- Bas : volume local + marche/arrêt
    local bottom = vgui.Create("DPanel", p)
    bottom:Dock(BOTTOM)
    bottom:SetTall(S(104))
    bottom:DockPadding(S(12), S(8), S(12), S(8))
    bottom.Paint = function() end

    local power = UI.Button(bottom, "", "power", function()
        if IsValid(ent) then send(ent, math.max(ent:GetStation(), 1), not ent:GetOn()) end
    end)
    power:Dock(BOTTOM)
    power:SetTall(S(36))
    power.Think = function(self)
        local on = IsValid(ent) and ent:GetOn()
        self.cwText = on and "Éteindre la radio" or "Allumer la radio"
        self.cwKind = on and "danger" or "accent"
    end

    local volRow = vgui.Create("DPanel", bottom)
    volRow:Dock(BOTTOM)
    volRow:SetTall(S(36))
    volRow:DockMargin(0, 0, 0, S(6))
    volRow.Paint = function(_, rw, rh)
        draw.SimpleText("Volume (pour moi)", "CW.Small", 0, rh / 2, c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(math.floor(CW.RadioVolume() * 100) .. "%", "CW.Bold", rw, rh / 2, c.windowText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    local sl = UI.Slider(volRow, CW.RadioVolume(), function(v)
        RunConsoleCommand("cw_radio_volume", string.format("%.2f", v))
        -- applique tout de suite (le convar ne change qu'à l'image suivante)
        if IsValid(ent) and IsValid(ent.Channel) then ent.Channel:SetVolume(v) end
    end)
    sl:Dock(FILL)
    sl:DockMargin(S(130), 0, S(50), 0)

    -- Stations
    local scroll = vgui.Create("DScrollPanel", p)
    scroll:Dock(FILL)
    scroll:DockMargin(S(12), S(80), S(12), S(4))
    scroll:GetVBar():SetWide(S(6))
    for i, r in ipairs(radios) do
        local b = UI.Button(scroll, r.name .. "  -  " .. (r.genre or ""), "play", function()
            if IsValid(ent) then send(ent, i, true) end
        end)
        b:Dock(TOP)
        b:SetTall(S(38))
        b:DockMargin(0, 0, 0, S(6))
        b.Think = function(self)
            self.cwKind = (IsValid(ent) and ent:GetOn() and ent:GetStation() == i) and "accent" or "flat"
        end
    end
end

net.Receive("cw_radio_menu", function()
    local ent = net.ReadEntity()
    if IsValid(ent) then openRemote(ent) end
end)
