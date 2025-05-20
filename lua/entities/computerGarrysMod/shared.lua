ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "COMPUTER-COMBINE"
ENT.Author = "didifx60"
ENT.Category = "Ordinateur-WEB"
ENT.Instructions = "Appuyez sur E (Touche 'USE')"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.AutomaticFrameAdvance = true

function ENT:SetAutomaticFrameAdvance(bUsingAnim)
    self.AutomaticFrameAdvance = bUsingAnim
end
