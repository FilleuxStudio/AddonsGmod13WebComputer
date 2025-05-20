AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName     = "Monitor Youtube-Music-Two"
ENT.Author        = "didifx60"
ENT.Category      = "Ordinateur-WEB"
--ENT.Contact       = "N/A"
--ENT.Purpose       = "N/A"
ENT.Instructions  = "..."
ENT.Spawnable = true 
ENT.AdminSpawnable = true


if ( CLIENT ) then
	ENT.Mat = nil
	ENT.Panel = nil
end

function ENT:Initialize()

	if ( SERVER ) then

		self:SetModel( "models/props_phx/rt_screen.mdl" )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:Freeze()

	else

		-- Réinitialiser matériel et panneau et charger panneau DHTML.
		self.Mat = nil
		self.Panel = nil
		self:OpenPage()

	end

end

function ENT:Freeze()
	local phys = self:GetPhysicsObject()
	if ( IsValid( phys ) ) then phys:EnableMotion( false ) end
end

-- Chargez le panneau de référence DHTML.
function ENT:OpenPage()

   chat.AddText(Color(0,0,0), "ScreenMusic... :",Color(205,45,45), "...Connect...")
   chat.AddText(Color(0,0,0), "ScreenMusic... :",Color(205,45,45),"...")
   chat.AddText(Color(0,0,0), "ScreenMusic... :",Color(205,45,45),"...")
   chat.AddText(Color(0,0,0), "ScreenMusic... :",Color(205,45,45), "...Wait please...OK...OK...PRET.")

	-- Iff pour une raison quelconque un panneau est déjà chargé , supprimez-le.
	if ( self.Panel ) then

		self.Panel:Remove()
		self.Panel = nil

	end

	-- Créer un panneau de page Web et de remplir tout l'écran.
	self.Panel = vgui.Create( "DHTML" )
	self.Panel:Dock( FILL )

	--  page URL.
	local url = "https://www.youtube.com/watch?v=DGNewPg2FDI"

	-- Chargez la page.
	self.Panel:OpenURL( url )

	-- Masquer le panneau.
	self.Panel:SetAlpha( 0 )
	self.Panel:SetMouseInputEnabled( false )

	-- Désactiver les messages HTML.
	function self.Panel:ConsoleMessage( msg ) end

end

function ENT:Draw()

	-- Iff le matériau a déjà été saisi à partir du panneau.
	if ( self.Mat ) then

		-- Apply it to the screen/model.
		if ( render.MaterialOverrideByIndex ) then
			render.MaterialOverrideByIndex( 1, self.Mat )
		else
			render.ModelMaterialOverride( self.Mat )
		end

	-- Sinon , vérifiez que le panneau est valide et le matériau de HTML est fini de charger.
	elseif ( self.Panel && self.Panel:GetHTMLMaterial() ) then

		-- Obtenez le matériau html.
		local html_mat = self.Panel:GetHTMLMaterial()

		--Utilisé pour rendre le matériel adapter à l'écran du modèle.
       --Peut être nécessaire de modifier ssi en utilisant un modèle différent.

		local scale_x, scale_y = ScrW()/2048, ScrH()/1024

		-- Créer un nouveau matériau à la mise à l'échelle et shader appropriée.
		local matdata =
		{
			["$basetexture"]=html_mat:GetName(),
			["$basetexturetransform"]="center 0 0 scale "..scale_x.." "..scale_y.." rotate 0 translate 0 0",
			["$model"]=1
		}

		--  ID unique utilisé pour nom de la matière.
		local uid = string.Replace( html_mat:GetName(), "__vgui_texture_", "" )

		-- Créer le matériau de modèle.
		self.Mat = CreateMaterial( "WebMaterial_"..uid, "VertexLitGeneric", matdata )

	end

	-- Rendu le modèle.
	self:DrawModel()

	--Réinitialiser le remplacement matériel ou autre tout aura un matériau de HTML.
	render.ModelMaterialOverride( nil )

end

function ENT:OnRemove()
	-- Assurez-vous que le panneau est retiré trop.
	if ( self.Panel ) then self.Panel:Remove() end
end