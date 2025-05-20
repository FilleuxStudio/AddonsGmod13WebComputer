include("shared.lua")

-- Fonction pour afficher le terminal
local function OpenComputerInterface()
    chat.AddText(Color(0, 0, 0), "Terminal... :", Color(0, 123, 255), "...Open...Connect...")
    chat.AddText(Color(0, 0, 0), "Terminal... :", Color(0, 123, 255), "...software...hardware...PRÊT.")
    chat.AddText(Color(0, 0, 0), "Terminal... :", Color(0, 123, 255), "...Connect...Server...OK.")

    -- Fenêtre principale
    local windowsPc = vgui.Create("DFrame")
    windowsPc:SetTitle("Terminal")
    windowsPc:SetSize(1000, 600)
    windowsPc:Center()
    windowsPc:MakePopup()
    windowsPc:SetVisible(true)
    windowsPc.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 200))
    end

    -- Fenêtre Documents
    local windows1 = vgui.Create("DFrame")
    windows1:SetTitle("Documents")
    windows1:SetSize(250, 600)
    windows1:SetPos(10, 10)
    windows1:MakePopup()
    windows1:SetVisible(true)
    windows1:SetDraggable(false)
    windows1.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(121, 201, 234, 235))
    end

    -- Fenêtre Vidéo
    local windows2 = vgui.Create("DFrame")
    windows2:SetTitle("Vidéo")
    windows2:SetSize(250, 600)
    windows2:SetPos(ScrW() - 260, 10)
    windows2:MakePopup()
    windows2:SetVisible(true)
    windows2:SetDraggable(false)
    windows2.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(121, 201, 234, 235))
    end

    -- Bouton de fermeture
    local GUI_Main_Exit = vgui.Create("DButton", windowsPc)
    GUI_Main_Exit:SetSize(36, 36)
    GUI_Main_Exit:SetPos(5, 560)
    GUI_Main_Exit:SetText("")
    GUI_Main_Exit.Paint = function(self, w, h)
        surface.SetMaterial(Material("materials/img/inputclose.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    GUI_Main_Exit.DoClick = function()
        windowsPc:Close()
        windows1:Close()
        windows2:Close()
    end

    -- Boutons vidéo
    local videoButtons = {
        {label = "N°1", url = "https://www.youtube.com/watch?v=vXoJI2AkSBo"},
        {label = "N°2", url = "https://www.youtube.com/watch?v=cxVKech_xKU"},
        {label = "N°3", url = "https://www.youtube.com/watch?v=HLL9d34sg3Y"},
        {label = "N°4", url = "https://www.youtube.com/watch?v=o_3t40p8ky8"},
        {label = "N°5", url = "https://www.youtube.com/watch?v=c6TvN5Cgdjo"}
    }

    for i, btn in ipairs(videoButtons) do
        local button = vgui.Create("DButton", windows2)
        button:SetSize(45, 45)
        button:SetPos(50, 50 + (i - 1) * 60)
        button:SetText(btn.label)
        button.DoClick = function()
            local frame = vgui.Create("DFrame")
            frame:SetTitle(btn.label)
            frame:SetSize(1000, 500)
            frame:Center()
            frame:MakePopup()

            local html = vgui.Create("HTML", frame)
            html:Dock(FILL)
            html:OpenURL(btn.url)
        end
    end

    -- Bouton Dossier
    local buttonFolder = vgui.Create("DButton", windowsPc)
    buttonFolder:SetSize(68, 68)
    buttonFolder:SetPos(25, 89)
    buttonFolder:SetText("")
    buttonFolder.Paint = function(self, w, h)
        surface.SetMaterial(Material("materials/img/iconfolder.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    buttonFolder.DoClick = function()
        local frame = vgui.Create("DFrame", windowsPc)
        frame:SetTitle("Data")
        frame:SetSize(1000, 500)
        frame:Center()
        frame:MakePopup()
    end

    -- Bouton Internet
    local buttonInternet = vgui.Create("DButton", windowsPc)
    buttonInternet:SetSize(50, 50)
    buttonInternet:SetPos(25, 150)
    buttonInternet:SetText("")
    buttonInternet.Paint = function(self, w, h)
        surface.SetMaterial(Material("materials/img/inputchrome.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    buttonInternet.DoClick = function()
        local frame = vgui.Create("DFrame", windowsPc)
        frame:SetTitle("Internet")
        frame:SetSize(1000, 500)
        frame:Center()
        frame:MakePopup()

        local html = vgui.Create("HTML", frame)
        html:Dock(FILL)
        html:OpenURL("https://www.google.fr")
    end

    -- Bouton Photo
    local buttonPhoto = vgui.Create("DButton", windowsPc)
    buttonPhoto:SetSize(50, 50)
    buttonPhoto:SetPos(25, 220)
    buttonPhoto:SetText("")
    buttonPhoto.Paint = function(self, w, h)
        surface.SetMaterial(Material("materials/img/camera.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    buttonPhoto.DoClick = function()
        local frame = vgui.Create("DFrame", windowsPc)
        frame:SetTitle("Photo")
        frame:SetSize(1000, 500)
        frame:Center()
        frame:MakePopup()

        local html = vgui.Create("HTML", frame)
        html:Dock(FILL)
        html:OpenURL("https://www.google.fr/search?q=combine+gmod&tbm=isch")
    end

    -- Texte d'information
    local TextFrame = vgui.Create("DFrame", windows1)
    TextFrame:SetSize(200, 500)
    TextFrame:Center()
    TextFrame:SetTitle("Informations")
    TextFrame:MakePopup()

    local richtext = vgui.Create("RichText", TextFrame)
    richtext:Dock(FILL)
    richtext:InsertColorChange(255, 255, 192, 255)
    richtext:AppendText("Bienvenue dans le terminal COMBINE. Sélectionnez une option pour commencer.")

    function richtext:PerformLayout()
        self:SetFontInternal("Trebuchet18")
        self:SetBGColor(Color(64, 64, 84))
    end
end

-- Hook pour ouvrir l'interface
usermessage.Hook("PC3", OpenComputerInterface)

-- Affichage du modèle de l'entité
function ENT:Draw()
    self:DrawModel()
end
