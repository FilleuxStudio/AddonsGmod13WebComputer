--[[----------------------------------------------------------------------------
    Faux Garry's Mod pour tester ComputerWeb hors du jeu (LuaJIT / lupa).

    ATTENTION : ce n'est PAS le vrai moteur. Il vérifie que le code s'exécute
    sans erreur Lua (variables non définies, fautes de frappe, erreurs de
    logique) et que la logique pure (URL, fichiers, terminal, réseau) est
    correcte. Le rendu réel et le comportement du moteur web ne peuvent être
    validés que dans le jeu.
------------------------------------------------------------------------------]]

MOCK = { unknownMethods = {}, netSent = {}, chat = {}, console = {} }

---------------------------------------------------------------------------
-- Objet "n'importe quoi" : accepte tout appel de méthode
---------------------------------------------------------------------------
local function Anything()
    local t = {}
    return setmetatable(t, {
        __index = function(_, k) return function() return Anything() end end,
        __call = function() return Anything() end,
    })
end
MOCK.Anything = Anything

---------------------------------------------------------------------------
-- Constantes / utilitaires globaux
---------------------------------------------------------------------------
SERVER, CLIENT = false, true
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, TEXT_ALIGN_BOTTOM = 0, 1, 2, 3, 4
TOP, LEFT, RIGHT, BOTTOM, FILL = 1, 2, 3, 4, 5
MOUSE_LEFT, MOUSE_RIGHT = 107, 108
KEY_S, KEY_UP, KEY_DOWN, KEY_ENTER = 29, 88, 90, 64
KEY_F, KEY_T = 9, 30
FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY = 128, 8192, 256
FFT_256 = 2
GMOD_CHANNEL_STOPPED, GMOD_CHANNEL_PLAYING, GMOD_CHANNEL_PAUSED = 0, 1, 2
SIMPLE_USE, SOLID_VPHYSICS, MOVETYPE_VPHYSICS = 3, 6, 6

