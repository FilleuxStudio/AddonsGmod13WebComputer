--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Calculatrice"
      * évaluateur d'expressions maison (aucun loadstring : pas d'injection de code)
      * + - * / ^ % ( ), fonctions sqrt abs sin cos tan ln log round floor ceil, constantes pi e
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local OS = CW.OS

CW.Calc = CW.Calc or {}
local Calc = CW.Calc

local FUNCS = {
    sqrt = function(x) if x < 0 then return nil, "Racine d'un nombre négatif" end return math.sqrt(x) end,
    abs = math.abs, sin = math.sin, cos = math.cos, tan = math.tan,
    ln = function(x) if x <= 0 then return nil, "Logarithme invalide" end return math.log(x) end,
    log = function(x) if x <= 0 then return nil, "Logarithme invalide" end return math.log(x) / math.log(10) end,
    round = function(x) return math.floor(x + 0.5) end,
    floor = math.floor, ceil = math.ceil,
}
local CONSTS = { pi = math.pi, e = math.exp(1) }

--- Découpe l'expression en jetons. Renvoie liste ou nil, erreur.
local function tokenize(src)
    local toks, i, n = {}, 1, #src
    while i <= n do
        local ch = src:sub(i, i)
        if ch:match("%s") then
            i = i + 1
        elseif ch:match("[%d%.]") then
            local num = src:match("^%d*%.?%d*", i)
            if num == "" or num == "." then return nil, "Nombre invalide" end
            toks[#toks + 1] = { t = "num", v = tonumber(num) }
            i = i + #num
        elseif ch:match("%a") then
            local word = src:match("^%a+", i):lower()
            toks[#toks + 1] = { t = "id", v = word }
            i = i + #word
        elseif ch:match("[%+%-%*/%^%%%(%)]") then
            toks[#toks + 1] = { t = ch }
            i = i + 1
        elseif ch == "," then
            return nil, "Utilisez le point comme séparateur décimal"
        else
            return nil, "Caractère non autorisé : " .. ch
        end
    end
    return toks
end

--- Évalue une expression. Renvoie nombre ou nil, message d'erreur.
function Calc.Eval(src)
    src = tostring(src or "")
    if #src > 160 then return nil, "Expression trop longue" end
    if CW.Trim(src) == "" then return nil, "Expression vide" end
    local toks, terr = tokenize(src)
    if not toks then return nil, terr end

    local pos, depth = 1, 0
    local parseExpr

    local function peek() return toks[pos] and toks[pos].t end
    local function fail(msg) error({ calc = msg }, 0) end

    local function parsePrimary()
        local tk = toks[pos]
        if not tk then fail("Expression incomplète") end
        if tk.t == "num" then pos = pos + 1 return tk.v end
        if tk.t == "(" then
            pos = pos + 1
            depth = depth + 1
            if depth > 24 then fail("Parenthèses trop imbriquées") end
            local v = parseExpr()
            if peek() ~= ")" then fail("Parenthèse fermante manquante") end
            pos = pos + 1
            depth = depth - 1
            return v
        end
        if tk.t == "id" then
            pos = pos + 1
            if CONSTS[tk.v] then return CONSTS[tk.v] end
            local fn = FUNCS[tk.v]
            if not fn then fail("Inconnu : " .. tk.v) end
            if peek() ~= "(" then fail("« " .. tk.v .. " » attend des parenthèses") end
            pos = pos + 1
            depth = depth + 1
            if depth > 24 then fail("Parenthèses trop imbriquées") end
            local arg = parseExpr()
            if peek() ~= ")" then fail("Parenthèse fermante manquante") end
            pos = pos + 1
            depth = depth - 1
            local r, e = fn(arg)
            if r == nil then fail(e or "Fonction invalide") end
            return r
        end
        fail("Symbole inattendu : " .. tostring(tk.t))
    end

    local parseUnary

    local function parsePower()
        local base = parsePrimary()
        if peek() == "^" then
            pos = pos + 1
            local exp = parseUnary()      -- associatif à droite, accepte 2^-1
            local r = base ^ exp
            if r ~= r then fail("Puissance invalide") end
            return r
        end
        return base
    end

    function parseUnary()
        if peek() == "-" then pos = pos + 1 return -parseUnary() end
        if peek() == "+" then pos = pos + 1 return parseUnary() end
        return parsePower()
    end

    local function parseTerm()
        local v = parseUnary()
        while peek() == "*" or peek() == "/" or peek() == "%" do
            local op = toks[pos].t
            pos = pos + 1
            local rhs = parseUnary()
            if op == "*" then
                v = v * rhs
            else
                if rhs == 0 then fail("Division par zéro") end
                if op == "/" then v = v / rhs else v = v - math.floor(v / rhs) * rhs end
            end
        end
        return v
    end

    function parseExpr()
        local v = parseTerm()
        while peek() == "+" or peek() == "-" do
            local op = toks[pos].t
            pos = pos + 1
            local rhs = parseTerm()
            if op == "+" then v = v + rhs else v = v - rhs end
        end
        return v
    end

    local ok, res = pcall(function()
        local v = parseExpr()
        if pos <= #toks then fail("Symbole inattendu après l'expression") end
        return v
    end)
    if not ok then
        if type(res) == "table" and res.calc then return nil, res.calc end
        return nil, "Expression invalide"
    end
    if res ~= res or res == math.huge or res == -math.huge then return nil, "Résultat hors limites" end
    return res
end

function Calc.Format(v)
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
    local s = string.format("%.10g", v)
    return s
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local KEYS = {
    { "C", "(", ")", "/" },
    { "7", "8", "9", "*" },
    { "4", "5", "6", "-" },
    { "1", "2", "3", "+" },
    { "0", ".", "^", "=" },
}
local EXTRA = { "sqrt(", "sin(", "cos(", "ln(", "pi", "<" }

local function openCalc(desktop, args)
    local win = UI.Window(desktop, {
        title = "Calculatrice", icon = "calc", app = "calc",
        w = S(380), h = S(580), minW = S(340), minH = S(520), noMax = true, noResize = true,
    })
    local content = win:GetContent()
    local entry, resultText, history = nil, "0", {}
    local isError = false

    local function evaluate()
        local v, err = Calc.Eval(entry:GetValue())
        if v == nil then
            resultText, isError = err or "Erreur", true
            return
        end
        resultText, isError = Calc.Format(v), false
        table.insert(history, 1, entry:GetValue() .. " = " .. resultText)
        while #history > 4 do table.remove(history) end
    end

    local display = vgui.Create("DPanel", content)
    display:Dock(TOP)
    display:SetTall(S(150))
    display:DockMargin(S(8), S(8), S(8), 0)
    display.Paint = function(_, w, h)
        local c = UI.T.c
        if UI.T.bevel then
            UI.Bevel(0, 0, w, h, false, c.input)
        else
            draw.RoundedBox(S(UI.T.radius), 0, 0, w, h, c.panel)
        end
        for i, line in ipairs(history) do
            draw.SimpleText(line, "CW.Small", w - S(10), S(8) + (i - 1) * S(15), c.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        draw.SimpleText(resultText, "CW.Big", w - S(10), h - S(14), isError and c.danger or c.windowText,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end

    entry = UI.Entry(content, "Tapez une opération, ex. (3+4)*2")
    entry:Dock(TOP)
    entry:SetTall(S(36))
    entry:DockMargin(S(8), S(8), S(8), 0)
    entry.OnEnter = function() evaluate() end

    local function put(txt)
        entry:SetText(entry:GetValue() .. txt)
        entry:RequestFocus()
    end

    local function keyRow(parent)
        local r = vgui.Create("DPanel", parent)
        r:Dock(TOP)
        r:SetTall(S(54))
        r:DockMargin(S(8), S(6), S(8), 0)
        r.Paint = function() end
        return r
    end

    local function addKey(row, label, count)
        local kind = (label == "=") and "accent" or "flat"
        local b = UI.Button(row, label == "<" and "Eff." or label:gsub("%($", ""), nil, function()
            if label == "C" then
                entry:SetText("")
                resultText, isError = "0", false
            elseif label == "<" then
                local t = entry:GetValue()
                entry:SetText(t:sub(1, #t - 1))
            elseif label == "=" then
                evaluate()
            else
                put(label)
            end
        end, kind)
        b:Dock(LEFT)
        b:SetWide(math.floor((S(380) - S(16) - S(2) - S(6) * (count - 1)) / count))
        b:DockMargin(0, 0, S(6), 0)
        return b
    end

    local ex = keyRow(content)
    for _, k in ipairs(EXTRA) do addKey(ex, k, #EXTRA) end
    for _, row in ipairs(KEYS) do
        local r = keyRow(content)
        for _, k in ipairs(row) do addKey(r, k, #row) end
    end

    entry:RequestFocus()
    win.OnAppArgs = function() end
    return win
end

OS.RegisterApp("calc", {
    name = "Calculatrice", icon = "calc", order = 22, single = true,
    open = openCalc,
})
