--[[----------------------------------------------------------------------------
    ComputerWeb - Système de fichiers virtuel (client)

    Chaque joueur a son "disque" : data/computerweb/users/<SteamID64>/...
    Tous les chemins manipulés ici sont VIRTUELS ("Documents/Notes/todo.txt")
    et nettoyés : impossible de sortir du disque du joueur (pas de "..").
    Seuls les fichiers texte (.txt) sont gérés (limite imposée par GMod pour
    l'écriture dans data/).
------------------------------------------------------------------------------]]

local CW = ComputerWeb
CW.FS = CW.FS or {}
local FS = CW.FS

FS.Root        = "computerweb/users/"
FS.MaxFileSize = 65536   -- 64 Ko par fichier
FS.MaxEntries  = 300     -- éléments listés par dossier
FS.MaxDepth    = 8
FS.Ext         = ".txt"

local ACCENTS = {
    ["à"]="a",["â"]="a",["ä"]="a",["á"]="a",["ã"]="a",["å"]="a",
    ["ç"]="c",
    ["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",
    ["î"]="i",["ï"]="i",["í"]="i",["ì"]="i",
    ["ô"]="o",["ö"]="o",["ó"]="o",["ò"]="o",["õ"]="o",
    ["ù"]="u",["û"]="u",["ü"]="u",["ú"]="u",
    ["ÿ"]="y",["ñ"]="n",
    ["À"]="A",["Â"]="A",["Ä"]="A",["Ç"]="C",
    ["É"]="E",["È"]="E",["Ê"]="E",["Ë"]="E",
    ["Î"]="I",["Ï"]="I",["Ô"]="O",["Ö"]="O",["Ù"]="U",["Û"]="U",["Ü"]="U",
    ["œ"]="oe",["Œ"]="OE",["æ"]="ae",
}

local RESERVED = { con = true, prn = true, aux = true, nul = true }

---------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------

--- Rend un nom saisi par l'utilisateur utilisable : accents retirés,
--  caractères interdits supprimés. Renvoie nil si rien d'exploitable.
function FS.SanitizeName(name)
    name = tostring(name or "")
    name = name:gsub("[\xC3][\x80-\xBF]", function(c) return ACCENTS[c] or "" end)
    name = name:gsub("[\xC5][\x92\x93]", function(c) return ACCENTS[c] or "" end)
    name = name:gsub("[^%w _%-%.%(%)]", "")
    name = name:gsub("%s+", " ")
    name = name:gsub("^[%s%.]+", ""):gsub("[%s%.]+$", "")
    name = name:sub(1, 48)
    if name == "" then return nil end
    return name
end

function FS.ValidName(name)
    if type(name) ~= "string" or name == "" or #name > 48 then return false end
    if name:find("[^%w _%-%.%(%)]") then return false end
    if name:sub(1, 1) == "." or name:sub(-1) == "." or name:sub(-1) == " " then return false end
    local base = name:match("^([^%.]*)") or name
    local lower = base:lower()
    if RESERVED[lower] or lower:match("^com%d$") or lower:match("^lpt%d$") then return false end
    return true
end

--- Nom de fichier avec extension .txt garantie.
function FS.FileName(name)
    local clean = FS.SanitizeName(name)
    if not clean then return nil end
    if clean:lower():sub(-#FS.Ext) ~= FS.Ext then clean = clean .. FS.Ext end
    if #clean > 52 then return nil end
    return clean
end

---------------------------------------------------------------------------
-- Chemins
---------------------------------------------------------------------------

function FS.UserID()
    local id = "local"
    if LocalPlayer and IsValid(LocalPlayer()) then
        local sid = LocalPlayer():SteamID64()
        if sid and sid ~= "0" and sid ~= "" then id = sid end
    end
    return id
end

function FS.UserDir()
    return FS.Root .. FS.UserID()
end

--- Normalise un chemin virtuel. Renvoie "Dossier/Sous" ("" pour la racine) ou nil, raison.
function FS.Clean(vpath)
    local s = tostring(vpath or ""):gsub("\\", "/")
    local parts = {}
    for seg in s:gmatch("[^/]+") do
        if seg == "." then
            -- ignoré
        elseif seg == ".." then
            if #parts > 0 then parts[#parts] = nil end -- reste dans le disque
        else
            if not FS.ValidName(seg) then return nil, "Nom invalide : " .. seg end
            parts[#parts + 1] = seg
            if #parts > FS.MaxDepth then return nil, "Dossiers trop profonds" end
        end
    end
    return table.concat(parts, "/")
end

function FS.Join(a, b)
    if not a or a == "" then return b end
    if not b or b == "" then return a end
    return a .. "/" .. b
end

function FS.Parent(vpath)
    local clean = FS.Clean(vpath) or ""
    return clean:match("^(.*)/[^/]*$") or ""
end

function FS.Basename(vpath)
    return (tostring(vpath or ""):match("([^/]*)$")) or ""
end

--- Chemin réel dans data/ (ou nil, raison).
function FS.Real(vpath)
    local clean, err = FS.Clean(vpath)
    if not clean then return nil, err end
    local base = FS.UserDir()
    if clean == "" then return base end
    return base .. "/" .. clean
end

---------------------------------------------------------------------------
-- Opérations
---------------------------------------------------------------------------

local function ensureDir(real)
    local built = ""
    for seg in real:gmatch("[^/]+") do
        built = built == "" and seg or (built .. "/" .. seg)
        if not file.IsDir(built, "DATA") then file.CreateDir(built) end
    end
    return file.IsDir(real, "DATA")
end

function FS.Exists(vpath)
    local real = FS.Real(vpath)
    return real ~= nil and file.Exists(real, "DATA")
end

function FS.IsDir(vpath)
    local real = FS.Real(vpath)
    return real ~= nil and file.IsDir(real, "DATA")
end

--- Liste un dossier. Renvoie { dirs = {...}, files = {{name,size,time}, ...} } ou nil, raison.
function FS.List(vdir)
    local real, err = FS.Real(vdir)
    if not real then return nil, err end
    if not file.IsDir(real, "DATA") then return nil, "Dossier introuvable" end

    local rfiles, rdirs = file.Find(real .. "/*", "DATA")
    rfiles, rdirs = rfiles or {}, rdirs or {}

    local dirs, files = {}, {}
    for _, d in ipairs(rdirs) do
        if FS.ValidName(d) and #dirs < FS.MaxEntries then dirs[#dirs + 1] = d end
    end
    for _, f in ipairs(rfiles) do
        if f:lower():sub(-#FS.Ext) == FS.Ext and FS.ValidName(f) and #files < FS.MaxEntries then
            local path = real .. "/" .. f
            files[#files + 1] = {
                name = f,
                size = file.Size(path, "DATA") or 0,
                time = file.Time(path, "DATA") or 0,
            }
        end
    end
    table.sort(dirs, function(a, b) return a:lower() < b:lower() end)
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
    return { dirs = dirs, files = files }
end

function FS.MkDir(vpath)
    local clean, err = FS.Clean(vpath)
    if not clean or clean == "" then return false, err or "Nom invalide" end
    local real = FS.Real(clean)
    if file.Exists(real, "DATA") then return false, "Existe déjà" end
    if not ensureDir(real) then return false, "Impossible de créer le dossier" end
    return true
end

function FS.Read(vpath)
    local real, err = FS.Real(vpath)
    if not real then return nil, err end
    if not file.Exists(real, "DATA") or file.IsDir(real, "DATA") then return nil, "Fichier introuvable" end
    return file.Read(real, "DATA") or ""
end

function FS.Write(vpath, content)
    local clean, err = FS.Clean(vpath)
    if not clean or clean == "" then return false, err or "Nom invalide" end
    if clean:lower():sub(-#FS.Ext) ~= FS.Ext then return false, "Seuls les fichiers .txt sont pris en charge" end
    content = tostring(content or ""):gsub("%z", "")
    if #content > FS.MaxFileSize then
        return false, "Fichier trop gros (max " .. math.floor(FS.MaxFileSize / 1024) .. " Ko)"
    end

    local real = FS.Real(clean)
    if file.IsDir(real, "DATA") then return false, "Un dossier porte déjà ce nom" end
    if not ensureDir(FS.Real(FS.Parent(clean))) then return false, "Dossier parent introuvable" end

    file.Write(real, content)
    if not file.Exists(real, "DATA") then return false, "Écriture impossible" end
    return true
end

local function deleteTree(real, depth)
    if depth > FS.MaxDepth + 1 then return false end
    if file.IsDir(real, "DATA") then
        local files, dirs = file.Find(real .. "/*", "DATA")
        for _, f in ipairs(files or {}) do file.Delete(real .. "/" .. f) end
        for _, d in ipairs(dirs or {}) do deleteTree(real .. "/" .. d, depth + 1) end
    end
    file.Delete(real)
    return not file.Exists(real, "DATA")
end

function FS.Delete(vpath)
    local clean, err = FS.Clean(vpath)
    if not clean or clean == "" then return false, err or "Impossible de supprimer la racine" end
    local real = FS.Real(clean)
    if not file.Exists(real, "DATA") then return false, "Introuvable" end
    if not deleteTree(real, 0) then return false, "Suppression impossible" end
    return true
end

local function copyTree(srcReal, dstReal, depth)
    if depth > FS.MaxDepth + 1 then return false end
    if file.IsDir(srcReal, "DATA") then
        if not ensureDir(dstReal) then return false end
        local files, dirs = file.Find(srcReal .. "/*", "DATA")
        for _, f in ipairs(files or {}) do
            file.Write(dstReal .. "/" .. f, file.Read(srcReal .. "/" .. f, "DATA") or "")
        end
        for _, d in ipairs(dirs or {}) do
            if not copyTree(srcReal .. "/" .. d, dstReal .. "/" .. d, depth + 1) then return false end
        end
        return true
    end
    file.Write(dstReal, file.Read(srcReal, "DATA") or "")
    return file.Exists(dstReal, "DATA")
end

--- Renomme / déplace un fichier ou dossier.
function FS.Rename(vfrom, vto)
    local from, e1 = FS.Clean(vfrom)
    local to, e2 = FS.Clean(vto)
    if not from or from == "" then return false, e1 or "Source invalide" end
    if not to or to == "" then return false, e2 or "Destination invalide" end
    local rf, rt = FS.Real(from), FS.Real(to)
    if not file.Exists(rf, "DATA") then return false, "Introuvable" end
    if file.Exists(rt, "DATA") then return false, "Ce nom existe déjà" end
    if to:sub(1, #from + 1) == from .. "/" then return false, "Impossible de déplacer un dossier dans lui-même" end
    if not ensureDir(FS.Real(FS.Parent(to))) then return false, "Dossier de destination introuvable" end

    local isDir = file.IsDir(rf, "DATA")
    if not isDir and file.Rename then
        file.Rename(rf, rt)
        if file.Exists(rt, "DATA") and not file.Exists(rf, "DATA") then return true end
    end
    if not copyTree(rf, rt, 0) then return false, "Copie impossible" end
    if not deleteTree(rf, 0) then return false, "Source non supprimée" end
    return true
end

---------------------------------------------------------------------------
-- Premier démarrage : dossiers et fichier de bienvenue
---------------------------------------------------------------------------
function FS.Init()
    local base = FS.UserDir()
    local fresh = not file.IsDir(base, "DATA")
    ensureDir(base)
    if fresh then
        for _, d in ipairs({ "Bureau", "Documents", "Musique" }) do
            ensureDir(base .. "/" .. d)
        end
        file.Write(base .. "/Documents/Bienvenue.txt", table.concat({
            "Bienvenue sur ComputerWeb !",
            "",
            "- Ce disque est a vous : vos fichiers sont enregistres sur votre PC,",
            "  et vous les retrouvez sur tous les ordinateurs du jeu.",
            "- Ouvrez le Navigateur pour chercher sur le web.",
            "- Lancez la Musique pour ecouter une radio.",
            "- Essayez le Terminal : tapez 'help'.",
            "",
            "Bon jeu !",
        }, "\n"))
    end
end

function FS.FormatSize(bytes)
    bytes = tonumber(bytes) or 0
    if bytes < 1024 then return bytes .. " o" end
    return string.format("%.1f Ko", bytes / 1024)
end
