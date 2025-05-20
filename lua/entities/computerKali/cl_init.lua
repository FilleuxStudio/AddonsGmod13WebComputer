include('shared.lua')

function PC3( ply ) 


chat.AddText(Color(0,0,0), "Terminal... :",Color(0,123,255), "...Open...Connect...")
chat.AddText(Color(0,0,0), "Terminal... :",Color(0,123,255), "...software...hardware...PRET.")
chat.AddText(Color(0,0,0), "Terminal... :",Color(0,123,255), "...Connect...Server...OK.")


local windowsPc = vgui.Create("DFrame")
 windowsPc:SetTitle("Terminal")
 windowsPc:SetSize(1000, 600)
 windowsPc:Center()
 windowsPc:MakePopup()
 windowsPc:SetVisible(true)
 windowsPc.Paint = function()
draw.RoundedBox( 8, 0, 0, windowsPc:GetWide(), windowsPc:GetTall(), Color( 0, 0, 0, 200 ) )
end

local windows1 = vgui.Create("DFrame")
 windows1:SetTitle("Documents")
 windows1:SetSize(250, 600)
 windows1:AlignLeft( 10 )
 windows1:AlignTop(10)
 windows1:MakePopup()
 windows1:SetVisible(true)
 windows1:SetDraggable(false)
 windows1.Paint = function()
draw.RoundedBox( 8, 0, 0, windows1:GetWide(), windows1:GetTall(), Color( 121, 201, 234, 235 ) )
end

local windows2 = vgui.Create("DFrame")
 windows2:SetTitle("Vidéo")
 windows2:SetSize(250, 600)
 windows2:AlignRight( 10 )
 windows2:AlignTop(10)
 windows2:MakePopup()
 windows2:SetVisible(true)
 windows2:SetDraggable(false)
 windows2.Paint = function()
draw.RoundedBox( 8, 0, 0, windows2:GetWide(), windows2:GetTall(), Color(121, 201, 234, 235 ) )
end


 sound.PlayFile( "sound/soundcombine.mp3", "models/props_combine/combine_intmonitor001.mdl", function( station )
	if ( IsValid( station ) ) then station:Play() end
end )




function  windowsPc:Paint( w, h )
	-- largeur longuer, texW - width, texH - height
	local texW = 1000
	local texH = 600

	surface.SetMaterial( Material( "img/imgmenu04.jpg", "noclamp" ) )
	surface.SetDrawColor( color_white )
	surface.DrawTexturedRectUV( 0, 0, w, h, 0, 0, w / texW, h / texH )
end

	 local GUI_Main_Exit = vgui.Create("DButton", windowsPc)
	GUI_Main_Exit:SetSize(36,36)
	GUI_Main_Exit:SetPos(5, 560)
	GUI_Main_Exit:SetText("")
	GUI_Main_Exit.Paint = function()
		surface.SetMaterial(Material("img/inputclose.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,GUI_Main_Exit:GetWide(),GUI_Main_Exit:GetTall())
	GUI_Main_Exit.DoClick = function ()
windowsPc:Close()
windows1:Close()
windows2:Close()
	end
	end


local button = vgui.Create( "DButton", windows2 )
button:SetSize( 45, 45 )
button:SetPos(50,50)
button:SetText( "N°1" )
button.DoClick = function()
local frame = vgui.Create( "DFrame")
frame:SetTitle( "N°1" )
frame:SetSize(1000,500)
frame:Center()
frame:MakePopup()

	local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.youtube.com/watch?v=vXoJI2AkSBo" )
end


local button1 = vgui.Create( "DButton", windows2 )
button1:SetSize( 45, 45 )
button1:SetPos(50,110)
button1:SetText( "N°2" )
button1.DoClick = function()
local frame = vgui.Create( "DFrame")
frame:SetTitle( "N°2" )
frame:SetSize(1000,500)
frame:Center()
frame:MakePopup()

	local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.youtube.com/watch?v=cxVKech_xKU" )
end

local button2 = vgui.Create( "DButton", windows2 )
button2:SetSize( 45, 45 )
button2:SetPos(50,169)
button2:SetText( "N°3" )
button2.DoClick = function()
local frame = vgui.Create( "DFrame")
frame:SetTitle( "N°3" )
frame:SetSize(1000,500)
frame:Center()
frame:MakePopup()

	local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.youtube.com/watch?v=HLL9d34sg3Y" )
end

local button3 = vgui.Create( "DButton", windows2 )
button3:SetSize( 45, 45 )
button3:SetPos(50,230)
button3:SetText( "N°4" )
button3.DoClick = function()
local frame = vgui.Create( "DFrame")
frame:SetTitle( "N°4" )
frame:SetSize(1000,500)
frame:Center()
frame:MakePopup()

	local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.youtube.com/watch?v=o_3t40p8ky8" )
end

local button4 = vgui.Create( "DButton", windows2 )
button4:SetSize( 45, 45 )
button4:SetPos(50,290)
button4:SetText( "N°5" )
button4.DoClick = function()
local frame = vgui.Create( "DFrame")
frame:SetTitle( "N°5" )
frame:SetSize(1000,500)
frame:Center()
frame:MakePopup()

	local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.youtube.com/watch?v=c6TvN5Cgdjo" )
end

local button11 = vgui.Create( "DButton", windowsPc )
button11:SetSize( 68, 68 )
button11:SetPos(25, 89)
button11:SetText( "" )
button11.Paint = function()
		surface.SetMaterial(Material("materials/img/iconfolder.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,button:GetWide(),button:GetTall())
end
button11.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "Data" )
frame:SetSize(1000, 500)
frame:Center()
end

local button0 = vgui.Create( "DButton", windowsPc )
button0:SetSize( 50, 50 )
button0:SetPos(25, 150)
button0:SetText( "" )
button0.Paint = function()
		surface.SetMaterial(Material("materials/img/inputchrome.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,button0:GetWide(),button0:GetTall())
end
button0.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "Internet" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.google.fr/?gfe_rd=cr&ei=LlPVV6TbOOnt8wf25IvgAQ")
end

local button01 = vgui.Create( "DButton", windowsPc )
button01:SetSize( 50, 50 )
button01:SetPos(25, 220)
button01:SetText( "" )
button01.Paint = function()
		surface.SetMaterial(Material("materials/img/camera.png"))
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(0,0,button01:GetWide(),button01:GetTall())
end
button01.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "Photo" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.google.fr/search?q=combine+gmod&espv=2&biw=1600&bih=775&source=lnms&tbm=isch&sa=X&ved=0ahUKEwjhwY7IrofPAhUBXRoKHdpIBTkQ_AUIBigB&dpr=1")
end

TextFrame = vgui.Create( "DFrame", windows1 )
TextFrame:SetSize( 200, 500 )
TextFrame:Center()
TextFrame:SetTitle( "#ServerBrowser_ServerWarningTitle" )
TextFrame:MakePopup()

local richtext = vgui.Create( "RichText", TextFrame )
richtext:Dock( FILL )

richtext:InsertColorChange( 255, 255, 192, 255 )
richtext:AppendText( "#ServerBrowser_ServerWarning_MaxPlayers" )

function richtext:PerformLayout()

	self:SetFontInternal( "Trebuchet18" )
	self:SetBGColor( Color( 64, 64, 84 ) )

end



end

usermessage.Hook("PC3", PC3)

hook.Add("PostDrawOpaqueRenderables", "PC3", function()
    for _, ent in pairs (ents.FindByClass("pc3")) do
	if ent:GetPos():Distance(LocalPlayer():GetPos()) < 1000 then
	  
	   
end
end 
end)
