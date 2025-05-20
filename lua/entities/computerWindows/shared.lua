ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName     = "Windows 7 GMOD"
ENT.Author        = "didifx60"
ENT.Category      = "Ordinateur-WEB"
--ENT.Contact       = "N/A"
--ENT.Purpose       = "N/A"
ENT.Instructions  = "Appyer sur E (Touche 'USE')" 
ENT.Spawnable = true 
ENT.AdminSpawnable = true
ENT.AutomaticFrameAdvance = true

function ENT:SetAutomaticFrameAdvance(bUsingAnim)
       self.AutomaticFrameAdvance = bUsingAnim
end