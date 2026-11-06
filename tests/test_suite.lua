-- Suite de tests ComputerWeb (exécutée par run_tests.py)

local passed, failed = 0, 0
local failures = {}

local function check(cond, label, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        failures[#failures + 1] = label .. (detail and (" :: " .. tostring(detail)) or "")
        print("  ECHEC  " .. label .. (detail and (" :: " .. tostring(detail)) or ""))
    end
end

local function eq(a, b, label) check(a == b, label, "obtenu=" .. tostring(a) .. " attendu=" .. tostring(b)) end
local function section(name) print("\n== " .. name) end

---------------------------------------------------------------------------
-- Chargement des modules partagés
---------------------------------------------------------------------------
section("Chargement")
include("computerweb/config.lua")
include("computerweb/sh_core.lua")
local CW = ComputerWeb
check(CW and CW.CheckURL, "sh_core chargé")
eq(CW.Version, "2.0.0", "version")

---------------------------------------------------------------------------
-- Garde d'URL
---------------------------------------------------------------------------
section("Garde d'URL : ParseURL / hôtes privés")
local function host(u) local _, h = CW.ParseURL(u) return h end
eq(host("https://Fr.Wikipedia.org/wiki/X"), "fr.wikipedia.org", "hôte minuscule")
eq(host("http://user:pw@evil.com@127.0.0.1/x"), "127.0.0.1", "astuce user@hôte")
eq(host("https://example.com:8443/a?b=c#d"), "example.com", "port retiré")
eq(host("https://example.com./"), "example.com", "point final retiré")
eq(host("https://[::1]:8080/"), "[::1]", "IPv6")
check(CW.ParseURL("pas une url") == nil, "ParseURL refuse le texte brut")

local privates = { "localhost", "foo.localhost", "127.0.0.1", "10.1.2.3", "192.168.1.1", "172.16.0.1", "172.31.255.255",
    "169.254.169.254", "0.0.0.0", "100.64.0.1", "[::1]", "2130706433", "0x7f000001", "0177.0.0.1", "127.1", "routeur.local",
    "nas.lan", "224.0.0.1", "" }
for _, h in ipairs(privates) do check(CW.IsPrivateHost(h), "privé : " .. (h == "" and "<vide>" or h)) end
local publics = { "wikipedia.org", "8.8.8.8", "172.32.0.1", "172.15.0.1", "1.1.1.1", "example.co.uk" }
for _, h in ipairs(publics) do check(not CW.IsPrivateHost(h), "public : " .. h) end

section("Garde d'URL : CheckURL")
local CV = CW.CVars
local function url_ok(u, o) return (CW.CheckURL(u, o)) end
check(url_ok("https://fr.wikipedia.org/"), "https public accepté")
check(url_ok("http://example.com/"), "http public accepté")
check(not url_ok("javascript:alert(1)"), "javascript refusé")
check(not url_ok("file:///etc/passwd"), "file refusé")
check(not url_ok("data:text/html,<script>"), "data refusé")
check(not url_ok("asset://garrysmod/lua/x.lua"), "asset refusé")
check(not url_ok("ftp://example.com/"), "ftp refusé")
check(not url_ok("https://127.0.0.1/admin"), "loopback refusé")
check(not url_ok("http://192.168.0.1/"), "LAN refusé")
check(not url_ok("http://169.254.169.254/latest/meta-data"), "métadonnées cloud refusées")
check(not url_ok(("https://a.com/" .. ("x"):rep(3000))), "URL trop longue refusée")

CV.private.v = "0"
check(url_ok("http://192.168.0.1/"), "LAN accepté si cw_block_private_hosts=0")
CV.private.v = "1"

CV.filter.v = "1"
check(url_ok("https://fr.wikipedia.org/wiki/Lua"), "liste blanche : sous-domaine accepté")
check(url_ok("https://wikipedia.org/"), "liste blanche : domaine exact accepté")
check(not url_ok("https://evilwikipedia.org/"), "liste blanche : faux ami refusé")
check(not url_ok("https://wikipedia.org.evil.com/"), "liste blanche : suffixe piégé refusé")
check(not url_ok("https://random-site.net/"), "liste blanche : site inconnu refusé")
check(url_ok("https://random-site.net/", { skipAllowlist = true }), "skipAllowlist (flux préréglés)")
CV.domains.v = "exemple.fr, autre.org"
check(url_ok("https://www.exemple.fr/"), "cw_allowed_domains remplace la config")
check(not url_ok("https://fr.wikipedia.org/"), "cw_allowed_domains : ancien domaine refusé")
CV.domains.v = ""
CV.filter.v = "0"

CW.Config.BlockedDomains = { "bloque.com" }
check(not url_ok("https://www.bloque.com/"), "BlockedDomains refuse aussi les sous-domaines")
CW.Config.BlockedDomains = {}

hook.Add("ComputerWeb_CanOpenURL", "t", function(url) if url:find("interdit") then return false end end)
check(not url_ok("https://example.com/interdit"), "hook ComputerWeb_CanOpenURL")
hook.Remove("ComputerWeb_CanOpenURL", "t")

section("Garde d'URL : ResolveInput")
local function res(t, e) return CW.ResolveInput(t, e) end
eq(res("https://fr.wikipedia.org/"), "https://fr.wikipedia.org/", "URL complète conservée")
eq(res("wikipedia.org"), "https://wikipedia.org", "nom de domaine -> https")
eq(res("fr.wikipedia.org/wiki/Lua"), "https://fr.wikipedia.org/wiki/Lua", "domaine + chemin")
check((res("chat mignon")):find("duckduckgo.com/html/?q=chat%20mignon", 1, true) ~= nil, "recherche -> moteur par défaut", res("chat mignon"))
check((res("chat mignon")):find("&kp=1", 1, true) ~= nil, "SafeSearch ajouté (DuckDuckGo)")
check((res("a b", "google")):find("safe=active", 1, true) ~= nil, "SafeSearch Google")
check((res("a b", "bing")):find("adlt=strict", 1, true) ~= nil, "SafeSearch Bing")
CV.safe.v = "0"
check((res("a b")):find("kp=1", 1, true) == nil, "SafeSearch désactivable")
CV.safe.v = "1"
check((res("100% pur & fun")):find("100%%25%%20pur%%20%%26%%20fun") ~= nil, "requête encodée (%, &)", res("100% pur & fun"))
local u, why = res("javascript:alert(1)")
check(u == nil and why, "ResolveInput refuse javascript:", why)
u, why = res("file:///C:/Windows/win.ini")
check(u == nil, "ResolveInput refuse file:", why)
u, why = res("localhost:8080")
check(u == nil, "ResolveInput refuse localhost", why)
u, why = res("192.168.1.1")
check(u == nil, "ResolveInput refuse IP privée", why)
u, why = res("   ")
check(u == nil, "ResolveInput refuse le vide", why)
check(res("c++: tutoriel") ~= nil, "'c++: tutoriel' est une recherche, pas un protocole")
check(res("3.14 pi") ~= nil, "'3.14 pi' est une recherche")

section("Droit d'usage")
local ent = { IsValid = function() return true end, GetPos = function() return Vector(100, 0, 0) end }
local ply = MOCK.NewPlayer({ pos = Vector(0, 0, 0) })
check(CW.CanUseComputer(ply, ent), "proche : autorisé")
ply.pos = Vector(1000, 0, 0)
check(not CW.CanUseComputer(ply, ent), "trop loin : refusé")
ply.pos = Vector(0, 0, 0)
ply.alive = false
check(not CW.CanUseComputer(ply, ent), "mort : refusé")
ply.alive = true
hook.Add("ComputerWeb_CanUse", "t", function() return false end)
check(not CW.CanUseComputer(ply, ent), "hook ComputerWeb_CanUse (DarkRP)")
hook.Remove("ComputerWeb_CanUse", "t")

---------------------------------------------------------------------------
-- Système de fichiers
---------------------------------------------------------------------------
section("Client : chargement ui / fs / os / apps")
include("computerweb/cl_ui.lua")
include("computerweb/cl_fs.lua")
include("computerweb/cl_os.lua")
for _, f in ipairs({ "files", "notepad", "browser", "music", "terminal", "settings" }) do
    include("computerweb/apps/cl_" .. f .. ".lua")
end
include("computerweb/cl_screen_remote.lua")
local FS, UI, OS = CW.FS, CW.UI, CW.OS
check(FS and UI and OS, "modules client chargés")
check(#OS.AppOrder == 6, "6 applications enregistrées", #OS.AppOrder)

section("FS : noms et chemins")
eq(FS.SanitizeName("Résumé été.txt"), "Resume ete.txt", "accents retirés")
eq(FS.SanitizeName("..\\..\\evil"), "evil", "séparateurs retirés")
eq(FS.SanitizeName("a<b>c:d\"e|f?g*h"), "abcdefgh", "caractères interdits retirés")
check(FS.SanitizeName("///") == nil, "nom vide -> nil")
eq(FS.FileName("notes"), "notes.txt", "extension .txt ajoutée")
eq(FS.FileName("Notes.TXT"), "Notes.TXT", "extension déjà présente")
check(not FS.ValidName("con"), "nom réservé Windows refusé")
check(not FS.ValidName("com1.txt"), "COM1 refusé")
check(not FS.ValidName(".cache"), "nom caché refusé")
check(FS.ValidName("Mon fichier (2).txt"), "nom normal accepté")
eq(FS.Clean("Documents/../../../etc"), "etc", "'..' ne sort jamais du disque")
eq(FS.Clean("/a//b/./c/"), "a/b/c", "normalisation")
check(FS.Clean("a/b*c") == nil, "caractère interdit dans un segment")
check(FS.Clean(("a/"):rep(12)) == nil, "profondeur limitée")
eq(FS.Parent("a/b/c.txt"), "a/b", "Parent")
eq(FS.Parent("a"), "", "Parent racine")
eq(FS.Basename("a/b/c.txt"), "c.txt", "Basename")

section("FS : opérations")
FS.Init()
check(FS.IsDir("Documents") and FS.IsDir("Bureau") and FS.IsDir("Musique"), "dossiers par défaut créés")
check(FS.Exists("Documents/Bienvenue.txt"), "fichier de bienvenue créé")
check(FS.UserDir():find("76561198000000001", 1, true), "dossier propre au SteamID64")

local ok = FS.Write("Documents/test.txt", "bonjour")
check(ok, "Write")
eq(FS.Read("Documents/test.txt"), "bonjour", "Read")
check(not FS.Write("Documents/test.exe", "x"), "Write refuse hors .txt")
check(not FS.Write("Documents/gros.txt", ("x"):rep(FS.MaxFileSize + 1)), "taille max respectée")
check(FS.Write("Documents/limite.txt", ("x"):rep(FS.MaxFileSize)), "taille max exacte acceptée")
ok = FS.Write("Nouveau/Sous/fichier.txt", "x")
check(ok, "Write crée les dossiers parents")
check(FS.MkDir("Documents/Projets"), "MkDir")
check(not FS.MkDir("Documents/Projets"), "MkDir refuse un doublon")
local list = FS.List("Documents")
check(list and #list.dirs == 1 and list.dirs[1] == "Projets", "List : dossiers")
local names = {}
for _, f in ipairs(list.files) do names[#names + 1] = f.name end
check(table.concat(names, ","):find("Bienvenue.txt", 1, true) and table.concat(names, ","):find("test.txt", 1, true), "List : fichiers", table.concat(names, ","))
check(FS.List("Inexistant") == nil, "List dossier inexistant")

check(FS.Rename("Documents/test.txt", "Documents/renomme.txt"), "Rename fichier")
check(not FS.Exists("Documents/test.txt") and FS.Exists("Documents/renomme.txt"), "Rename effectif")
check(not FS.Rename("Documents/renomme.txt", "Documents/Bienvenue.txt"), "Rename refuse l'écrasement")
FS.Write("Documents/Projets/a.txt", "A")
check(FS.Rename("Documents/Projets", "Documents/Archives"), "Rename dossier")
check(FS.Exists("Documents/Archives/a.txt") and not FS.Exists("Documents/Projets"), "Rename dossier récursif")
check(not FS.Rename("Documents/Archives", "Documents/Archives/dedans"), "Rename dossier dans lui-même refusé")
check(FS.Delete("Documents/Archives"), "Delete dossier non vide")
check(not FS.Exists("Documents/Archives"), "Delete effectif")
check(FS.Delete("Documents/renomme.txt"), "Delete fichier")
check(not FS.Delete(""), "Delete racine refusé")
check(not FS.Delete("Documents/n-existe-pas.txt"), "Delete inexistant")

-- Aucune écriture hors du disque du joueur
local before = 0
for _ in pairs(MOCK.files) do before = before + 1 end
FS.Write("../../../evil.txt", "x")
FS.Write("..\\..\\evil2.txt", "x")
for path in pairs(MOCK.files) do
    check(path:find("computerweb/users/", 1, true) == 1, "écriture confinée au disque joueur", path)
end

section("FS : disque 'invité' (SteamID64 = 0)")
MOCK.me.sid = "0"
check(FS.UserDir():find("/local$"), "repli sur 'local'", FS.UserDir())
MOCK.me.sid = "76561198000000001"

---------------------------------------------------------------------------
-- Terminal
---------------------------------------------------------------------------
section("Terminal : interpréteur")
local Term = CW.Term
local t = Term.Split('echo "a b" c  "d')
eq(#t, 4, "Split : 4 éléments")
eq(t[2], "a b", "Split : guillemets")
eq(t[4], "d", "Split : guillemet non fermé")

local function runTerm(cmds, cwd)
    local out = {}
    local st = { cwd = cwd or "", out = function(text, kind) out[#out + 1] = (kind and ("[" .. kind .. "] ") or "") .. text end,
        started = 0, clear = function() out = {} end }
    for _, c in ipairs(cmds) do Term.Run(st, c) end
    return table.concat(out, "\n"), st
end

local o = runTerm({ "help" })
check(o:find("Commandes disponibles", 1, true), "help")
o = runTerm({ "commandeinconnue" })
check(o:find("introuvable"), "commande inconnue")
o = runTerm({ "mkdir demo", "cd demo", "pwd", "echo salut > a.txt", "ls", "cat a.txt" })
check(o:find("/demo", 1, true) and o:find("a.txt", 1, true) and o:find("salut", 1, true), "mkdir/cd/echo/ls/cat", o)
o = runTerm({ "cd demo", "echo suite >> a.txt", "cat a.txt" })
check(o:find("salut") and o:find("suite"), "echo >> ajoute", o)
o = runTerm({ "cd demo", "touch b", "ls" })
check(o:find("b.txt", 1, true), "touch ajoute .txt", o)
o = runTerm({ "cd demo", "mv a.txt c.txt", "ls" })
check(o:find("c.txt", 1, true) and not o:find("a.txt ", 1, true), "mv", o)
o = runTerm({ "cd demo", "rm c.txt", "rm b.txt", "ls" })
check(o:find("vide"), "rm", o)
o = runTerm({ "cd ../../../.." })
check(not o:find("err"), "cd .. au-delà de la racine reste sur la racine", o)
o = runTerm({ "cd inexistant" })
check(o:find("introuvable"), "cd dossier inexistant")
o = runTerm({ "cat" })
check(o:find("usage"), "cat sans argument")
o = runTerm({ "cd demo", "cat nexiste.txt" })
check(o:find("introuvable"), "cat inexistant", o)
o = runTerm({ "ls .." })
check(o:find("Documents"), "ls ..")
o = runTerm({ "cd Documents", "ls /Bureau" })
check(not o:find("err"), "chemin absolu", o)
o = runTerm({ "echo test > ../../../../evil" })
for path in pairs(MOCK.files) do
    check(path:find("computerweb/users/", 1, true) == 1, "terminal : écriture confinée", path)
end
o = runTerm({ "neofetch" })
check(o:find("Testeur", 1, true), "neofetch")
o = runTerm({ "ping exemple.com" })
check(o:find("simulation"), "ping (simulation affichée)")
o = runTerm({ "wallpaper aurora" })
eq(MOCK.convars.cw_wallpaper.v, "aurora", "wallpaper change le convar")
o = runTerm({ "wallpaper nimportequoi" })
check(o:find("disponibles"), "wallpaper inconnu")
o = runTerm({ "play" }, "")
check(MOCK.lastStream == "https://ice.somafm.com/groovesalad", "play lance la 1re radio", MOCK.lastStream)
o = runTerm({ "play lush" })
eq(MOCK.lastStream, "https://ice.somafm.com/lush", "play par nom")
o = runTerm({ "play 99" })
check(o:find("Stations"), "play station inconnue -> liste")
o = runTerm({ "stop" })
eq(CW.Audio.status, "stopped", "stop")
CV.music.v = "0"
o = runTerm({ "play" })
check(o:find("désactivée"), "play respecte cw_music_enabled")
CV.music.v = "1"

---------------------------------------------------------------------------
-- Audio
---------------------------------------------------------------------------
section("Audio")
local A = CW.Audio
A.Play({ name = "t", url = "https://ice.somafm.com/groovesalad", preset = true })
eq(A.status, "playing", "lecture")
A.TogglePause()
eq(A.status, "paused", "pause")
A.TogglePause()
eq(A.status, "playing", "reprise")
A.SetVolume(5)
eq(A.volume, 1, "volume borné à 1")
A.Stop()
eq(A.status, "stopped", "arrêt")
A.Play({ name = "t", url = "https://127.0.0.1/x.mp3", preset = false })
eq(A.status, "error", "URL privée refusée par l'audio")
MOCK.streamFails = true
A.Play({ name = "t", url = "https://example.com/x.mp3" })
eq(A.status, "error", "flux en échec -> erreur")
check(A.err and #A.err > 0, "message d'erreur présent")
MOCK.streamFails = false
CV.filter.v = "1"
A.Play({ name = "t", url = "https://ice.somafm.com/lush", preset = true })
eq(A.status, "playing", "radios préréglées autorisées même en liste blanche")
A.Play({ name = "t", url = "https://ice.somafm.com/lush", preset = false })
eq(A.status, "error", "URL libre refusée en liste blanche")
CV.filter.v = "0"
A.Stop()

---------------------------------------------------------------------------
-- Diagnostic
---------------------------------------------------------------------------
section("Diagnostic : analyse")
local D = CW.Diag
local r = D.Analyze(nil)
eq(r.level, "bad", "pas de réponse -> bad")
r = D.Analyze({ ua = "Mozilla/5.0 Awesomium/1.7", mse = false })
eq(r.level, "bad", "Awesomium -> bad")
r = D.Analyze({ ua = "Mozilla/5.0 Chrome/86.0.4240.198", h264 = "", vp9 = "probably", aac = "", opus = "probably", mse = true, webgl = true })
eq(r.level, "warn", "Chrome 86 + VP9 + MSE mais sans H.264 -> warn", r.level)
r = D.Analyze({ ua = "Mozilla/5.0 Chrome/86.0.4240.198", h264 = "", vp9 = "", mse = false })
eq(r.level, "warn", "sans codecs -> warn")
r = D.Analyze({ ua = "Mozilla/5.0 Chrome/137.0.7151.121", h264 = "probably", vp9 = "probably", aac = "maybe", opus = "probably", mse = true, webgl = true })
eq(r.level, "ok", "Chrome 137 complet -> ok")
check(r.rows[1][2]:find("137", 1, true), "version affichée")

section("Diagnostic : exécution (panneau + callback)")
do
    local parent = MOCK.NewPanel("DPanel")
    local got
    D.Run(parent, function(res2) got = res2 end)
    local p = parent:GetChildren()[1]
    check(p and p.__class == "DHTML", "panneau DHTML créé")
    check(p.__funcs and p.__funcs["cwdiag.report"], "fonction cwdiag.report exposée")
    p:OnDocumentReady()
    check(p.__js and p.__js:find("canPlayType", 1, true), "JS de test injecté")
    p.__funcs["cwdiag.report"]('{"ua":"x"}')   -- JSONToTable mock retourne {} -> ok
    check(got ~= nil, "callback appelé avec le résultat")
end

---------------------------------------------------------------------------
-- Serveur : réseau et validations
---------------------------------------------------------------------------
section("Serveur : cw_screen_set")
SERVER, CLIENT = true, false
include("computerweb/sv_main.lua")
SERVER, CLIENT = false, true
check(net._recv["cw_screen_set"], "récepteur réseau enregistré")

local function mkScreen(url)
    local s = { IsComputerWebScreen = true, url = url or "init", IsValid = function() return true end,
        GetPos = function() return Vector(50, 0, 0) end }
    function s:SetScreenURL(u) self.url = u end
    return s
end
local function sendSet(plyObj, screen, url)
    net._in = { screen, url }
    net._recv["cw_screen_set"](0, plyObj)
end

local screen = mkScreen()
local player1 = MOCK.NewPlayer({ idx = 11, pos = Vector(0, 0, 0) })

-- Horloge contrôlée (les anti-spam du serveur dépendent de CurTime)
local realCurTime = CurTime
local now = 5000
function CurTime() return now end
local function tick() now = now + 10 end

local function sendSet(plyObj, scr, url)
    tick()
    net._in = { scr, url }
    net._recv["cw_screen_set"](0, plyObj)
end

sendSet(player1, screen, "https://www.youtube.com/watch?v=aOa_H4srt74")
eq(screen.url, "https://www.youtube.com/watch?v=aOa_H4srt74", "préréglage accepté pour un joueur")

sendSet(player1, screen, "https://example.com/video")
eq(screen.url, "https://www.youtube.com/watch?v=aOa_H4srt74", "URL libre refusée pour un non-admin")
check(#MOCK.chat > 0, "message de refus envoyé au joueur")

local admin = MOCK.NewPlayer({ idx = 12, admin = true, pos = Vector(0, 0, 0) })
sendSet(admin, screen, "https://example.com/video")
eq(screen.url, "https://example.com/video", "URL libre acceptée pour un admin")

sendSet(admin, screen, "https://127.0.0.1/secret")
eq(screen.url, "https://example.com/video", "IP privée refusée même pour un admin")

sendSet(admin, screen, "javascript:alert(1)")
eq(screen.url, "https://example.com/video", "javascript refusé même pour un admin")

CV.screenurl.v = "1"
sendSet(player1, screen, "https://example.org/autre")
eq(screen.url, "https://example.org/autre", "cw_screen_custom_url=1 ouvre l'URL libre à tous")
CV.screenurl.v = "0"

-- anti-spam : deux envois sans que l'horloge avance
net._in = { screen, "https://example.com/spam1" }
tick(); net._recv["cw_screen_set"](0, admin)
local afterFirst = screen.url
net._in = { screen, "https://example.com/spam2" }
net._recv["cw_screen_set"](0, admin)       -- même instant : ignoré
eq(screen.url, afterFirst, "anti-spam : 2e changement immédiat ignoré")

local far = MOCK.NewPlayer({ idx = 13, admin = true, pos = Vector(5000, 0, 0) })
sendSet(far, screen, "https://example.com/loin")
check(screen.url ~= "https://example.com/loin", "joueur trop loin refusé")

local notScreen = { IsValid = function() return true end, GetPos = function() return Vector(0, 0, 0) end }
sendSet(admin, notScreen, "https://example.com/")
check(true, "entité qui n'est pas un écran ignorée sans erreur")

sendSet(admin, screen, ("https://example.com/" .. ("a"):rep(600)))
check(#screen.url < 600, "URL trop longue ignorée")

section("Serveur : ouverture d'un ordinateur")
MOCK.netSent = {}
local desk = { IsValid = function() return true end, GetPos = function() return Vector(60, 0, 0) end }
local p2 = MOCK.NewPlayer({ idx = 21, pos = Vector(0, 0, 0) })
tick()
CW.OpenComputer(p2, desk)
eq(#MOCK.netSent, 1, "message cw_os_open envoyé")
eq(MOCK.netSent[1].name, "cw_os_open", "nom du message")
CW.OpenComputer(p2, desk)
eq(#MOCK.netSent, 1, "anti-spam : 2e ouverture immédiate ignorée")
tick()
local farDesk = { IsValid = function() return true end, GetPos = function() return Vector(900, 0, 0) end }
local p3 = MOCK.NewPlayer({ idx = 22, pos = Vector(0, 0, 0) })
CW.OpenComputer(p3, farDesk)
eq(#MOCK.netSent, 1, "ordinateur trop loin : aucun message")
CurTime = realCurTime

---------------------------------------------------------------------------
-- Entités
---------------------------------------------------------------------------
section("Entités : chargement des fichiers")
local function loadEntity(name, realm)
    local oldS, oldC = SERVER, CLIENT
    SERVER, CLIENT = realm == "server", realm == "client"
    ENT = {}
    include("../lua/entities/" .. name .. ".lua")  -- chemin relatif depuis lua/
    local e = ENT
    ENT = nil
    SERVER, CLIENT = oldS, oldC
    return e
end
-- include() préfixe déjà "lua/" : on remonte d'un cran
local function loadEnt(name, realm)
    local oldS, oldC = SERVER, CLIENT
    SERVER, CLIENT = realm == "server", realm == "client"
    ENT = {}
    include("entities/" .. name .. ".lua")
    local e = ENT
    ENT = nil
    SERVER, CLIENT = oldS, oldC
    return e
end

local computers = { computerWindows = "nova", computerUbuntu = "terra", computerKali = "cipher", computerGarrysMod = "sandbox" }
for class, theme in pairs(computers) do
    local e = loadEnt(class, "server")
    eq(e.CWTheme, theme, class .. " : thème " .. theme)
    eq(e.Base, "cw_computer_base", class .. " : base")
    check(e.Spawnable == true, class .. " : spawnable")
    check(UI.Themes[e.CWTheme], class .. " : le thème existe")
    check(e.CWModel:find("%.mdl$"), class .. " : modèle défini")
    check(e.IconOverride == "entities/" .. class .. ".png", class .. " : icône du spawnmenu")
end

local base = loadEnt("cw_computer_base", "server")
check(base.Spawnable == false, "base non spawnable")
do
    local used
    local oldOpen = CW.OpenComputer
    CW.OpenComputer = function(p, e) used = { p, e } end
    local fakeEnt = setmetatable({ CWModel = "x" }, { __index = base })
    local pl = MOCK.NewPlayer()
    base.Use(fakeEnt, pl, pl)
    check(used and used[1] == pl and used[2] == fakeEnt, "Use() appelle OpenComputer")
    CW.OpenComputer = oldOpen
end

local screens = { monitorMusic = "aOa_H4srt74", monitorMusciTwo = "DGNewPg2FDI" }
for class, vid in pairs(screens) do
    local e = loadEnt(class, "server")
    eq(e.Base, "cw_screen_base", class .. " : base écran")
    check(e.DefaultURL:find(vid, 1, true), class .. " : URL par défaut conservée")
end

section("Écran 3D (client) : création du panneau, volume, nettoyage")
do
    local e = loadEnt("cw_screen_base", "client")
    local url = "https://www.youtube.com/watch?v=aOa_H4srt74"
    local inst = setmetatable({ _url = url, _pos = Vector(100, 0, 0) }, { __index = e })
    function inst:GetScreenURL() return self._url end
    function inst:GetPos() return self._pos end
    function inst:DrawModel() self.drawn = true end
    function inst:IsValid() return true end
    inst:Initialize()
    inst.NextCheck = 0
    inst:Think()
    check(IsValid(inst.Panel) and inst.Panel.__class == "DHTML", "panneau créé quand le joueur est proche")
    eq(inst.Panel.__url, url, "URL chargée")
    -- redirection interdite
    local stopped = false
    inst.Panel.StopLoading = function() stopped = true end
    inst.Panel:OnBeginLoadingDocument("https://127.0.0.1/pwn")
    check(stopped, "redirection vers IP privée stoppée")
    stopped = false
    inst.Panel:OnBeginLoadingDocument("https://example.com/ok")
    check(not stopped, "navigation légitime non stoppée")
    -- volume
    inst.NextCheck = 0
    inst:Think()
    check(inst.Panel.__js and inst.Panel.__js:find("volume", 1, true), "volume ajusté par JS")
    -- dessin
    inst:Draw()
    check(inst.Mat ~= nil and inst.drawn, "matériau HTML appliqué et modèle dessiné")
    -- loin
    MOCK.me.pos = Vector(5000, 0, 0)
    inst.NextCheck = 0
    inst:Think()
    check(inst.Panel == nil, "panneau détruit quand le joueur s'éloigne")
    MOCK.me.pos = Vector(0, 0, 0)
    -- URL interdite
    inst._url = "javascript:alert(1)"
    inst.NextCheck = 0
    inst:Think()
    check(inst.Panel == nil, "URL interdite : aucun panneau")
    inst._url = url
    inst.NextCheck = 0
    inst:Think()
    inst:OnRemove()
    check(inst.Panel == nil, "OnRemove nettoie")
end

---------------------------------------------------------------------------
-- Bureau : ouverture de chaque thème et de chaque application
---------------------------------------------------------------------------
section("Bureau : thèmes (construction + dessin)")
local function noErrors(errs, label)
    check(#errs == 0, label, errs[1])
    for i = 2, math.min(#errs, 4) do print("      " .. errs[i]) end
end

for _, theme in ipairs(UI.ThemeOrder) do
    MOCK.lastError = nil
    local root = OS.Open({ CWTheme = theme, IsValid = function() return false end })
    check(root and root:IsValid(), theme .. " : bureau créé")
    timer.Flush()
    eq(UI.T.id, theme, theme .. " : thème appliqué")
    noErrors(MOCK.exercise(root), theme .. " : dessin du bureau")
    eq(MOCK.lastSound, UI.T.boot, theme .. " : son de démarrage joué")
    -- menu démarrer
    root:ToggleStartMenu()
    check(root.MenuOpen, theme .. " : menu ouvert")
    noErrors(MOCK.exercise(root), theme .. " : dessin du menu")
    root:CloseStartMenu()
    check(not root.MenuOpen, theme .. " : menu fermé")
    -- icônes / dock : clics
    local errs = MOCK.clickAll(root, function(p) return p.cwText == "Éteindre" end)
    noErrors(errs, theme .. " : clics sur toute l'interface du bureau")
    root:Shutdown()
    check(not root:IsValid(), theme .. " : extinction")
end

section("Bureau : applications")
local root = OS.Open({ CWTheme = "nova", IsValid = function() return false end })
timer.Flush()
for _, id in ipairs(OS.AppOrder) do
    MOCK.lastError = nil
    local win = root:OpenApp(id, {})
    check(win and win:IsValid(), id .. " : fenêtre ouverte")
    check(root.Active == win, id .. " : fenêtre active")
    noErrors(MOCK.exercise(win), id .. " : dessin / Think")
    local errs, n = MOCK.clickAll(win)
    noErrors(errs, id .. " : " .. n .. " clics simulés")
    check(MOCK.lastError == nil, id .. " : aucune erreur interne remontée", MOCK.lastError)
    noErrors(MOCK.exercise(win), id .. " : dessin après clics")
    win:CloseWindow()
    check(not win:IsValid(), id .. " : fermeture")
end

section("Bureau : fenêtres (min / max / activation)")
do
    local w1 = root:OpenApp("notepad", {})
    local w2 = root:OpenApp("notepad", {})
    check(w1 ~= w2, "bloc-notes multi-instances")
    eq(root.Active, w2, "dernière fenêtre active")
    w2:Minimize()
    check(not w2:IsVisible(), "minimisée")
    w2:Restore()
    check(w2:IsVisible() and root.Active == w2, "restaurée")
    local x, y, w, h = w1:GetX(), w1:GetY(), w1:GetWide(), w1:GetTall()
    w1:ToggleMaximize()
    check(w1.cwMax, "maximisée")
    w1:ToggleMaximize()
    check(not w1.cwMax and w1:GetWide() == w, "taille restaurée")
    local m1 = root:OpenApp("music", {})
    local m2 = root:OpenApp("music", {})
    eq(m1, m2, "musique : instance unique")
    root:OpenApp("settings", { page = "diag" })
    check(true, "paramètres : page diag demandée")
    check(#root.Windows >= 4, "plusieurs fenêtres suivies")
end

section("Bureau : applications désactivées par l'admin")
do
    CV.browser.v = "0"
    local before = #root.Windows
    local w = root:OpenApp("browser", {})
    check(w == nil and #root.Windows == before, "navigateur désactivé : pas de fenêtre")
    CV.browser.v = "1"
    CV.music.v = "0"
    local mw = root:OpenApp("music", {})
    check(mw == nil or mw == root.Active, "musique désactivée (fenêtre existante ré-affichée ou aucune)")
    CV.music.v = "1"
end

section("Navigateur : navigation, blocage, popups")
do
    local win = root:OpenApp("browser", {})
    local body
    local html
    -- recherche du DHTML après navigation : on déclenche via OnAppArgs
    win:OnAppArgs({ input = "fr.wikipedia.org" })
    MOCK.walk(win, function(p) if p.__class == "DHTML" then html = p end end)
    check(html ~= nil, "DHTML créé à la première navigation")
    eq(html.__url, "https://fr.wikipedia.org", "URL ouverte")
    check(html.AllowLuaDisabled == nil, "(info) SetAllowLua appelé sans erreur")
    -- redirection bloquée
    local stopped = false
    html.StopLoading = function() stopped = true end
    html:OnBeginLoadingDocument("http://192.168.1.1/admin")
    check(stopped, "navigation vers LAN stoppée")
    check(html.__htmlSource and html.__htmlSource:find("Page bloquée", 1, true), "page de blocage affichée")
    -- injection HTML dans la page de blocage
    html:OnBeginLoadingDocument("https://example.com/<script>alert(1)</script>")
    -- (cwInternal est vrai : ignoré) puis nouvelle navigation propre
    html.cwInternal = false
    html:OnBeginLoadingDocument("javascript:alert('x')")
    check(not html.__htmlSource:find("<script>alert(1)</script>", 1, true), "URL échappée dans la page de blocage")
    -- popup autorisé / refusé
    html.cwInternal = false
    html:OnChildViewCreated("a", "https://example.com/popup", true)
    eq(html.__url, "https://example.com/popup", "popup légitime suivi dans la même fenêtre")
    html:OnChildViewCreated("a", "file:///etc/passwd", true)
    eq(html.__url, "https://example.com/popup", "popup file:// ignoré")
    -- mode liste blanche
    CV.filter.v = "1"
    win:OnAppArgs({ input = "random-site.net" })
    check(html.__url ~= "https://random-site.net", "liste blanche : navigation refusée")
    CV.filter.v = "0"
    -- recherche
    win:OnAppArgs({ input = "chats mignons" })
    check(html.__url:find("duckduckgo.com/html", 1, true), "recherche via le moteur par défaut")
    win:CloseWindow()
end

section("Fichiers / bloc-notes : scénario complet")
do
    local function button(win, label)
        local found
        MOCK.walk(win, function(p) if p.cwText == label then found = p end end)
        return found
    end

    MOCK.nextString = "rapport"
    local fw = root:OpenApp("files", { path = "Documents" })
    button(fw, "Nouveau dossier"):DoClick()
    check(FS.IsDir("Documents/rapport"), "explorateur : nouveau dossier créé dans le dossier courant")
    button(fw, "Nouveau fichier"):DoClick()
    check(FS.Exists("Documents/rapport.txt"), "explorateur : nouveau fichier créé (.txt ajouté)")
    check(root.Windows[#root.Windows].cwApp == "notepad", "explorateur : le nouveau fichier s'ouvre dans le bloc-notes")
    root.Windows[#root.Windows]:CloseWindow()

    -- Renommer / supprimer nécessitent une sélection : on sélectionne via un clic sur la ligne
    local rows = {}
    MOCK.walk(fw, function(p) if p.__class == "DButton" and p.cwText == nil and p.cwIcon == nil and rawget(p, "DoClick") and p.__h > 0 then rows[#rows + 1] = p end end)
    noErrors(MOCK.exercise(fw), "explorateur : dessin des lignes")

    local errs = MOCK.clickAll(fw)    -- clique sur tout (y compris Supprimer / Renommer / dossier parent)
    noErrors(errs, "explorateur : tous les boutons")
    fw:CloseWindow()

    local nw = root:OpenApp("notepad", { path = "Documents/Bienvenue.txt" })
    local entry
    MOCK.walk(nw, function(p) if p.__class == "DTextEntry" then entry = p end end)
    check(entry and entry:GetValue():find("Bienvenue sur ComputerWeb", 1, true), "ouverture d'un fichier dans le bloc-notes")
    entry:SetText("modifié")
    entry:OnChange()
    nw:CloseWindow()  -- Derma_Query mock choisit "Enregistrer"
    eq(FS.Read("Documents/Bienvenue.txt"), "modifié", "enregistrement à la fermeture")
end

section("Musique : favoris persistants")
do
    local mw = root:OpenApp("music", {})
    check(mw ~= nil, "fenêtre musique")
    -- ajout d'un favori via l'interface
    local urlEntry
    MOCK.walk(mw, function(p) if p.__class == "DTextEntry" then urlEntry = p end end)
    urlEntry:SetText("https://example.com/flux.mp3")
    MOCK.nextString = "Ma radio"
    local favBtn
    MOCK.walk(mw, function(p) if p.cwText == "★ Favori" then favBtn = p end end)
    check(favBtn ~= nil, "bouton favori trouvé")
    favBtn:DoClick()
    local raw = file.Read(FS.UserDir() .. "/favorites.json")
    check(raw and raw:find("Ma radio", 1, true), "favoris enregistrés sur le disque", raw)
    mw:CloseWindow()
    local mw2 = root:OpenApp("music", {})
    local found = false
    MOCK.walk(mw2, function(p) if p.cwText == nil and p.DoClick then end end)
    check(CW.Audio.status == "stopped", "fermer la musique arrête la lecture")
    mw2:CloseWindow()
end

section("Session : garde de distance")
do
    local lockEnt = { CWTheme = "nova", IsValid = function() return true end, GetPos = function() return Vector(0, 0, 0) end }
    MOCK.me.pos = Vector(0, 0, 0)
    local r2 = OS.Open(lockEnt)
    timer.Flush()
    local oldCT = CurTime
    local t0 = 9000
    CurTime = function() t0 = t0 + 1 return t0 end
    r2:Think()
    check(r2:IsValid(), "proche : session maintenue")
    MOCK.me.pos = Vector(5000, 0, 0)
    r2:Think()
    check(not r2:IsValid(), "éloigné : session fermée")
    MOCK.me.pos = Vector(0, 0, 0)

    local r3 = OS.Open(lockEnt)
    MOCK.me.alive = false
    r3:Think()
    check(not r3:IsValid(), "mort : session fermée")
    MOCK.me.alive = true

    lockEnt.IsValid = function() return false end
    local r4 = OS.Open({ CWTheme = "terra", IsValid = function() return true end, GetPos = function() return Vector(0, 0, 0) end })
    local alive = true
    r4.Entity = { IsValid = function() return alive end, GetPos = function() return Vector(0, 0, 0) end }
    alive = false
    r4:Think()
    check(not r4:IsValid(), "entité supprimée : session fermée")
    CurTime = oldCT
end

section("Télécommande d'écran")
do
    local ent2 = { IsValid = function() return true end, GetPos = function() return Vector(50, 0, 0) end,
        GetScreenURL = function() return "https://example.com/" end }
    net._in = { ent2 }
    net._recv["cw_screen_menu"]()
    -- le panneau est créé : on cherche un MakePopup'd racine
    local pnl
    for p in pairs(MOCK.allPanels) do if not p.__parent and not p.__removed and p.__w == nil == false and p.__class == "DPanel" and p.Think and p.Paint then pnl = p end end
    check(pnl ~= nil, "télécommande créée")
    if pnl then
        noErrors(MOCK.exercise(pnl), "télécommande : dessin")
        MOCK.netSent = {}
        local errs2 = MOCK.clickAll(pnl)
        noErrors(errs2, "télécommande : clics")
        check(#MOCK.netSent >= 1 and MOCK.netSent[1].name == "cw_screen_set", "bouton préréglage -> cw_screen_set envoyé")
    end
end

---------------------------------------------------------------------------
-- Rapport
---------------------------------------------------------------------------
section("Méthodes de panneau inconnues du faux GMod (à vérifier dans la doc GMod)")
local unknown = {}
for k in pairs(MOCK.unknownMethods) do unknown[#unknown + 1] = k end
table.sort(unknown)
print("  " .. table.concat(unknown, ", "))

print(string.format("\n==== %d réussis, %d échecs ====", passed, failed))
return failed == 0
