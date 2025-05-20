include('shared.lua')
include('cl_initColor')

function computerWindows ( ply ) 

chat.AddText(Color(0,255,128), "Windows 7 GMOD... :",Color(254,254,254), "...Open...Connect...") -- text chat 
chat.AddText(Color(0,255,128), "Windows 7 GMOD... :",Color(254,254,254), "...software...hardware...OK.")
-- DRrame principal
local windowsPc = vgui.Create("DFrame") -- DFrame Princila
 windowsPc:SetTitle("Windows 7 GMOD")
 windowsPc:SetSize(1200, 650)
 windowsPc:Center()
 windowsPc:MakePopup()
 function  windowsPc:Paint( w, h )
	-- largeur longuer, texW - width, texH - height // style de fond 
	local texW = 1200
	local texH = 650
   
	surface.SetMaterial( Material( "materials/img/fontWindows.jpg", "noclamp" ) ) -- "Texture rechercher dans le dossier"
	surface.SetDrawColor( color_white ) -- Color RBG
	surface.DrawTexturedRectUV( 0, 0, w, h, 0, 0, w / texW, h / texH )
end
-- sound de démarrage 
 sound.PlayFile( "sound/windows7Startup.mp3", "models/props_lab/monitor02.mdl", function( station )
	if ( IsValid( station ) ) then station:Play() end
end )

local BarWindows = vgui.Create("DPanel", windowsPc)
BarWindows:SetSize(1215, 40)
BarWindows:Dock(BOTTOM)
BarWindows:SetBackgroundColor(ColorGreen)

local buttonW = vgui.Create("DButton", BarWindows) -- Button de Windows 7
buttonW:SetSize( 42, 42 ) -- taille
buttonW:SetPos(0, 0) -- Position
buttonW:SetText("")
buttonW.Paint = function()
		surface.SetMaterial(Material("materials/img/InputW.png")) -- icon
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,buttonW:GetWide(),buttonW:GetTall())
end
buttonW.DoClick = function()

local PanelW = vgui.Create( "DFrame", windowsPc )
PanelW:SetTitle( "Démarage" )
PanelW:SetSize(320, 400)
PanelW:Dock(LEFT)
-- dans cette DFrame on place un button.
local GUI_Main_Exit = vgui.Create("DButton", PanelW)
GUI_Main_Exit:SetSize(32,32)
GUI_Main_Exit:Dock(BOTTOM)
GUI_Main_Exit:SetText("")
GUI_Main_Exit.Paint = function()
	surface.SetMaterial(Material("img/inputclose2.png"))
	surface.SetDrawColor(255,255,255,255)
	surface.DrawTexturedRect(0,0,GUI_Main_Exit:GetWide(),GUI_Main_Exit:GetTall())
GUI_Main_Exit.DoClick = function ()
windowsPc:Close()
end
end

end -- fin de la function buttonW 

local buttonPC = vgui.Create( "DButton", windowsPc )
buttonPC:SetSize( 32, 32 )
buttonPC:SetPos(25, 50)
buttonPC:SetText("")
buttonPC.Paint = function()
		surface.SetMaterial(Material("materials/img/IconPC.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,buttonPC:GetWide(),buttonPC:GetTall())
end
buttonPC.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "Documents" )
frame:SetSize(1000, 500)
frame:Center()

------------------------------------------------------------------

local MenuBar = vgui.Create( "DMenuBar", frame ) -- petit menu pour selection. 
MenuBar:DockMargin( -3, -6, -3, 0 ) 

local M1 = MenuBar:AddMenu( "File" )
M1:AddOption( "New", function() Msg( "Chose File:New\n" ) end ):SetIcon( "icon16/page_white_go.png" )
M1:AddOption( "Open", function() Msg( "Chose File:Open\n" ) end ):SetIcon( "icon16/folder_go.png" )

local M2 = MenuBar:AddMenu( "Edit" )
M2:AddOption( "writing pad", function() 

local DPanel = vgui.Create( "DFrame", frame) 
DPanel:SetTitle("")
DPanel:Center()
DPanel:SetSize( 250, 250 ) 
DPanel:MakePopup()

local DLabel = vgui.Create( "DLabel", DPanel )
DLabel:SetPos(10, 25)
DLabel:SetText( "Texte" ) 
DLabel:SizeToContents() 
DLabel:SetDark( 1 )

local TextEntry = vgui.Create( "DTextEntry", DPanel)
TextEntry:SetPos(25, 40)
TextEntry:SetSize( 200, 200)
TextEntry:SetText( "édit:" )
TextEntry.OnEnter = function( self )
chat.AddText( self:GetValue() )	
end

end ):SetIcon("html/img/news.png")

local M3 = MenuBar:AddMenu( "Help" )
M3:AddOption( "About", function() 

local DPanel = vgui.Create( "DFrame", frame) 
DPanel:SetTitle("About")
DPanel:Center()
DPanel:SetSize( 400, 400 ) 
DPanel:MakePopup()

local img = vgui.Create( "DImage", DPanel )	
img:SetPos( 8, 30 )	
img:SetSize( 64, 64 )	
img:SetImage( "materials/img/iconi.png" )

local DLabel1 = vgui.Create( "DLabel", DPanel )
DLabel1:SetPos(82, 26)
DLabel1:SetText( "FR: En cours de développement des mise a jour bientôt.\n\nEN: During development of the update soon." )  
DLabel1:SizeToContents() 
DLabel1:SetDark( 1 )
end ):SetIcon("html/img/upload.png")

end

-----------------------------------------------------------------------------------


local buttonNet = vgui.Create( "DButton", windowsPc )
buttonNet:SetSize( 32, 32 )
buttonNet:SetPos(25, 150)
buttonNet:SetText( "" )
buttonNet.Paint = function()
		surface.SetMaterial(Material("materials/img/Google.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,buttonNet:GetWide(),buttonNet:GetTall())
end
buttonNet.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "Internet" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.google.fr/?gfe_rd=cr&ei=NkjMV7PrLM7w8Aem7oCwDw")
end


local button0 = vgui.Create( "DButton", windowsPc )
button0:SetSize( 64, 64 )
button0:SetPos(25, 250)
button0:SetText( "" )
button0.Paint = function()
		surface.SetMaterial(Material("materials/img/icongeek.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,button0:GetWide(),button0:GetTall())
end
button0.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "Geek" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "www.journaldugeek.com/")
end



end

usermessage.Hook("computerWindows", computerWindows)

hook.Add("PostDrawOpaqueRenderables", "computerWindows", function()
    for _, ent in pairs (ents.FindByClass("computerWindows")) do
	if ent:GetPos():Distance(LocalPlayer():GetPos()) < 1000 then
	  
	   
end
end 
end)
