AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

function ENT:Initialize()

    self:SetModel("models/props_combine/combine_intmonitor001.mdl")
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:DrawShadow( true )

	
end
	


function ENT:AcceptInput ( Name, Activator, Caller )
     
	 if Name == "Use" and Caller:IsPlayer() then 
	 
	  umsg.Start("PC3", Caller)
	  umsg.End()
	 
    end
end