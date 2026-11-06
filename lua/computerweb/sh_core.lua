--[[----------------------------------------------------------------------------
    ComputerWeb - Noyau partagé (serveur + client)
      * ConVars de l'administrateur
      * Garde d'URL : décide ce qu'un joueur a le droit d'ouvrir
------------------------------------------------------------------------------]]

ComputerWeb = ComputerWeb or {}
local CW = ComputerWeb

CW.Version = "2.0.0"

---------------------------------------------------------------------------
-- ConVars (répliquées : l'admin règle côté serveur, les clients suivent)
---------------------------------------------------------------------------
local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

CW.CVars = CW.CVars or {}
local CV = CW.CVars

local function mk(key, name, default, help, min, max)
    if not CV[key] then
        CV[key] = CreateConVar(name, default, FLAGS, help, min, max)
    end
end

mk("browser",   "cw_browser_enabled",     "1",   "1 = navigateur web actif dans les ordinateurs",                  0, 1)
mk("music",     "cw_music_enabled",       "1",   "1 = application Musique active",                                  0, 1)
mk("safe",      "cw_safesearch",          "1",   "1 = recherche protégée (SafeSearch strict) dans les moteurs",     0, 1)
mk("filter",    "cw_url_filter",          "0",   "1 = liste blanche stricte (config.lua ou cw_allowed_domains)",    0, 1)
mk("domains",   "cw_allowed_domains",     "",    "Domaines autorisés séparés par des virgules (remplace config.lua si non vide)")
mk("private",   "cw_block_private_hosts", "1",   "1 = refuse localhost et les réseaux privés (192.168.x.x, ...)",   0, 1)
mk("usedist",   "cw_use_distance",        "130", "Distance max pour utiliser un ordinateur (unités)",               40, 500)
mk("sessdist",  "cw_session_distance",    "260", "Le bureau se ferme si le joueur s'éloigne de plus de X unités (0 = jamais)", 0, 2000)
mk("screendist","cw_screen_distance",     "700", "Distance max à laquelle un écran 3D charge sa page web",          100, 3000)
mk("screenurl", "cw_screen_custom_url",   "0",   "1 = tout joueur peut saisir une URL libre sur un écran 3D (sinon : admins seulement)", 0, 1)

---------------------------------------------------------------------------
-- Utilitaires texte
---------------------------------------------------------------------------
function CW.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function CW.URLEncode(s)
    s = tostring(s or "")
    return (s:gsub("([^%w%-%._~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

---------------------------------------------------------------------------
-- Garde d'URL
---------------------------------------------------------------------------

-- Protocoles qu'on refuse net (même si l'utilisateur les tape à la main).
local BLOCKED_SCHEMES = {
    javascript = true, data = true, file = true, about = true, chrome = true,
    ["view-source"] = true, asset = true, gmod = true, ftp = true, blob = true,
    filesystem = true, vbscript = true, steam = true, ws = true, wss = true,
    ["chrome-extension"] = true, resource = true, mailto = true, tel = true,
}

--- Découpe une URL absolue. Renvoie scheme, host (minuscule) ou nil.
function CW.ParseURL(url)
    url = tostring(url or "")
    local scheme, rest = url:match("^(%a[%w+.-]*)://(.*)$")
    if not scheme then return nil end
    scheme = scheme:lower()

    local authority = rest:match("^([^/?#]*)") or ""
    authority = authority:gsub("^.*@", "") -- retire user:pass@ (astuce http://site@127.0.0.1)

    local host
    if authority:sub(1, 1) == "[" then
        host = authority:match("^(%[.-%])") or authority
    else
        host = authority:gsub(":%d*$", "")
    end
    host = host:lower():gsub("%.+$", "")
    return scheme, host
end

local function isCanonicalPublicIPv4(host)
    local a, b, c, d = host:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    -- refuse les zéros en tête (notation octale ambiguë : 0177.0.0.1)
    for _, part in ipairs({ a, b, c, d }) do
        if #part > 1 and part:sub(1, 1) == "0" then return false end
        if tonumber(part) > 255 then return false end
    end
    a, b = tonumber(a), tonumber(b)
    if a == 0 or a == 10 or a == 127 or a >= 224 then return false end
    if a == 169 and b == 254 then return false end
    if a == 172 and b >= 16 and b <= 31 then return false end
    if a == 192 and b == 168 then return false end
    if a == 100 and b >= 64 and b <= 127 then return false end
    return true
end

--- true si l'hôte vise la machine locale / un réseau privé / une adresse suspecte.
function CW.IsPrivateHost(host)
    host = tostring(host or ""):lower()
    if host == "" then return true end
    if host == "localhost" then return true end
    for _, suffix in ipairs({ ".localhost", ".local", ".internal", ".lan", ".home", ".corp", ".intranet" }) do
        if host:sub(-#suffix) == suffix then return true end
    end
    if host:sub(1, 1) == "[" then return true end -- littéraux IPv6 : refusés

    -- Hôte entièrement numérique (2130706433, 0x7f000001, 0177.0.0.1 ...)
    local allNumeric = true
    for label in host:gmatch("[^%.]+") do
        if not (label:match("^%d+$") or label:match("^0[xX]%x+$")) then
            allNumeric = false
            break
        end
    end
    if allNumeric then
        local ok = isCanonicalPublicIPv4(host)
        return ok ~= true
    end
    return false
end

local function splitList(s)
    local out = {}
    for item in tostring(s or ""):gmatch("[^,%s;]+") do
        out[#out + 1] = item
    end
    return out
end

local function normalizeDomain(d)
    d = tostring(d or ""):lower()
    d = d:gsub("^%*%.", ""):gsub("^%.", ""):gsub("%.$", "")
    return d
end

local function hostMatches(host, list)
    host = normalizeDomain(host)
    for _, entry in ipairs(list or {}) do
        local d = normalizeDomain(entry)
        if d ~= "" and (host == d or host:sub(-(#d + 1)) == "." .. d) then
            return true
        end
    end
    return false
end
CW.HostMatches = hostMatches

function CW.GetAllowedDomains()
    local override = CV.domains and CV.domains:GetString() or ""
    if CW.Trim(override) ~= "" then return splitList(override) end
    return (CW.Config and CW.Config.AllowedDomains) or {}
end

--- Vérifie une URL absolue.
--  opts.skipAllowlist : ne pas appliquer la liste blanche (flux musicaux prédéfinis)
--  Renvoie true  OU  false, "raison lisible".
function CW.CheckURL(url, opts)
    opts = opts or {}
    url = tostring(url or "")
    if #url > 2048 then return false, "Adresse trop longue" end

    local scheme, host = CW.ParseURL(url)
    if not scheme then return false, "Adresse invalide" end
    if scheme ~= "http" and scheme ~= "https" then
        return false, "Protocole non autorisé (" .. scheme .. ")"
    end
    if hostMatches(host, CW.Config and CW.Config.BlockedDomains) then
        return false, "Site bloqué par l'administrateur"
    end
    if CV.private:GetBool() and CW.IsPrivateHost(host) then
        return false, "Adresse locale ou réseau privé refusée"
    end
    if not opts.skipAllowlist and CV.filter:GetBool() and not hostMatches(host, CW.GetAllowedDomains()) then
        return false, "Site non autorisé sur ce serveur"
    end
    if hook and hook.Run and hook.Run("ComputerWeb_CanOpenURL", url, host) == false then
        return false, "Refusé par le serveur"
    end
    return true
end

--- Transforme ce que l'utilisateur a tapé en URL (ou en recherche).
--  engineKey : clé dans Config.SearchEngines (défaut : DefaultSearchEngine)
--  Renvoie url  OU  nil, "raison".
function CW.ResolveInput(text, engineKey)
    text = CW.Trim(text)
    if text == "" then return nil, "Adresse vide" end

    local scheme = text:match("^(%a[%w+.-]*):")
    local url

    if text:match("^[Hh][Tt][Tt][Pp][Ss]?://") then
        url = text
    elseif scheme and BLOCKED_SCHEMES[scheme:lower()] then
        return nil, "Protocole non autorisé (" .. scheme:lower() .. ")"
    elseif not text:find("%s") and (text:match("^[%w%-%.]+%.%a%a+[/?#:]?") or text:match("^[%w%-%.]+%.%a%a+$")
            or text:match("^localhost[:/]?") or text:match("^%d+%.%d+%.%d+%.%d+")) then
        url = "https://" .. text
    else
        local cfg = CW.Config or {}
        local engines = cfg.SearchEngines or {}
        local eng = engines[engineKey or ""] or engines[cfg.DefaultSearchEngine or ""] or engines.duckduckgo
        if not eng then return nil, "Aucun moteur de recherche configuré" end
        local enc = CW.URLEncode(text)
        url = eng.url:gsub("%%s", function() return enc end)
        if CV.safe:GetBool() and eng.safe then url = url .. eng.safe end
    end

    local ok, why = CW.CheckURL(url)
    if not ok then return nil, why end
    return url
end

--- Peut-on utiliser cet ordinateur ? (serveur : autorité ; client : informatif)
function CW.CanUseComputer(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if not IsValid(ent) then return false end
    local maxDist = CV.usedist:GetFloat()
    if ply:GetPos():Distance(ent:GetPos()) > maxDist + 80 then return false end
    if hook.Run("ComputerWeb_CanUse", ply, ent) == false then return false end
    return true
end
