include('shared.lua')

function PC( ply ) 

chat.AddText(Color(0,0,0), "pc1000... :",Color(0,174,0), "...Open...Connect...")
chat.AddText(Color(0,0,0), "pc1000... :",Color(0,174,0), "...software...hardware...PRET.")

local windowsPc = vgui.Create("DFrame")
 windowsPc:SetTitle("PC1000FX")
 windowsPc:SetSize(1200, 650)
 windowsPc:Center()
 windowsPc:MakePopup()
 windowsPc:SetVisible(true)
 windowsPc.Paint = function()
draw.RoundedBox( 8, 0, 0, windowsPc:GetWide(), windowsPc:GetTall(), Color( 0, 0, 0, 200 ) )
end

 sound.PlayFile( "sound/windows95.mp3", "models/props_lab/monitor01a.mdl", function( station )
	if ( IsValid( station ) ) then station:Play() end
end )

local button = vgui.Create( "DButton", windowsPc )
button:SetSize( 36, 36 )
button:SetPos(25, 100)
button:SetText( "" )
button.Paint = function()
		surface.SetMaterial(Material("materials/img/google.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,button:GetWide(),button:GetTall())
end
button.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.google.fr/?gws_rd=ssl" )

end

local button1 = vgui.Create( "DButton", windowsPc )
button1:SetSize( 36, 36 )
button1:SetPos(25, 200)
button1:SetText( "" )
button1.Paint = function()
		surface.SetMaterial(Material("materials/img/steam.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,button1:GetWide(),button1:GetTall())
end
button1.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "http://store.steampowered.com/?l=french" )

end

local button2 = vgui.Create( "DButton", windowsPc )
button2:SetSize( 36, 36 )
button2:SetPos(25, 300)
button2:SetText( "" )
button2.Paint = function()
		surface.SetMaterial(Material("materials/img/email.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,button2:GetWide(),button2:GetTall())
end
button2.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://mail.google.com/" )



end

local button3 = vgui.Create( "DButton", windowsPc )
button3:SetSize( 38, 38 )
button3:SetPos(25, 400)
button3:SetText( "" )
button3.Paint = function()
		surface.SetMaterial(Material("materials/img/youtube.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,button3:GetWide(),button3:GetTall())
end
button3.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://www.youtube.com/?hl=fr&gl=FR" )
end


local button4 = vgui.Create( "DButton", windowsPc )
button4:SetSize( 38, 38 )
button4:SetPos(85, 100)
button4:SetText( "" )
button4.Paint = function()
		surface.SetMaterial(Material("materials/img/gmod13.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,button4:GetWide(),button4:GetTall())
end
button4.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "http://www.garrysmod.com/" )
end

local button5 = vgui.Create( "DButton", windowsPc )
button5:SetSize( 38, 38 )
button5:SetPos(85, 200)
button5:SetText( "" )
button5.Paint = function()
		surface.SetMaterial(Material("materials/img/iconfb.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,button5:GetWide(),button5:GetTall())
end
button5.DoClick = function()

local frame = vgui.Create( "DFrame", windowsPc )
frame:SetTitle( "" )
frame:SetSize(1000, 500)
frame:Center()

local html = vgui.Create( "HTML", frame )
html:Dock( FILL )
html:OpenURL( "https://fr-fr.facebook.com/" )
end

--[[ local html = vgui.Create("DHTML", windowsPc)
 html:SetSize(1000, 450)
 html:Center()

 local ctrls = vgui.Create( "DHTMLControls", windowsPc) -- Navigation controls
ctrls:SetWide( 1000)
ctrls:SetPos( 97, 4 )
ctrls:SetHTML( html ) -- accrocher panel windowsPc
ctrls.AddressBar:SetText( "google.com" ) --lien html

html:MoveBelow(ctrls)
html:OpenURL("google.com")
--]]

function  windowsPc:Paint( w, h )
	-- largeur longuer, texW - width, texH - height
	local texW = 1200
	local texH = 650

	surface.SetMaterial( Material( "img/imgmenu01.jpg", "noclamp" ) )
	surface.SetDrawColor( color_white )
	surface.DrawTexturedRectUV( 0, 0, w, h, 0, 0, w / texW, h / texH )
end

	 local GUI_Main_Exit = vgui.Create("DButton", windowsPc)
	GUI_Main_Exit:SetSize(32,32)
	GUI_Main_Exit:SetPos(3, 615)
	GUI_Main_Exit:SetText("")
	GUI_Main_Exit.Paint = function()
		surface.SetMaterial(Material("img/inputclose1.png"))
		surface.SetDrawColor(255,255,255,200)
		surface.DrawTexturedRect(0,0,GUI_Main_Exit:GetWide(),GUI_Main_Exit:GetTall())
	GUI_Main_Exit.DoClick = function ()
windowsPc:Close()
	end
	end


end

usermessage.Hook("PC", PC)

hook.Add("PostDrawOpaqueRenderables", "PC", function()
    for _, ent in pairs (ents.FindByClass("pc1")) do
	if ent:GetPos():Distance(LocalPlayer():GetPos()) < 1000 then
	  
	   
end
end 
end)
