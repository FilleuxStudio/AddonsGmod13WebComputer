--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Démineur"
      * clic gauche : révéler, clic droit : drapeau, premier clic toujours sûr
      * 3 niveaux, chronomètre, compteur de mines
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local OS = CW.OS

CW.Mines = CW.Mines or {}
local M = CW.Mines

M.Levels = {
    { id = "easy",   name = "Facile",    w = 9,  h = 9,  mines = 10 },
    { id = "medium", name = "Moyen",     w = 13, h = 11, mines = 26 },
    { id = "hard",   name = "Difficile", w = 16, h = 12, mines = 40 },
}

---------------------------------------------------------------------------
-- Logique pure
---------------------------------------------------------------------------
function M.New(w, h, mines)
    local cells = {}
    for i = 1, w * h do cells[i] = { mine = false, open = false, flag = false, n = 0 } end
    return {
        w = w, h = h, mines = math.min(mines, w * h - 9), cells = cells,
        started = false, over = false, won = false, opened = 0, flags = 0,
    }
end

local function idx(g, x, y) return (y - 1) * g.w + x end

local function neighbours(g, x, y)
    local out = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx, ny = x + dx, y + dy
                if nx >= 1 and nx <= g.w and ny >= 1 and ny <= g.h then out[#out + 1] = { nx, ny } end
            end
        end
    end
    return out
end
M.Neighbours = neighbours

local function place(g, sx, sy, rnd)
    rnd = rnd or math.random
    -- zone sûre : la case cliquée et ses voisines
    local safe = { [idx(g, sx, sy)] = true }
    for _, p in ipairs(neighbours(g, sx, sy)) do safe[idx(g, p[1], p[2])] = true end
    local free = {}
    for i = 1, g.w * g.h do if not safe[i] then free[#free + 1] = i end end
    for _ = 1, g.mines do
        if #free == 0 then break end
        local k = rnd(1, #free)
        g.cells[free[k]].mine = true
        free[k] = free[#free]
        free[#free] = nil
    end
    for y = 1, g.h do
        for x = 1, g.w do
            local n = 0
            for _, p in ipairs(neighbours(g, x, y)) do
                if g.cells[idx(g, p[1], p[2])].mine then n = n + 1 end
            end
            g.cells[idx(g, x, y)].n = n
        end
    end
    g.started = true
end

--- Révèle une case. Renvoie "boom", "ok" ou nil (rien fait).
function M.Reveal(g, x, y, rnd)
    if g.over or x < 1 or x > g.w or y < 1 or y > g.h then return nil end
    if not g.started then place(g, x, y, rnd) end
    local c = g.cells[idx(g, x, y)]
    if c.open or c.flag then return nil end
    if c.mine then
        c.open = true
        g.over, g.won, g.boom = true, false, idx(g, x, y)
        for _, cell in ipairs(g.cells) do if cell.mine then cell.open = true end end
        return "boom"
    end
    local stack = { { x, y } }
    while #stack > 0 do
        local p = table.remove(stack)
        local cell = g.cells[idx(g, p[1], p[2])]
        if not cell.open and not cell.flag then
            cell.open = true
            g.opened = g.opened + 1
            if cell.n == 0 then
                for _, nb in ipairs(neighbours(g, p[1], p[2])) do stack[#stack + 1] = nb end
            end
        end
    end
    if g.opened >= g.w * g.h - g.mines then
        g.over, g.won = true, true
        for _, cell in ipairs(g.cells) do if cell.mine then cell.flag = true end end
        g.flags = g.mines
    end
    return "ok"
end

function M.ToggleFlag(g, x, y)
    if g.over or x < 1 or x > g.w or y < 1 or y > g.h then return false end
    local c = g.cells[idx(g, x, y)]
    if c.open then return false end
    if not c.flag and g.flags >= g.mines then return false end
    c.flag = not c.flag
    g.flags = g.flags + (c.flag and 1 or -1)
    return true
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local NUMCOL = {
    Color(0, 0, 255), Color(0, 128, 0), Color(220, 0, 0), Color(0, 0, 128),
    Color(128, 0, 0), Color(0, 128, 128), Color(0, 0, 0), Color(110, 110, 110),
}

local function openMines(desktop, args)
    local win = UI.Window(desktop, {
        title = "Démineur", icon = "mines", app = "mines",
        w = S(420), h = S(500), minW = S(300), minH = S(300), noMax = true, noResize = true,
    })
    local content = win:GetContent()
    local CELL = S(30)
    local level = M.Levels[1]
    local game, t0, frozen

    local grid, face

    local function resize()
        local gw, gh = level.w * CELL, level.h * CELL
        grid:SetSize(gw, gh)
        win:SetSize(gw + S(8) + S(24), gh + S(27) + S(158))
        -- recentre dans la zone de travail
        local pw, ph = win:GetParent():GetSize()
        win:SetPos(math.max(0, math.floor((pw - win:GetWide()) / 2)), math.max(0, math.floor((ph - win:GetTall()) / 3)))
    end

    local function newGame()
        game = M.New(level.w, level.h, level.mines)
        t0, frozen = nil, nil
        if IsValid(grid) then resize() end
    end

    local function elapsed()
        if frozen then return frozen end
        if not t0 then return 0 end
        return math.min(999, math.floor(SysTime() - t0))
    end

    -- Barre du haut : niveaux
    local top = vgui.Create("DPanel", content)
    top:Dock(TOP)
    top:SetTall(S(44))
    top:DockPadding(S(6), S(6), S(6), S(6))
    top.Paint = function(_, w, h)
        local c = UI.T.c.panel
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(0, 0, w, h)
    end
    for _, lv in ipairs(M.Levels) do
        local b = UI.Button(top, lv.name, nil, function() level = lv; newGame() end)
        b:Dock(LEFT)
        b:SetWide(S(104))
        b:DockMargin(0, 0, S(6), 0)
        b.Think = function(self) self.cwKind = (level == lv) and "accent" or "flat" end
    end

    -- Bandeau : compteur / visage / chrono
    local bar = vgui.Create("DPanel", content)
    bar:Dock(TOP)
    bar:SetTall(S(56))
    bar:DockMargin(S(8), S(8), S(8), 0)
    bar.Paint = function(_, w, h)
        local c = UI.T.c
        UI.Bevel(0, 0, w, h, false, c.panel)
        local left = game.mines - game.flags
        draw.SimpleText(string.format("%03d", left), "CW.Huge", S(14), h / 2, Color(235, 30, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.format("%03d", elapsed()), "CW.Huge", w - S(14), h / 2, Color(235, 30, 30), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    face = vgui.Create("DButton", bar)
    face:SetText("")
    face:SetSize(S(44), S(44))
    face.Think = function(self)
        self:SetPos(math.floor((bar:GetWide() - S(44)) / 2), S(6))
    end
    face.Paint = function(self, w, h)
        UI.Bevel(0, 0, w, h, not self:IsDown(), UI.T.c.panel)
        local cx, cy, r = w / 2, h / 2, S(14)
        UI.Circle(cx, cy, r, Color(255, 220, 0), 24)
        surface.SetDrawColor(0, 0, 0, 255)
        if game.over and not game.won then
            surface.DrawLine(cx - 6, cy - 6, cx - 2, cy - 2); surface.DrawLine(cx - 6, cy - 2, cx - 2, cy - 6)
            surface.DrawLine(cx + 2, cy - 6, cx + 6, cy - 2); surface.DrawLine(cx + 2, cy - 2, cx + 6, cy - 6)
            surface.DrawLine(cx - 5, cy + 7, cx + 5, cy + 7)
        elseif game.won then
            surface.DrawRect(cx - 8, cy - 5, 6, 3); surface.DrawRect(cx + 2, cy - 5, 6, 3)
            surface.DrawLine(cx - 5, cy + 3, cx, cy + 7); surface.DrawLine(cx, cy + 7, cx + 5, cy + 3)
        else
            surface.DrawRect(cx - 6, cy - 5, 3, 3); surface.DrawRect(cx + 3, cy - 5, 3, 3)
            surface.DrawLine(cx - 5, cy + 4, cx, cy + 7); surface.DrawLine(cx, cy + 7, cx + 5, cy + 4)
        end
    end
    face.DoClick = function() newGame() end

    -- Grille
    grid = vgui.Create("DPanel", content)
    grid:SetPos(S(8), S(116))
    local function cellAt()
        local mx, my = grid:CursorPos()
        local x, y = math.floor(mx / CELL) + 1, math.floor(my / CELL) + 1
        if x < 1 or y < 1 or x > game.w or y > game.h then return nil end
        return x, y
    end
    grid.OnMousePressed = function(self, code)
        local x, y = cellAt()
        if not x then return end
        if code == MOUSE_LEFT then
            if not t0 then t0 = SysTime() end
            M.Reveal(game, x, y)
        elseif code == MOUSE_RIGHT then
            M.ToggleFlag(game, x, y)
        end
        if game.over and not frozen then frozen = elapsed() end
    end
    grid.Paint = function(self, w, h)
        local c = UI.T.c
        local hx, hy = cellAt()
        for y = 1, game.h do
            for x = 1, game.w do
                local cell = game.cells[(y - 1) * game.w + x]
                local px, py = (x - 1) * CELL, (y - 1) * CELL
                if cell.open then
                    surface.SetDrawColor(c.window.r - 14, c.window.g - 14, c.window.b - 14, 255)
                    if c.window.r < 100 then surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255) end
                    surface.DrawRect(px, py, CELL, CELL)
                    surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 255)
                    surface.DrawOutlinedRect(px, py, CELL, CELL, 1)
                    if cell.mine then
                        UI.Circle(px + CELL / 2, py + CELL / 2, CELL * 0.26,
                            (game.boom == (y - 1) * game.w + x) and Color(220, 0, 0) or Color(20, 20, 20), 14)
                    elseif cell.n > 0 then
                        draw.SimpleText(tostring(cell.n), "CW.Bold", px + CELL / 2, py + CELL / 2,
                            NUMCOL[cell.n] or color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                else
                    UI.Bevel(px, py, CELL, CELL, true, (hx == x and hy == y and not game.over) and c.panelHi or c.panel)
                    if cell.flag then
                        surface.SetDrawColor(30, 30, 30, 255)
                        surface.DrawRect(px + CELL * 0.45, py + CELL * 0.25, 2, CELL * 0.5)
                        surface.SetDrawColor(220, 0, 0, 255)
                        surface.DrawPoly({
                            { x = px + CELL * 0.45, y = py + CELL * 0.22 },
                            { x = px + CELL * 0.75, y = py + CELL * 0.34 },
                            { x = px + CELL * 0.45, y = py + CELL * 0.46 },
                        })
                    end
                end
            end
        end
    end

    newGame()
    resize()
    return win
end

OS.RegisterApp("mines", {
    name = "Démineur", icon = "mines", order = 60, single = true,
    open = openMines,
})
