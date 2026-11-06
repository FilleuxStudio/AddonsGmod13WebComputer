--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Matrix" (système Cipher) : pluie de caractères d'ambiance
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local OS = CW.OS

CW.Matrix = CW.Matrix or {}
local Mx = CW.Matrix

Mx.Chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ<>/\\|=+*#$%&"

--- Caractère déterministe pour (colonne, ligne, tic) : stable entre deux images.
function Mx.CharAt(col, row, tick)
    local i = (col * 31 + row * 17 + tick) % #Mx.Chars + 1
    return Mx.Chars:sub(i, i)
end

local function openMatrix(desktop, args)
    local win = UI.Window(desktop, {
        title = "Matrix", icon = "matrix", app = "matrix",
        w = S(720), h = S(480), minW = S(320), minH = S(240),
    })
    local panel = vgui.Create("DPanel", win:GetContent())
    panel:Dock(FILL)

    local cols = {}
    local CWID, LH = S(14), S(16)

    panel.Paint = function(self, w, h)
        surface.SetDrawColor(0, 4, 2, 255)
        surface.DrawRect(0, 0, w, h)
        local c = UI.T.c.accent
        local n = math.max(1, math.floor(w / CWID))
        local dt = math.min(FrameTime(), 0.1)
        local tick = math.floor(SysTime() * 6)
        for i = 1, n do
            local col = cols[i]
            if not col then
                col = { y = -math.random(0, math.max(h, 1)), speed = math.random(90, 260), len = math.random(8, 22) }
                cols[i] = col
            end
            col.y = col.y + col.speed * dt
            if col.y - col.len * LH > h then
                col.y = -math.random(0, S(200))
                col.speed = math.random(90, 260)
                col.len = math.random(8, 22)
            end
            for k = 0, col.len - 1 do
                local y = col.y - k * LH
                if y > -LH and y < h then
                    local row = math.floor(y / LH)
                    local fade = 1 - k / col.len
                    local colr = (k == 0) and Color(220, 255, 235, 255) or Color(c.r, c.g, c.b, math.floor(40 + 200 * fade))
                    draw.SimpleText(Mx.CharAt(i, row, tick), "CW.MonoSmall", (i - 1) * CWID + S(2), y, colr, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end
        end
    end

    win.OnAppArgs = function() end
    return win
end

OS.RegisterApp("matrix", {
    name = "Matrix", icon = "matrix", order = 70, single = true, themes = { "cipher" },
    open = openMatrix,
})
