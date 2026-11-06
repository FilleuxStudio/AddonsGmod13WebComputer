AddCSLuaFile()

-- Radio interactive : touche E = télécommande (station, marche/arrêt).
--   * l'état (allumée + station) est synchronisé serveur -> tous les clients
--   * chaque joueur proche entend le flux en 3D (volume selon la distance)
--   * la liste des stations est CW.Config.Radios (config.lua)
-- Le modèle est celui de la radio du jeu de base (aucun modèle tiers).

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Radio interactive"
ENT.Author      = "FilleuxStudio"
ENT.Category    = "ComputerWeb"
ENT.Spawnable   = true
ENT.AdminOnly   = false
ENT.Instructions = "Appuyez sur E pour changer de station."
ENT.IconOverride = "entities/cw_radio.png"

ENT.CWKind  = "radio"
ENT.CWModel = "models/props_lab/citizenradio.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "On")
    self:NetworkVar("Int", 0, "Station")
end

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.CWModel)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetStation(1)
        self:SetOn(false)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator, caller)
        local ply = IsValid(caller) and caller or activator
        if IsValid(ply) and ply:IsPlayer() then
            ComputerWeb.OpenRadioMenu(ply, self)
        end
    end

else -- CLIENT

    local CW = ComputerWeb
    CW.RadioEnts = CW.RadioEnts or {}

    local FADE_MIN, FADE_MAX = 120, 900

    function CW.RadioVolume()
        local cv = CW.CVars.radiovol
        return cv and math.Clamp(cv:GetFloat(), 0, 1) or 0.8
    end

    function ENT:Initialize()
        self.Channel = nil
        self.LoadedStation = nil
        self.LoadToken = 0
        self.NextCheck = 0
        CW.RadioEnts[self] = true
    end

    function ENT:StopAudio()
        self.LoadToken = (self.LoadToken or 0) + 1       -- invalide les chargements en cours
        if IsValid(self.Channel) then self.Channel:Stop() end
        self.Channel, self.LoadedStation = nil, nil
    end

    function ENT:StartAudio(station)
        local radio = (CW.Config.Radios or {})[station]
        if not radio then return end
        local url = radio.url
        if not CW.CheckURL(url, { skipAllowlist = true }) then return end

        self:StopAudio()
        self.LoadedStation = station
        local token = self.LoadToken
        sound.PlayURL(url, "3d mono", function(ch, errID, errName)
            -- le callback arrive plus tard : l'entité a pu changer de station ou disparaître
            if not IsValid(self) or self.LoadToken ~= token then
                if IsValid(ch) then ch:Stop() end
                return
            end
            if not IsValid(ch) then
                self.LoadedStation = nil
                self.NextCheck = CurTime() + 8      -- ne réessaie pas en boucle
                return
            end
            ch:SetPos(self:GetPos())
            ch:Set3DFadeDistance(FADE_MIN, FADE_MAX)
            ch:SetVolume(CW.RadioVolume())
            ch:Play()
            self.Channel = ch
        end)
    end

    function ENT:Think()
        if IsValid(self.Channel) then
            self.Channel:SetPos(self:GetPos())
        end

        local now = CurTime()
        if now < self.NextCheck then return end
        self.NextCheck = now + 0.4

        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local near = lp:GetPos():Distance(self:GetPos()) <= FADE_MAX + 100
        local station = self:GetStation()
        if not self:GetOn() or not near or station < 1 or station > #(CW.Config.Radios or {}) then
            if self.Channel or self.LoadedStation then self:StopAudio() end
            return
        end

        if self.LoadedStation ~= station then
            self:StartAudio(station)
        elseif IsValid(self.Channel) then
            self.Channel:SetVolume(CW.RadioVolume())
        end
    end

    function ENT:Draw()
        self:DrawModel()
    end

    function ENT:OnRemove()
        CW.RadioEnts[self] = nil
        self:StopAudio()
    end

    -- Petit texte au-dessus des radios allumées proches
    hook.Add("HUDPaint", "ComputerWeb_RadioHUD", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local me = lp:GetPos()
        for ent in pairs(CW.RadioEnts) do
            if IsValid(ent) and ent:GetOn() and me:Distance(ent:GetPos()) < 350 then
                local radio = (CW.Config.Radios or {})[ent:GetStation()]
                if radio then
                    local sp = (ent:GetPos() + Vector(0, 0, 22)):ToScreen()
                    if sp.visible then
                        draw.SimpleText("Radio : " .. radio.name, "CW.Bold", sp.x + 1, sp.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText("Radio : " .. radio.name, "CW.Bold", sp.x, sp.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end
    end)

end
