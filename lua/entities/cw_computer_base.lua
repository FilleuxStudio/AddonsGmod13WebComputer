AddCSLuaFile()

-- Entité de base de tous les ordinateurs ComputerWeb.
-- Les ordinateurs "réels" (computerWindows, computerUbuntu, ...) ne font
-- que choisir un thème, un modèle et un nom : voir les fichiers voisins.

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Ordinateur (base)"
ENT.Author      = "FilleuxStudio"
ENT.Category    = "ComputerWeb"
ENT.Spawnable   = false
ENT.AdminOnly   = false
ENT.Instructions = "Appuyez sur E pour utiliser l'ordinateur."

ENT.CWKind  = "pc"          -- type d'appareil (outil Réseau du thème Cipher)
ENT.CWTheme = "nova"
ENT.CWModel = "models/props_lab/monitor02.mdl"

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.CWModel)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:DrawShadow(true)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator, caller)
        local ply = IsValid(caller) and caller or activator
        if IsValid(ply) and ply:IsPlayer() then
            ComputerWeb.OpenComputer(ply, self)
        end
    end

else

    function ENT:Draw()
        self:DrawModel()
    end

end
