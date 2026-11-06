--[[----------------------------------------------------------------------------
    ComputerWeb - Télécommande des écrans 3D (touche E sur monitorMusic, ...)
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S

local remote

local function closeRemote()
    if IsValid(remote) then remote:Remove() end
    remote = nil
end

local function openRemote(ent)
    closeRemote()
    UI.RefreshScale()
    UI.SetTheme("sandbox")
    local c = UI.T.c

    local presets = CW.Config.ScreenPresets or {}
    local canCustom = IsValid(LocalPlayer()) and (LocalPlayer():IsAdmin() or CW.CVars.screenurl:GetBool())

    local w = S(460)
    local h = S(150) + #presets * S(44) + (canCustom and S(66) or 0) + S(56)
    h = math.min(h, ScrH() - S(80))

    local p = vgui.Create("DPanel")
    p:SetSize(w, h)
    p:Center()
    p:MakePopup()
    p:SetKeyboardInputEnabled(true)
    remote = p

    p.Paint = function(self, pw, ph)
        draw.RoundedBox(S(14), -2, -2, pw + 4, ph + 6, Color(0, 0, 0, 120))
        draw.RoundedBox(S(14), 0, 0, pw, ph, c.window)
        draw.RoundedBoxEx(S(14), 0, 0, pw, S(48), c.title, true, true, false, false)
        UI.DrawIcon("browser", S(14), S(12), S(24), S(24))
        draw.SimpleText("Télécommande de l'écran", "CW.Title", S(48), S(24), c.titleText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if IsValid(ent) then
            local url = ent:GetScreenURL()
            if #url > 62 then url = url:sub(1, 59) .. "..." end
            draw.SimpleText("En cours : " .. url, "CW.Small", S(16), S(62), c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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

    local y = S(80)
    local scroll = vgui.Create("DScrollPanel", p)
    scroll:SetPos(S(12), y)
    scroll:SetSize(w - S(24), #presets * S(44) > h - S(190) and h - S(190) or #presets * S(44))
    scroll:GetVBar():SetWide(S(6))

    for _, preset in ipairs(presets) do
        local b = UI.Button(scroll, preset.name, "play", function()
            net.Start("cw_screen_set")
                net.WriteEntity(ent)
                net.WriteString(preset.url)
            net.SendToServer()
        end)
        b:Dock(TOP)
        b:SetTall(S(38))
        b:DockMargin(0, 0, 0, S(6))
    end

    local bottom = vgui.Create("DPanel", p)
    bottom:Dock(BOTTOM)
    bottom:SetTall(canCustom and S(110) or S(52))
    bottom:DockPadding(S(12), S(8), S(12), S(8))
    bottom.Paint = function() end

    local mute = UI.Button(bottom, "", nil, function()
        if IsValid(ent) then ent.LocalMuted = not ent.LocalMuted end
    end)
    mute:Dock(BOTTOM)
    mute:SetTall(S(34))
    mute.Think = function(self)
        self.cwText = (IsValid(ent) and ent.LocalMuted) and "Son : coupé (pour moi)" or "Son : activé (pour moi)"
        self.cwIcon = "volume"
    end

    if canCustom then
        local row = vgui.Create("DPanel", bottom)
        row:Dock(BOTTOM)
        row:SetTall(S(38))
        row:DockMargin(0, 0, 0, S(8))
        row.Paint = function() end

        local entry = UI.Entry(row, "Adresse libre (https://…)")
        local send = UI.Button(row, "Afficher", nil, function()
            net.Start("cw_screen_set")
                net.WriteEntity(ent)
                net.WriteString(CW.Trim(entry:GetValue()))
            net.SendToServer()
        end, "accent")
        send:Dock(RIGHT)
        send:SetWide(S(100))
        send:DockMargin(S(6), 0, 0, 0)
        entry:Dock(FILL)
        entry.OnEnter = function(self) send:DoClick() end
    end
end

net.Receive("cw_screen_menu", function()
    local ent = net.ReadEntity()
    if IsValid(ent) then openRemote(ent) end
end)