function Color(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
color_white, color_black = Color(255, 255, 255), Color(0, 0, 0)

function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isfunction(x) return type(x) == "function" end

function math.Clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function Lerp(t, a, b) return a + (b - a) * t end
function FrameTime() return 0.016 end
local clock = 1000
function SysTime() clock = clock + 0.01 return clock end
function CurTime() return clock end
function ScrW() return 1920 end
function ScrH() return 1080 end
function ErrorNoHalt(...) MOCK.lastError = table.concat({ ... }, "") end
function MsgC() end

function SortedPairs(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local i = 0
    return function()
        i = i + 1
        if keys[i] ~= nil then return keys[i], t[keys[i]] end
    end
end

function string.Replace(s, a, b) return (s:gsub(a:gsub("%p", "%%%0"), (b:gsub("%%", "%%%%")))) end

function IsValid(o)
    if not o then return false end
    local f = o.IsValid
    if type(f) ~= "function" then return false end
    return f(o)
end

---------------------------------------------------------------------------
-- Vecteur / joueur / ConVars
---------------------------------------------------------------------------
local VecMT = {}
VecMT.__index = VecMT
function VecMT:Distance(o) return math.sqrt((self.x - o.x) ^ 2 + (self.y - o.y) ^ 2 + (self.z - o.z) ^ 2) end
function VecMT.__add(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
function VecMT:ToScreen() return { x = 640 + self.x, y = 360 - self.z, visible = MOCK.vecVisible ~= false } end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VecMT) end

local PlayerMT = {}
PlayerMT.__index = PlayerMT
function PlayerMT:IsValid() return true end
function PlayerMT:IsPlayer() return true end
function PlayerMT:Alive() return self.alive ~= false end
function PlayerMT:Nick() return self.nick end
function PlayerMT:SteamID64() return self.sid end
function PlayerMT:GetPos() return self.pos end
function PlayerMT:IsAdmin() return self.admin end
function PlayerMT:IsSuperAdmin() return self.super end
function PlayerMT:EntIndex() return self.idx end
function PlayerMT:ChatPrint(m) MOCK.chat[#MOCK.chat + 1] = m end

function MOCK.NewPlayer(opts)
    opts = opts or {}
    return setmetatable({
        nick = opts.nick or "Testeur", sid = opts.sid or "76561198000000001",
        pos = opts.pos or Vector(0, 0, 0), admin = opts.admin or false,
        super = opts.super or false, idx = opts.idx or 1,
    }, PlayerMT)
end
MOCK.me = MOCK.NewPlayer()
function LocalPlayer() return MOCK.me end

local ConVarMT = {}
ConVarMT.__index = ConVarMT
function ConVarMT:GetString() return tostring(self.v) end
function ConVarMT:GetBool() return self.v == "1" or self.v == 1 or self.v == true end
function ConVarMT:GetFloat() return tonumber(self.v) or 0 end
function ConVarMT:GetInt() return math.floor(tonumber(self.v) or 0) end

MOCK.convars = {}
local function newConVar(name, default)
    local cv = MOCK.convars[name]
    if not cv then
        cv = setmetatable({ name = name, v = tostring(default) }, ConVarMT)
        MOCK.convars[name] = cv
    end
    return cv
end
function CreateConVar(name, default) return newConVar(name, default) end
function CreateClientConVar(name, default) return newConVar(name, default) end
function GetConVar(name) return MOCK.convars[name] end
function RunConsoleCommand(name, value)
    MOCK.console[#MOCK.console + 1] = { name, value }
    if MOCK.convars[name] then MOCK.convars[name].v = tostring(value) end
end

---------------------------------------------------------------------------
-- Libs diverses
---------------------------------------------------------------------------
hook = { _h = {} }
function hook.Add(ev, id, fn) hook._h[ev] = hook._h[ev] or {}; hook._h[ev][id] = fn end
function hook.Remove(ev, id) if hook._h[ev] then hook._h[ev][id] = nil end end
function hook.Run(ev, ...)
    for _, fn in pairs(hook._h[ev] or {}) do
        local r = fn(...)
        if r ~= nil then return r end
    end
end

timer = { queue = {} }
function timer.Simple(delay, fn) timer.queue[#timer.queue + 1] = { delay, fn } end
function timer.Flush()
    local q = timer.queue
    timer.queue = {}
    for _, t in ipairs(q) do t[2]() end
end

concommand = { cmds = {} }
function concommand.Add(name, fn) concommand.cmds[name] = fn end

chat = { AddText = function(...) MOCK.chat[#MOCK.chat + 1] = table.concat({ ... }, "", 1, 0) end }
gui = { OpenURL = function(u) MOCK.openedURL = u end }
input = { IsMouseDown = function() return false end, IsControlDown = function() return false end }
render = { MaterialOverrideByIndex = function() end, ModelMaterialOverride = function() end }
cam = Anything()
function CreateMaterial(name, shader, data) return { name = name, data = data, GetName = function() return name end } end
function Material(path) return { path = path, Width = function() return 1024 end, Height = function() return 512 end, GetName = function() return path end } end

surface = {
    CreateFont = function() end, SetFont = function() end, SetMaterial = function() end,
    SetDrawColor = function() end, DrawRect = function() end, DrawLine = function() end,
    DrawOutlinedRect = function() end, DrawTexturedRect = function() end, DrawPoly = function() end,
    GetTextSize = function(t) return #tostring(t) * 8, 16 end, PlaySound = function(s) MOCK.lastSound = s end,
}
draw = {
    RoundedBox = function() end, RoundedBoxEx = function() end, NoTexture = function() end,
    SimpleText = function(t) return #tostring(t) * 8, 16 end,
}

net = { _recv = {}, _in = {}, _out = nil }
function net.Receive(name, fn) net._recv[name] = fn end
function net.Start(name) net._out = { name = name, data = {} } end
function net.WriteEntity(e) table.insert(net._out.data, e) end
function net.WriteString(s) table.insert(net._out.data, s) end
function net.Send(ply) net._out.to = ply; MOCK.netSent[#MOCK.netSent + 1] = net._out; net._out = nil end
function net.SendToServer() net._out.to = "server"; MOCK.netSent[#MOCK.netSent + 1] = net._out; net._out = nil end
function net.WriteUInt(v) table.insert(net._out.data, v) end
function net.WriteBool(v) table.insert(net._out.data, v) end
function net.ReadUInt() return table.remove(net._in, 1) end
function net.ReadBool() return table.remove(net._in, 1) end
function net.ReadEntity() return table.remove(net._in, 1) end
function net.ReadString() return table.remove(net._in, 1) end
util = {
    AddNetworkString = function() end,
    JSONToTable = function(s) return MOCK.json_decode(s) end,
    TableToJSON = function(t) return MOCK.json_encode(t) end,
}

-- JSON minimal (tableaux d'objets { name=..., url=... })
function MOCK.json_encode(t)
    local items = {}
    for _, o in ipairs(t) do
        items[#items + 1] = string.format('{"name":%q,"url":%q}', o.name, o.url)
    end
    return "[" .. table.concat(items, ",") .. "]"
end
function MOCK.json_decode(s)
    local out = {}
    for name, url in tostring(s):gmatch('{"name":"(.-)","url":"(.-)"}') do
        out[#out + 1] = { name = name, url = url }
    end
    return out
end

MOCK.ents = {}
ents = { GetAll = function() return MOCK.ents end }

sound = {}
function sound.PlayURL(url, flags, cb)
    MOCK.lastStream, MOCK.lastStreamFlags = url, flags
    MOCK.streams = (MOCK.streams or 0) + 1
    local ch = { _state = GMOD_CHANNEL_PLAYING, vol = 1 }
    function ch:IsValid() return not self.dead end
    function ch:Play() self._state = GMOD_CHANNEL_PLAYING end
    function ch:Pause() self._state = GMOD_CHANNEL_PAUSED end
    function ch:Stop() self.dead = true; self._state = GMOD_CHANNEL_STOPPED end
    function ch:SetVolume(v) self.vol = v end
    function ch:SetPos(p) self.pos = p end
    function ch:Set3DFadeDistance(a, b) self.fade = { a, b } end
    function ch:GetState() return self._state end
    function ch:FFT(t) for i = 1, 64 do t[i] = 0.1 end return 64 end
    if MOCK.streamFails then cb(nil, 2, "Erreur simulée") else cb(ch, 0, "") end
end

---------------------------------------------------------------------------
-- file (DATA en mémoire)
---------------------------------------------------------------------------
MOCK.files, MOCK.dirs = {}, {}
local function norm(p) return (tostring(p):gsub("//+", "/"):gsub("/$", "")) end
local function parentOf(p) return p:match("^(.*)/[^/]*$") or "" end

file = {}
function file.Exists(p) p = norm(p); return MOCK.files[p] ~= nil or MOCK.dirs[p] == true end
function file.IsDir(p) return MOCK.dirs[norm(p)] == true end
function file.CreateDir(p) MOCK.dirs[norm(p)] = true end
function file.Read(p) return MOCK.files[norm(p)] end
function file.Write(p, c)
    p = norm(p)
    if not MOCK.dirs[parentOf(p)] and parentOf(p) ~= "" then return end   -- comme GMod : le dossier doit exister
    MOCK.files[p] = c
end
function file.Size(p) local c = MOCK.files[norm(p)]; return c and #c or -1 end
function file.Time(p) return 1700000000 end
function file.Delete(p)
    p = norm(p)
    if MOCK.files[p] then MOCK.files[p] = nil return end
    if MOCK.dirs[p] then
        for f in pairs(MOCK.files) do if parentOf(f) == p then return end end
        for d in pairs(MOCK.dirs) do if parentOf(d) == p then return end end
        MOCK.dirs[p] = nil
    end
end
function file.Rename(a, b)
    a, b = norm(a), norm(b)
    if MOCK.files[a] then MOCK.files[b] = MOCK.files[a]; MOCK.files[a] = nil end
end
function file.Find(pattern)
    local dir = norm(pattern):gsub("/%*$", "")
    local files, dirs = {}, {}
    for f in pairs(MOCK.files) do if parentOf(f) == dir then files[#files + 1] = f:match("[^/]*$") end end
    for d in pairs(MOCK.dirs) do if parentOf(d) == dir then dirs[#dirs + 1] = d:match("[^/]*$") end end
    table.sort(files); table.sort(dirs)
    return files, dirs
end

---------------------------------------------------------------------------
-- Derma : dialogues et menus (réponses scriptables)
---------------------------------------------------------------------------
MOCK.nextString = "essai"
function Derma_StringRequest(title, text, default, ok) if ok then ok(MOCK.nextString) end end
function Derma_Query(text, title, l1, f1) if f1 then f1() end end
local MenuMT = {}
MenuMT.__index = MenuMT
local function newOption() return { SetIcon = function(o) return o end, SetChecked = function(o) return o end } end
function MenuMT:AddOption(name, fn) self.options[#self.options + 1] = { name = name, fn = fn } return newOption() end
function MenuMT:AddSubMenu() return setmetatable({ options = {} }, MenuMT), newOption() end
function MenuMT:AddSpacer() end
function MenuMT:Open() MOCK.lastMenu = self end
function DermaMenu() return setmetatable({ options = {} }, MenuMT) end

---------------------------------------------------------------------------
-- Panneaux
---------------------------------------------------------------------------
local Panel = {}
-- Un champ absent vaut nil (comme dans le vrai GMod). Les méthodes de Panel/Derma réellement
-- utilisées par ComputerWeb sont déclarées explicitement plus bas : si le code appelle une méthode
-- que le mock ne connaît pas, le test échoue en citant son nom -> on vérifie qu'elle existe
-- vraiment dans l'API GMod (et pas une faute de frappe) avant de l'ajouter à la liste.
Panel.__index = Panel

MOCK.allPanels = setmetatable({}, { __mode = "k" })

local NOOP_METHODS = {
    -- Panel
    "Dock", "DockMargin", "DockPadding", "SetCursor", "SetTooltip", "MakePopup", "SetKeyboardInputEnabled",
    "SetMouseInputEnabled", "RequestFocus", "SetAlpha", "MouseCapture", "InvalidateLayout", "SetPaintedManually",
    "SetPaintBackground", "AlphaTo", "Center",
    -- DLabel
    "SetFont", "SetTextColor", "SetWrap", "SetAutoStretchVertical", "SetContentAlignment",
    -- DTextEntry
    "SetMultiline", "SetDrawLanguageID", "DrawTextEntryText", "SetCaretPos", "SetPlaceholderText",
    -- DHTML
    "SetAllowLua", "StopLoading",
    -- DIconLayout
    "SetSpaceX", "SetSpaceY",
}
for _, name in ipairs(NOOP_METHODS) do
    if Panel[name] == nil then Panel[name] = function() end end
end

function Panel:GetCaretPos() return 0 end
function Panel:IsValid() return not self.__removed end
function Panel:Remove()
    self.__removed = true
    if self.OnRemove then self:OnRemove() end
    for _, c in ipairs(self.__children) do if not c.__removed then c:Remove() end end
    if self.__parent then
        for i, c in ipairs(self.__parent.__children) do if c == self then table.remove(self.__parent.__children, i) break end end
    end
end
function Panel:Clear() for i = #self.__children, 1, -1 do self.__children[i]:Remove() end end
function Panel:GetChildren() local t = {} for i, c in ipairs(self.__children) do t[i] = c end return t end
function Panel:GetParent() return self.__parent end
function Panel:HasParent(p) local x = self.__parent while x do if x == p then return true end x = x.__parent end return false end
function Panel:SetSize(w, h) self.__w, self.__h = w, h; if self.OnSizeChanged then self:OnSizeChanged(w, h) end end
function Panel:GetSize() return self.__w, self.__h end
function Panel:GetWide() return self.__w end
function Panel:GetTall() return self.__h end
function Panel:SetWide(w) self:SetSize(w, self.__h) end
function Panel:SetTall(h) self:SetSize(self.__w, h) end
function Panel:SetPos(x, y) self.__x, self.__y = x, y end
function Panel:GetPos() return self.__x, self.__y end
function Panel:GetX() return self.__x end
function Panel:GetY() return self.__y end
function Panel:SetVisible(v) self.__visible = v end
function Panel:IsVisible() return self.__visible end
function Panel:Dock(d) self.__dock = d end
function Panel:CursorPos() return 5, 5 end
function Panel:IsHovered() return false end
function Panel:IsDown() return false end
function Panel:HasFocus() return false end
function Panel:SetText(t) self.__text = tostring(t) end
function Panel:GetText() return self.__text or "" end
function Panel:GetValue() return self.__text or "" end
function Panel:MoveToFront()
    if not self.__parent then return end
    local ch = self.__parent.__children
    for i, c in ipairs(ch) do if c == self then table.remove(ch, i) break end end
    ch[#ch + 1] = self
end
function Panel:MoveToBack()
    if not self.__parent then return end
    local ch = self.__parent.__children
    for i, c in ipairs(ch) do if c == self then table.remove(ch, i) break end end
    table.insert(ch, 1, self)
end
function Panel:AddFunction(lib, name, fn) self.__funcs = self.__funcs or {}; self.__funcs[lib .. "." .. name] = fn end
function Panel:OpenURL(u) self.__url = u end
function Panel:SetHTML(h) self.__htmlSource = h end
function Panel:GetHTMLMaterial() return Material("__vgui_texture_1") end
function Panel:QueueJavascript(js) self.__js = js end
function Panel:GetVBar()
    if not self.__vbar then
        local mk = function() return setmetatable({ __children = {}, __w = 10, __h = 10, __visible = true }, Panel) end
        self.__vbar = mk()
        self.__vbar.btnUp, self.__vbar.btnDown, self.__vbar.btnGrip = mk(), mk(), mk()
    end
    return self.__vbar
end

function MOCK.NewPanel(class, parent)
    local p = setmetatable({ __class = class, __children = {}, __parent = parent, __w = 200, __h = 100,
        __x = 0, __y = 0, __visible = true }, Panel)
    if parent then
        parent.__children[#parent.__children + 1] = p
        -- taille plausible pour les panneaux "dockés"
        p.__w, p.__h = parent.__w or 200, parent.__h or 100
    end
    MOCK.allPanels[p] = true
    return p
end

vgui = {
    Create = function(class, parent) return MOCK.NewPanel(class, parent) end,
    GetHoveredPanel = function() return nil end,
}

---------------------------------------------------------------------------
-- include / AddCSLuaFile : charge depuis lua/
---------------------------------------------------------------------------
MOCK.root = MOCK.root or "."
function AddCSLuaFile() end
function include(path)
    local f = io.open(MOCK.root .. "/lua/" .. path, "r")
    assert(f, "include: fichier introuvable : " .. path)
    local src = f:read("*a")
    f:close()
    local chunk, err = loadstring(src, "@" .. path)
    assert(chunk, err)
    return chunk()
end

---------------------------------------------------------------------------
-- Parcours des panneaux
---------------------------------------------------------------------------
function MOCK.walk(root, fn)
    fn(root)
    for _, c in ipairs(root:GetChildren()) do MOCK.walk(c, fn) end
end

--- Appelle Think et Paint de chaque panneau (détecte les erreurs d'exécution du dessin).
function MOCK.exercise(root)
    local errors = {}
    MOCK.walk(root, function(p)
        for _, name in ipairs({ "Think", "Paint" }) do
            local f = rawget(p, name)
            if type(f) == "function" then
                local ok, err = pcall(f, p, p.__w or 100, p.__h or 40)
                if not ok then errors[#errors + 1] = (p.__class or "?") .. ":" .. name .. " -> " .. tostring(err) end
            end
        end
    end)
    return errors
end

--- Simule un clic sur chaque bouton de l'arbre (sauf ceux qu'on exclut).
function MOCK.clickAll(root, skip)
    local errors, n = {}, 0
    MOCK.walk(root, function(p)
        local f = rawget(p, "DoClick")
        if type(f) == "function" and not (skip and skip(p)) then
            n = n + 1
            local ok, err = pcall(f, p)
            if not ok then errors[#errors + 1] = "DoClick(" .. tostring(p.cwText or p.__class) .. ") -> " .. tostring(err) end
        end
    end)
    return errors, n
end
