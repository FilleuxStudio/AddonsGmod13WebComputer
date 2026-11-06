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
eq(CW.Version, "2.2.0", "version")

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
include("computerweb/cl_shortcuts.lua")
include("computerweb/cl_os.lua")
for _, f in ipairs({ "files", "notepad", "browser", "music", "editor", "calc", "mines", "paint", "netlab", "matrix", "terminal", "settings" }) do
    include("computerweb/apps/cl_" .. f .. ".lua")
end
include("computerweb/cl_screen_remote.lua")
include("computerweb/cl_radio_remote.lua")
local FS, UI, OS = CW.FS, CW.UI, CW.OS
check(FS and UI and OS, "modules client chargés")
check(#OS.AppOrder == 12, "12 applications enregistrées", #OS.AppOrder)

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
section("Serveur : radio et intrusion simulée")
do
    local function mkRadio()
        local r = { CWKind = "radio", on = false, station = 0, IsValid = function() return true end,
            GetPos = function() return Vector(40, 0, 0) end }
        function r:SetOn(v) self.on = v end
        function r:SetStation(v) self.station = v end
        return r
    end
    local radio = mkRadio()
    local pl = MOCK.NewPlayer({ idx = 31, pos = Vector(0, 0, 0) })
    local function setRadio(plyObj, r, station, on)
        tick()
        net._in = { r, station, on }
        net._recv["cw_radio_set"](0, plyObj)
    end
    check(net._recv["cw_radio_set"] and net._recv["cw_hack_done"], "récepteurs radio / hack enregistrés")
    setRadio(pl, radio, 2, true)
    eq(radio.station, 2, "station choisie"); eq(radio.on, true, "radio allumée")
    setRadio(pl, radio, 3, false)
    eq(radio.station, 3, "station mémorisée à l'arrêt"); eq(radio.on, false, "radio éteinte")
    setRadio(pl, radio, 0, true);  eq(radio.station, 3, "station 0 refusée")
    setRadio(pl, radio, 99, true); eq(radio.station, 3, "station hors liste refusée")
    setRadio(MOCK.NewPlayer({ idx = 32, pos = Vector(5000, 0, 0) }), radio, 1, true); eq(radio.station, 3, "joueur trop loin refusé")
    setRadio(pl, { CWKind = "pc", IsValid = function() return true end, GetPos = function() return Vector(0, 0, 0) end }, 1, true)
    check(true, "entité qui n'est pas une radio ignorée")
    -- anti-spam
    tick()
    net._in = { radio, 1, true }; net._recv["cw_radio_set"](0, pl)
    net._in = { radio, 4, true }; net._recv["cw_radio_set"](0, pl)
    eq(radio.station, 1, "anti-spam radio : 2e changement immédiat ignoré")
    -- menu
    MOCK.netSent = {}
    tick(); CW.OpenRadioMenu(pl, radio)
    eq(MOCK.netSent[1] and MOCK.netSent[1].name, "cw_radio_menu", "menu radio envoyé")
    -- hook RP
    local fired
    hook.Add("ComputerWeb_HackSimulated", "t", function(ply2, ent2) fired = { ply2, ent2 } end)
    tick(); net._in = { radio }; net._recv["cw_hack_done"](0, pl)
    check(fired and fired[1] == pl and fired[2] == radio, "hook ComputerWeb_HackSimulated déclenché")
    fired = nil
    net._in = { radio }; net._recv["cw_hack_done"](0, pl)
    check(fired == nil, "hack : anti-spam")
    tick(); net._in = { { IsValid = function() return true end, GetPos = function() return Vector(0, 0, 0) end } }
    net._recv["cw_hack_done"](0, pl)
    check(fired == nil, "hack : objet qui n'est pas un appareil ComputerWeb ignoré")
    tick(); net._in = { radio }; net._recv["cw_hack_done"](0, MOCK.NewPlayer({ idx = 33, pos = Vector(9000, 0, 0) }))
    check(fired == nil, "hack : joueur hors de portée ignoré")
    hook.Remove("ComputerWeb_HackSimulated", "t")
end

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

local computers = { computerWindows = "nova", computerUbuntu = "terra", computerKali = "cipher", computerGarrysMod = "sandbox", computerRetro = "retro" }
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
local root
local function desktopFor(theme)
    if root and root:IsValid() and root.Theme.id == theme then return root end
    root = OS.Open({ CWTheme = theme, IsValid = function() return false end })
    timer.Flush()
    return root
end
for _, id in ipairs(OS.AppOrder) do
    MOCK.lastError = nil
    local def = OS.Apps[id]
    local useRoot = desktopFor(def.themes and def.themes[1] or "nova")
    local win = useRoot:OpenApp(id, {})
    check(win and win:IsValid(), id .. " : fenêtre ouverte")
    check(useRoot.Active == win, id .. " : fenêtre active")
    noErrors(MOCK.exercise(win), id .. " : dessin / Think")
    local errs, n = MOCK.clickAll(win)
    noErrors(errs, id .. " : " .. n .. " clics simulés")
    check(MOCK.lastError == nil, id .. " : aucune erreur interne remontée", MOCK.lastError)
    noErrors(MOCK.exercise(win), id .. " : dessin après clics")
    win:CloseWindow()
    check(not win:IsValid(), id .. " : fermeture")
end

section("Bureau : applications réservées à un thème")
do
    local nova = desktopFor("nova")
    local before = #nova.Windows
    check(nova:OpenApp("netlab", {}) == nil and #nova.Windows == before, "Réseau refusé sur Nova")
    check(nova:OpenApp("matrix", {}) == nil, "Matrix refusé sur Nova")
    local vis = OS.VisibleApps("nova")
    local visC = OS.VisibleApps("cipher")
    local function has(list, id) for _, v in ipairs(list) do if v == id then return true end end end
    check(not has(vis, "netlab") and has(visC, "netlab"), "netlab visible seulement sous Cipher")
    check(has(vis, "editor") and has(visC, "editor"), "apps communes visibles partout")
    check(not OS.AppAllowed(nil, "nova"), "app inconnue non autorisée")
end
root = desktopFor("nova")

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
-- Micro-applications (logique pure)
---------------------------------------------------------------------------
section("Terminal : nouvelles commandes")
do
    local r = OS.Open({ CWTheme = "retro", IsValid = function() return false end })
    timer.Flush()
    local out = {}
    local st = { desktop = r, cwd = "", started = SysTime(), out = function(txt, kind) out[#out + 1] = tostring(txt) end }
    local function run(line) out = {}; CW.Term.Run(st, line) return table.concat(out, "\n") end
    check(run("calc (3+4)*2"):find("= 14", 1, true), "terminal : calc")
    check(run("calc 1/0"):find("zéro"), "terminal : calc erreur")
    check(run("calc os.exit()"):find("calc:"), "terminal : calc refuse du code")
    run("start calc")
    local found
    for _, w in ipairs(r.Windows) do if w.cwApp == "calc" then found = true end end
    check(found, "terminal : start calc ouvre la calculatrice")
    check(run("start nimportequoi"):find("usage"), "terminal : start application inconnue")
    run("accent 10 20 30"); eq(UI.T.c.accent.g, 20, "terminal : accent appliqué")
    check(run("accent x"):find("usage"), "terminal : accent usage")
    run("accent reset"); eq(UI.T.c.accent.b, 128, "terminal : accent reset")
    run("echo salut > t.txt"); run("edit t.txt")
    local ed
    for _, w in ipairs(r.Windows) do if w.cwApp == "editor" then ed = w end end
    check(ed ~= nil, "terminal : edit ouvre l'éditeur")
    if ed then ed.cwDiscard = true; ed:CloseWindow() end
    r:Shutdown()
end

section("Calculatrice : évaluateur d'expressions")
do
    local E = CW.Calc.Eval
    local function ev(expr) local v, err = E(expr) return v, err end
    eq(ev("1+2*3"), 7, "priorité * sur +")
    eq(ev("(1+2)*3"), 9, "parenthèses")
    eq(ev("-2^2"), -4, "moins unaire sous la puissance : -(2^2)")
    eq(ev("2^3^2"), 512, "puissance associative à droite")
    eq(ev("2^-1"), 0.5, "exposant négatif")
    eq(ev("10/4"), 2.5, "division")
    eq(ev("10%3"), 1, "modulo")
    eq(ev("-7%3"), 2, "modulo positif")
    eq(ev("sqrt(16)+abs(-3)"), 7, "fonctions")
    eq(ev("round(2.5)"), 3, "round")
    check(math.abs(ev("pi") - math.pi) < 1e-12, "constante pi")
    check(math.abs(ev("sin(0)")) < 1e-12 and ev("cos(0)") == 1, "trigonométrie")
    eq(ev("  4 * ( 2 + 3 ) "), 20, "espaces ignorés")
    eq(ev("--3"), 3, "double moins")
    local v, err = ev("1/0"); check(v == nil and err:find("zéro"), "division par zéro refusée", err)
    v, err = ev("sqrt(-1)"); check(v == nil, "racine négative refusée")
    v, err = ev("ln(0)"); check(v == nil, "ln(0) refusé")
    v, err = ev("2+"); check(v == nil, "expression incomplète refusée", err)
    v, err = ev("(2+3"); check(v == nil, "parenthèse manquante refusée", err)
    v, err = ev("2 3"); check(v == nil, "deux nombres sans opérateur refusés", err)
    v, err = ev("os.exit()"); check(v == nil, "appel de fonction Lua refusé", err)
    v, err = ev("print(1)"); check(v == nil, "fonction inconnue refusée", err)
    v, err = ev("1;2"); check(v == nil, "caractère interdit refusé", err)
    v, err = ev("1,5"); check(v == nil, "virgule décimale refusée avec message", err)
    v, err = ev(string.rep("(", 40) .. "1" .. string.rep(")", 40)); check(v == nil, "imbrication excessive refusée", err)
    v, err = ev(string.rep("1+", 100) .. "1"); check(v == nil, "expression trop longue refusée", err)
    v, err = ev("9^9^9"); check(v == nil, "dépassement refusé", err)
    v, err = ev(""); check(v == nil, "vide refusé")
    eq(CW.Calc.Format(7), "7", "format entier")
    eq(CW.Calc.Format(2.5), "2.5", "format décimal")
    eq(CW.Calc.Format(1 / 3), "0.3333333333", "format 10 chiffres")
end

section("Éditeur : fonctions pures")
do
    local Ed = CW.Editor
    local t, n = Ed.ReplaceAll("a.b.a", "a", "XY"); eq(t, "XY.b.XY", "remplacer tout"); eq(n, 2, "nombre de remplacements")
    t, n = Ed.ReplaceAll("100%", "%", "%%"); eq(t, "100%%", "'%' traité comme du texte brut")
    t, n = Ed.ReplaceAll("abc", "", "x"); eq(n, 0, "recherche vide : rien")
    t, n = Ed.ReplaceAll("aaa", "aa", "b"); eq(t, "ba", "non chevauchant")
    eq(#Ed.FindAll("abcabc", "bc"), 2, "FindAll")
    eq(Ed.FindAll("abcabc", "bc")[2], 5, "FindAll position")
    local ln, col = Ed.LineCol("ab\ncde", 0); eq(ln, 1, "ligne début"); eq(col, 1, "col début")
    ln, col = Ed.LineCol("ab\ncde", 5); eq(ln, 2, "ligne 2"); eq(col, 3, "col 3")
    ln, col = Ed.LineCol("ab\ncde", 999); eq(ln, 2, "position hors limite bornée")
    eq(Ed.WordCount("un deux\n trois  "), 3, "mots")
    eq(Ed.LineOf("a\nb\nc", 5), 3, "LineOf")
end

section("Démineur : logique")
do
    local M = CW.Mines
    local g = M.New(9, 9, 10)
    local seq = 0
    local function rnd(a, b) seq = seq + 1 return a + (seq * 7) % (b - a + 1) end
    eq(M.Reveal(g, 5, 5, rnd), "ok", "premier clic sûr")
    check(not g.cells[(5 - 1) * 9 + 5].mine, "case de départ sans mine")
    local mines = 0
    for _, c in ipairs(g.cells) do if c.mine then mines = mines + 1 end end
    eq(mines, 10, "10 mines posées")
    for _, nb in ipairs(M.Neighbours(g, 5, 5)) do check(not g.cells[(nb[2] - 1) * 9 + nb[1]].mine, "voisine sûre") break end
    check(g.opened >= 1, "au moins une case ouverte")
    -- drapeau
    local fx, fy
    for y = 1, 9 do for x = 1, 9 do if not g.cells[(y - 1) * 9 + x].open and not fx then fx, fy = x, y end end end
    check(M.ToggleFlag(g, fx, fy), "pose drapeau"); eq(g.flags, 1, "compteur drapeaux")
    check(M.Reveal(g, fx, fy) == nil, "case marquée non révélable")
    check(M.ToggleFlag(g, fx, fy), "retire drapeau"); eq(g.flags, 0, "compteur remis à zéro")
    -- défaite
    local boom
    for i, c in ipairs(g.cells) do if c.mine then boom = i break end end
    local bx, by = (boom - 1) % 9 + 1, math.floor((boom - 1) / 9) + 1
    eq(M.Reveal(g, bx, by), "boom", "mine -> boom")
    check(g.over and not g.won, "partie perdue")
    check(M.Reveal(g, 1, 1) == nil, "plus de coup après la fin")
    -- victoire : on ouvre toutes les cases sans mine
    local g2 = M.New(9, 9, 10)
    seq = 3
    M.Reveal(g2, 1, 1, rnd)
    for y = 1, 9 do for x = 1, 9 do
        if not g2.cells[(y - 1) * 9 + x].mine then M.Reveal(g2, x, y) end
    end end
    check(g2.over and g2.won, "partie gagnée en ouvrant toutes les cases sûres")
    local g3 = M.New(3, 3, 99)
    eq(g3.mines, 0, "grille 3x3 : au plus w*h-9 mines")
end

section("Dessin : sérialisation")
do
    local P = CW.Paint
    local strokes = { { r = 255, g = 0, b = 10, size = 5, pts = { 0, 0, 500, 500, 1000, 1000 } }, { r = 1, g = 2, b = 3, size = 2, pts = { 10, 10 } } }
    local text = P.Serialize(strokes)
    local back = P.Parse(text)
    eq(#back, 2, "2 traits relus (un point seul est valide)"); eq(back[1].r, 255, "couleur"); eq(back[1].pts[5], 1000, "points")
    check(P.Parse("hello") == nil, "mauvais en-tête refusé")
    back = P.Parse(P.Header .. "\n999 -5 300 500 0 0 99999 -50")
    eq(back[1].r, 255, "couleur bornée"); eq(back[1].g, 0, "couleur bornée (négatif)")
    eq(back[1].size, 30, "épaisseur bornée"); eq(back[1].pts[3], 1000, "coordonnée bornée"); eq(back[1].pts[4], 0, "coordonnée négative bornée")
    local big = { P.Header }
    for i = 1, 400 do big[#big + 1] = "0 0 0 2 1 1 2 2" end
    eq(#P.Parse(table.concat(big, "\n")), P.MaxStrokes, "nombre de traits plafonné")
    check(P.Parse(P.Header .. "\n1 2 3 4 5") ~= nil and #P.Parse(P.Header .. "\n1 2 3 4 5") == 0, "ligne malformée ignorée")
end

section("Raccourcis : validation, enregistrement, ouverture")
do
    local SC = CW.Shortcuts
    SC.List = {}
    check(SC.Add({ type = "app", app = "notepad", label = "Mon bloc" }), "raccourci application")
    check(SC.Add({ type = "url", url = "fr.wikipedia.org", label = "Wiki" }), "raccourci URL (https ajouté)")
    eq(SC.List[2].url, "https://fr.wikipedia.org", "https ajouté automatiquement")
    local ok, err = SC.Add({ type = "url", url = "javascript:alert(1)" }); check(not ok, "javascript: refusé", err)
    ok, err = SC.Add({ type = "url", url = "http://192.168.1.1/" }); check(not ok, "LAN refusé", err)
    ok, err = SC.Add({ type = "url", url = "https://x.com/\nboo" }); check(not ok, "retour ligne refusé", err)
    ok, err = SC.Add({ type = "app", app = "../../x" }); check(not ok, "id d'application invalide refusé", err)
    ok, err = SC.Add({ type = "file", path = "" }); check(not ok, "fichier vide refusé", err)
    ok, err = SC.Add({ type = "file", path = "Documents/note.txt", label = "Note" }); check(ok, "raccourci fichier", err)
    ok, err = SC.Add({ type = "bidule" }); check(not ok, "type inconnu refusé", err)
    ok, err = SC.Add("pas une table"); check(not ok, "entrée non table refusée")
    eq(SC.List[1].icon, "notepad", "icône par défaut de l'application")
    eq(SC.List[2].icon, "browser", "icône par défaut d'un site")
    local e = SC.Sanitize({ type = "app", app = "calc", label = "  " .. string.rep("x", 60) .. "\t", icon = "evil" })
    check(#e.label <= 24 and not e.label:find("%c"), "nom borné et nettoyé"); check(SC.IconSet[e.icon], "icône inconnue remplacée")
    -- aller-retour disque
    local before = #SC.List
    SC.List = {}
    SC.Load()
    eq(#SC.List, before, "rechargement : même nombre de raccourcis")
    eq(SC.List[3].path, "Documents/note.txt", "rechargement : chemin conservé")
    -- fichier piégé
    local parsed = SC.Parse("app\tsettings\tnotepad\tOK\nurl\tbrowser\tjavascript:alert(1)\tMal\nbidule\tx\ty\tz\nligne cassée")
    eq(#parsed, 1, "Parse : seules les lignes valides sont gardées")
    -- limite
    SC.List = {}
    for i = 1, SC.Max do SC.Add({ type = "app", app = "calc" }) end
    ok, err = SC.Add({ type = "app", app = "calc" }); check(not ok, "plafond de raccourcis", err)
    check(SC.Remove(1) and #SC.List == SC.Max - 1, "suppression")
    check(not SC.Remove(999), "suppression hors limites")
    SC.List = {}
end

section("Accent : couleur choisie par le joueur")
do
    UI.SetTheme("nova")
    local base = UI.Base.c.accent
    check(UI.T.c.accent.r == base.r, "accent par défaut = thème")
    UI.SetAccent("200 10 30")
    eq(UI.T.c.accent.r, 200, "accent appliqué (rouge)")
    check(UI.T.c.title.r < UI.T.c.accent.r, "barre de titre assombrie")
    eq(UI.Themes.nova.c.accent.r, base.r, "le thème de base n'est pas modifié")
    UI.SetAccent("250 250 250")
    eq(UI.T.c.accentText.r, 20, "texte sombre sur accent clair")
    UI.SetAccent("999 -4 abc")
    eq(UI.T.c.accent.r, base.r, "valeur invalide ignorée")
    UI.SetAccent("300 0 0")
    eq(UI.T.c.accent.r, 255, "composante bornée à 255")
    UI.SetTheme("retro")
    UI.SetAccent("0 100 0")
    check(UI.T.c.title2 ~= nil and UI.T.c.title.g > 0, "retro : dégradé de titre teinté")
    UI.SetAccent("")
    eq(UI.T.c.accent.b, 128, "retour au thème Retro98")
    UI.SetTheme("nova")
end

section("Bureau : raccourcis sur le bureau et réglages")
do
    local SC = CW.Shortcuts
    SC.List = {}
    for _, theme in ipairs({ "nova", "terra", "retro" }) do
        local r = OS.Open({ CWTheme = theme, IsValid = function() return false end })
        timer.Flush()
        SC.List = {}
        SC.Add({ type = "app", app = "calc", label = "Calcul" })
        SC.Add({ type = "url", url = "https://fr.wikipedia.org", label = "Wikipédia" })
        SC.Add({ type = "file", path = "Documents/n.txt", label = "Note" })
        r:BuildDesktopIcons()
        local n = 0
        for _, p in ipairs(r.IconPanels) do if p:IsValid() then n = n + 1 end end
        check(n >= 3, theme .. " : icônes de raccourcis créées (" .. n .. ")")
        MOCK.lastError = nil
        noErrors(MOCK.exercise(r), theme .. " : dessin avec raccourcis")
        -- ouverture d'un raccourci appli
        local w = SC.Open(r, SC.List[1])
        check(w and w:IsValid() and w.cwApp == "calc", theme .. " : raccourci -> calculatrice")
        w:CloseWindow()
        -- ouverture URL -> navigateur
        local bw = SC.Open(r, SC.List[2])
        check(bw and bw.cwApp == "browser", theme .. " : raccourci URL -> navigateur")
        bw:CloseWindow()
        -- fichier absent : pas de crash
        SC.Open(r, SC.List[3])
        check(true, theme .. " : fichier absent géré")
        -- fichier présent -> éditeur
        FS.Write("Documents/n.txt", "bonjour")
        local ew = SC.Open(r, SC.List[3])
        check(ew and ew.cwApp == "editor", theme .. " : raccourci fichier -> éditeur")
        ew.cwDiscard = true
        ew:CloseWindow()
        -- boîte de dialogue + pages de réglages
        local d = SC.OpenDialog(r)
        check(d and d:IsValid(), theme .. " : dialogue de raccourci")
        noErrors(MOCK.exercise(d), theme .. " : dessin du dialogue")
        local errs = MOCK.clickAll(d, function(pn) return pn.cwText == "Annuler" end)
        noErrors(errs, theme .. " : clics dans le dialogue")
        if d:IsValid() then d:CloseWindow() end
        for _, page in ipairs({ "color", "desk", "look" }) do
            local sw = r:OpenApp("settings", { page = page })
            noErrors(MOCK.exercise(sw), theme .. " : réglages/" .. page)
            noErrors(MOCK.clickAll(sw), theme .. " : réglages/" .. page .. " clics")
        end
        UI.SetAccent("")
        r:Shutdown()
    end
    SC.List = {}
end

section("Micro-applications : interactions")
do
    local r = OS.Open({ CWTheme = "retro", IsValid = function() return false end })
    timer.Flush()
    -- éditeur : enregistrement via l'API de fichiers
    local ew = r:OpenApp("editor", {})
    check(ew and ew:IsValid(), "éditeur ouvert")
    FS.Write("Documents/e.txt", "alpha beta")
    ew:OnAppArgs({ path = "Documents/e.txt" })
    check(true, "éditeur : ouverture d'un fichier")
    ew.cwDiscard = true; ew:CloseWindow()
    -- dessin : ouverture d'un fichier valide / invalide
    FS.Write("Documents/d.txt", CW.Paint.Serialize({ { r = 1, g = 2, b = 3, size = 5, pts = { 0, 0, 100, 100 } } }))
    local pw = r:OpenApp("paint", { path = "Documents/d.txt" })
    noErrors(MOCK.exercise(pw), "dessin : fichier relu et dessiné")
    pw:CloseWindow()
    FS.Write("Documents/x.txt", "pas un dessin")
    pw = r:OpenApp("paint", { path = "Documents/x.txt" })
    noErrors(MOCK.exercise(pw), "dessin : fichier invalide ignoré")
    pw:CloseWindow()
    -- démineur : dessin sur chaque niveau
    local mw = r:OpenApp("mines", {})
    noErrors(MOCK.exercise(mw), "démineur : dessin")
    MOCK.clickAll(mw)
    noErrors(MOCK.exercise(mw), "démineur : dessin après clics (niveaux)")
    mw:CloseWindow()
    r:Shutdown()
end

section("Outil Réseau (Cipher) : appareils, ping, intrusion simulée")
do
    local Net = CW.Net
    MOCK.me.pos = Vector(0, 0, 0)
    local function dev(kind, idx, x, theme)
        return { CWKind = kind, CWTheme = theme, IsValid = function() return true end,
            EntIndex = function() return idx end, GetPos = function() return Vector(x, 0, 0) end }
    end
    local pc, scr, rad, far = dev("pc", 41, 300, "cipher"), dev("screen", 42, 100), dev("radio", 43, 900), dev("pc", 44, 9000, "nova")
    MOCK.ents = { pc, scr, rad, far, { IsValid = function() return true end, EntIndex = function() return 45 end, GetPos = function() return Vector(1, 0, 0) end } }
    local list = Net.Targets()
    eq(#list, 3, "3 appareils à portée (le lointain et l'objet quelconque exclus)")
    eq(list[1].ent, scr, "tri par distance"); eq(list[3].ent, rad, "plus loin en dernier")
    check(list[1].ip:match("^192%.168%.%d+%.%d+$"), "IP fictive bien formée", list[1].ip)
    eq(Net.IP(pc), Net.IP(pc), "IP stable")
    eq(Net.Host(pc), "cipher-41", "nom d'hôte"); eq(Net.Host(scr), "screen-42", "nom d'hôte sans thème")
    eq(Net.Resolve(Net.IP(pc), list).ent, pc, "résolution par IP")
    eq(Net.Resolve("CIPHER-41", list).ent, pc, "résolution par nom (insensible à la casse)")
    eq(Net.Resolve("#42", list).ent, scr, "résolution par numéro")
    check(Net.Resolve("n-importe-quoi", list) == nil and Net.Resolve("", list) == nil, "résolution inconnue")
    local pl = Net.PingLines(list[1], 4)
    eq(#pl, 6, "ping : 1 entête + 4 paquets + 1 bilan")
    check(pl[2][1]:find("temps=", 1, true), "ping : latence affichée")
    check(Net.Latency(0) < Net.Latency(5000), "latence croissante avec la distance")
    local script = Net.HackScript(list[2])
    check(#script > 8, "script d'intrusion non vide")
    check(script[#script][1] and script[#script][2]:find("jeu", 1, true), "le script rappelle que c'est un jeu")
    local joined = {}
    for _, l in ipairs(script) do joined[#joined + 1] = l[2] end
    check(table.concat(joined, "\n"):find("simulation", 1, true), "le script se déclare simulation")
    -- exécution
    local out, finished = {}, false
    Net.RunScript({ { 0, "a" }, { 0, "b", "ok" } }, function(t, k) out[#out + 1] = t end, nil, function() finished = true end)
    for _ = 1, 10 do timer.Flush() end
    eq(table.concat(out, ","), "a,b", "RunScript : ordre des lignes"); check(finished, "RunScript : callback de fin")
    out, finished = {}, false
    local alive = true
    Net.RunScript({ { 0, "a" }, { 0, "b" } }, function(t) out[#out + 1] = t; alive = false end, function() return alive end, function() finished = true end)
    for _ = 1, 10 do timer.Flush() end
    eq(#out, 1, "RunScript : s'arrête si la fenêtre est fermée"); check(not finished, "RunScript : pas de fin après fermeture")
    -- notification serveur
    MOCK.netSent = {}
    Net.Notify(list[1])
    eq(MOCK.netSent[1] and MOCK.netSent[1].name, "cw_hack_done", "Notify : message envoyé au serveur")
    -- application complète sous Cipher
    local r = OS.Open({ CWTheme = "cipher", IsValid = function() return false end })
    timer.Flush()
    local w = r:OpenApp("netlab", {})
    for _ = 1, 40 do timer.Flush() end
    noErrors(MOCK.exercise(w), "Réseau : dessin après scan")
    MOCK.netSent = {}
    noErrors(MOCK.clickAll(w), "Réseau : clics (scan, ping, ports, intrusion)")
    for _ = 1, 80 do timer.Flush() end
    noErrors(MOCK.exercise(w), "Réseau : dessin après actions")
    w:CloseWindow()
    -- terminal
    local tw = r:OpenApp("terminal", {})
    local out2 = {}
    local st = { desktop = r, cwd = "", started = SysTime(), out = function(txt) out2[#out2 + 1] = tostring(txt) end }
    local function run(line) out2 = {}; CW.Term.Run(st, line) return table.concat(out2, "\n") end
    check(run("scan"):find("screen%-42"), "terminal : scan liste les appareils")
    check(run("ping screen-42"):find("temps=", 1, true), "terminal : ping d'un appareil de la scène")
    check(run("ping exemple.fr"):find("simulation", 1, true), "terminal : ping générique conservé")
    check(run("ports cipher-41"):find("22/tcp", 1, true), "terminal : ports")
    check(run("ports inconnu"):find("usage"), "terminal : ports usage")
    run("hack screen-42")
    check(st.hacking, "terminal : intrusion en cours")
    check(run("hack screen-42"):find("déjà en cours"), "terminal : une seule intrusion à la fois")
    for _ = 1, 80 do timer.Flush() end
    check(not st.hacking, "terminal : intrusion terminée")
    check(run("hack inconnu"):find("usage"), "terminal : hack usage")
    tw:CloseWindow()
    r:Shutdown()
    local rn = OS.Open({ CWTheme = "nova", IsValid = function() return false end })
    timer.Flush()
    st.desktop = rn
    check(run("hack screen-42"):find("réservée"), "terminal : hack réservé à Cipher")
    rn:Shutdown()
    MOCK.ents = {}
end

section("Matrix : caractères d'ambiance")
do
    local Mx = CW.Matrix
    eq(Mx.CharAt(3, 7, 2), Mx.CharAt(3, 7, 2), "caractère stable")
    check(#Mx.CharAt(1, 1, 1) == 1 and Mx.Chars:find(Mx.CharAt(5, 9, 4), 1, true), "caractère valide")
end

section("Radio 3D : entité, audio, télécommande")
do
    CW.CVars.radiovol = CW.CVars.radiovol or CreateClientConVar("cw_radio_volume", "0.8")
    local e = loadEnt("cw_radio", "client")
    eq(e.CWKind, "radio", "type d'appareil"); check(e.Spawnable, "spawnable")
    eq(e.IconOverride, "entities/cw_radio.png", "icône du menu de spawn")
    check(e.CWModel:find("%.mdl$"), "modèle du jeu de base")
    local inst = setmetatable({ _on = true, _st = 1, _pos = Vector(100, 0, 0) }, { __index = e })
    function inst:GetOn() return self._on end
    function inst:GetStation() return self._st end
    function inst:GetPos() return self._pos end
    function inst:IsValid() return not self.dead end
    function inst:DrawModel() self.drawn = true end
    MOCK.me.pos = Vector(0, 0, 0)
    inst:Initialize()
    MOCK.streams = 0
    inst.NextCheck = 0; inst:Think()
    eq(MOCK.streams, 1, "flux lancé quand la radio est allumée et proche")
    eq(MOCK.lastStream, CW.Config.Radios[1].url, "URL de la station 1")
    check(MOCK.lastStreamFlags:find("3d", 1, true) and MOCK.lastStreamFlags:find("mono", 1, true), "audio 3D mono")
    check(IsValid(inst.Channel) and inst.Channel.fade and inst.Channel.fade[2] > inst.Channel.fade[1], "distances de fondu définies")
    eq(inst.Channel.pos, inst._pos, "canal placé sur la radio")
    inst._pos = Vector(120, 0, 0); inst.NextCheck = 0; inst:Think()
    eq(inst.Channel.pos.x, 120, "canal suit la radio")
    inst.NextCheck = 0; inst:Think()
    eq(MOCK.streams, 1, "pas de relance inutile")
    -- volume local
    CW.CVars.radiovol.v = "0.25"; inst.NextCheck = 0; inst:Think()
    eq(inst.Channel.vol, 0.25, "volume local appliqué")
    -- changement de station
    inst._st = 2; inst.NextCheck = 0; inst:Think()
    eq(MOCK.streams, 2, "nouvelle station -> nouveau flux"); eq(MOCK.lastStream, CW.Config.Radios[2].url, "URL de la station 2")
    local old = inst.Channel
    inst._st = 3; inst.NextCheck = 0; inst:Think()
    check(old.dead, "ancien canal arrêté")
    -- station hors liste : coupe
    inst._st = 99; inst.NextCheck = 0; inst:Think()
    check(inst.Channel == nil, "station invalide : audio coupé")
    inst._st = 1; inst.NextCheck = 0; inst:Think()
    -- éteinte
    inst._on = false; inst.NextCheck = 0; inst:Think()
    check(inst.Channel == nil, "radio éteinte : audio coupé")
    inst._on = true; inst.NextCheck = 0; inst:Think()
    check(IsValid(inst.Channel), "rallumée : audio relancé")
    -- loin
    MOCK.me.pos = Vector(8000, 0, 0); inst.NextCheck = 0; inst:Think()
    check(inst.Channel == nil, "trop loin : audio coupé")
    MOCK.me.pos = Vector(0, 0, 0)
    -- échec de chargement : pas de boucle de relance
    MOCK.streamFails = true
    MOCK.streams = 0
    inst.NextCheck = 0; inst:Think()
    MOCK.streamFails = false
    eq(MOCK.streams, 1, "échec : une seule tentative")
    local t0 = CurTime()
    inst:Think()
    eq(MOCK.streams, 1, "échec : pas de relance immédiate")
    -- callback tardif d'une entité supprimée
    inst.NextCheck = 0; inst.LoadedStation = nil
    local pending
    local realPlay = sound.PlayURL
    sound.PlayURL = function(url, flags, cb) pending = cb end
    inst.NextCheck = 0; inst:Think()
    inst:OnRemove(); inst.dead = true
    local stray = { IsValid = function() return true end, Stop = function(self) self.stopped = true end }
    pending(stray, 0, "")
    check(stray.stopped, "callback tardif : canal arrêté, pas de fuite")
    sound.PlayURL = realPlay
    -- HUD
    inst.dead = false; inst:Initialize(); inst._on = true
    local ok = pcall(function() hook.Run("HUDPaint") end)
    check(ok, "HUD : pas d'erreur")
    -- télécommande
    local ent3 = { IsValid = function() return true end, GetPos = function() return Vector(50, 0, 0) end,
        GetOn = function() return true end, GetStation = function() return 1 end }
    net._in = { ent3 }
    net._recv["cw_radio_menu"]()
    local pnl
    for p in pairs(MOCK.allPanels) do if not p.__parent and not p.__removed and p.__class == "DPanel" and p.Think and p.Paint and p.__w == nil == false then pnl = p end end
    check(pnl ~= nil, "télécommande radio créée")
    if pnl then
        noErrors(MOCK.exercise(pnl), "télécommande radio : dessin")
        MOCK.netSent = {}
        noErrors(MOCK.clickAll(pnl), "télécommande radio : clics")
        local sentSet
        for _, m in ipairs(MOCK.netSent) do if m.name == "cw_radio_set" then sentSet = m end end
        check(sentSet ~= nil, "bouton station / marche-arrêt -> cw_radio_set")
        check(sentSet and sentSet.data[2] >= 1 and type(sentSet.data[3]) == "boolean", "paramètres du message valides")
    end
    inst:OnRemove()
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
