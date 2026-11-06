AddCSLuaFile()

-- Écran 3D qui affiche une page web sur le modèle (YouTube, etc.).
-- Améliorations par rapport à la v1 :
--   * la page n'est chargée que si un joueur est proche (performances)
--   * l'URL est synchronisée serveur -> clients et validée côté serveur
--   * volume dépendant de la distance, touche E = télécommande
--   * plus aucun spam dans le chat

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Écran web (base)"
ENT.Author      = "FilleuxStudio"
ENT.Category    = "ComputerWeb"
ENT.Spawnable   = false
ENT.AdminOnly   = false
ENT.Instructions = "Appuyez sur E pour ouvrir la télécommande."

ENT.IsComputerWebScreen = true
ENT.CWKind = "screen"      -- type d'appareil (outil Réseau du thème Cipher)
ENT.DefaultURL = "https://www.youtube.com/"
ENT.CWModel = "models/props_phx/rt_screen.mdl"

-- Taille de la page rendue (texture) : plus grand = plus net mais plus lourd.
local PANEL_W, PANEL_H = 1024, 512

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ScreenURL")
end

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.CWModel)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetScreenURL(self.DefaultURL)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableMotion(false) -- l'écran reste en place
        end
    end

    function ENT:Use(activator, caller)
        local ply = IsValid(caller) and caller or activator
        if IsValid(ply) and ply:IsPlayer() then
            ComputerWeb.OpenScreenMenu(ply, self)
        end
    end

else -- CLIENT

    function ENT:Initialize()
        self.Panel = nil
        self.Mat = nil
        self.LoadedURL = nil
        self.NextCheck = 0
        self.NextVolume = 0
        self.LastVolume = -1
        self.LocalMuted = false
    end

    function ENT:DestroyPanel()
        if IsValid(self.Panel) then self.Panel:Remove() end
        self.Panel, self.Mat, self.LoadedURL = nil, nil, nil
    end

    function ENT:CreatePanel(url)
        self:DestroyPanel()

        local ok = ComputerWeb.CheckURL(url)
        if not ok then return end

        local p = vgui.Create("DHTML")
        p:SetSize(PANEL_W, PANEL_H)
        p:SetPos(0, 0)
        p:SetAlpha(0)                      -- invisible : on n'utilise que la texture
        p:SetMouseInputEnabled(false)
        p:SetKeyboardInputEnabled(false)
        p:SetAllowLua(false)               -- une page web ne doit jamais exécuter de Lua
        p.ConsoleMessage = function() end  -- pas de bruit dans la console

        -- Ne suit pas les redirections vers un site interdit.
        p.OnBeginLoadingDocument = function(_, newURL)
            if newURL == "about:blank" then return end
            if not ComputerWeb.CheckURL(newURL) then p:StopLoading() end
        end

        -- Tente de lancer la lecture quand la page est prête (meilleur effort).
        p.OnDocumentReady = function(self2)
            self2:QueueJavascript([[
                try {
                    var v = document.querySelector('video');
                    if (v) { v.play(); }
                } catch (e) {}
            ]])
        end

        p:OpenURL(url)
        self.Panel = p
        self.LoadedURL = url
    end

    function ENT:Think()
        local now = CurTime()
        if now < self.NextCheck then return end
        self.NextCheck = now + 0.4

        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local dist = lp:GetPos():Distance(self:GetPos())
        local maxDist = ComputerWeb.CVars.screendist:GetFloat()
        local url = self:GetScreenURL()

        if dist > maxDist or url == "" then
            if self.Panel then self:DestroyPanel() end
            return
        end

        if not IsValid(self.Panel) or self.LoadedURL ~= url then
            self:CreatePanel(url)
            return
        end

        -- Volume selon la distance (0 loin, 1 collé à l'écran)
        local vol = 1 - math.Clamp((dist - 80) / (maxDist - 80), 0, 1)
        vol = vol * vol
        if self.LocalMuted then vol = 0 end
        if math.abs(vol - self.LastVolume) > 0.03 then
            self.LastVolume = vol
            self.Panel:QueueJavascript(string.format(
                "try{var v=document.querySelector('video');if(v){v.volume=%.2f;}}catch(e){}", vol))
        end
    end

    function ENT:Draw()
        -- Matériau HTML -> remplace la texture de l'écran du modèle
        if not self.Mat and IsValid(self.Panel) then
            local html_mat = self.Panel:GetHTMLMaterial()
            if html_mat then
                local tw = math.max(html_mat:Width(), 1)
                local th = math.max(html_mat:Height(), 1)
                local matdata = {
                    ["$basetexture"] = html_mat:GetName(),
                    ["$basetexturetransform"] = string.format(
                        "center 0 0 scale %.4f %.4f rotate 0 translate 0 0", PANEL_W / tw, PANEL_H / th),
                    ["$model"] = 1,
                }
                local uid = string.Replace(html_mat:GetName(), "__vgui_texture_", "")
                self.Mat = CreateMaterial("CWWebMaterial_" .. uid, "VertexLitGeneric", matdata)
            end
        end

        if self.Mat then
            if render.MaterialOverrideByIndex then
                render.MaterialOverrideByIndex(1, self.Mat)
            else
                render.ModelMaterialOverride(self.Mat)
            end
        end

        self:DrawModel()

        render.ModelMaterialOverride(nil)
        if render.MaterialOverrideByIndex then render.MaterialOverrideByIndex(1, nil) end
    end

    function ENT:OnRemove()
        self:DestroyPanel()
    end

end
