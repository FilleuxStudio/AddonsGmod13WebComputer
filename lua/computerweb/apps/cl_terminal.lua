--[[----------------------------------------------------------------------------
    ComputerWeb - Application "Terminal"
    Un petit shell qui travaille sur le disque virtuel du joueur.
    L'interpréteur (CW.Term) est séparé de l'interface pour rester testable.
------------------------------------------------------------------------------]]

local CW = ComputerWeb
local UI = CW.UI
local S = UI.S
local FS = CW.FS
local OS = CW.OS

CW.Term = CW.Term or {}
local Term = CW.Term

---------------------------------------------------------------------------
-- Interpréteur
---------------------------------------------------------------------------

--- Découpe une ligne en arguments ("a b" gardé ensemble).
function Term.Split(line)
    local args, i, n = {}, 1, #line
    while i <= n do
        local ch = line:sub(i, i)
        if ch:match("%s") then
            i = i + 1
        elseif ch == '"' then
            local j = line:find('"', i + 1, true)
            if not j then j = n + 1 end
            args[#args + 1] = line:sub(i + 1, j - 1)
            i = j + 1
        else
            local j = line:find("%s", i) or (n + 1)
            args[#args + 1] = line:sub(i, j - 1)
            i = j
        end
    end
    return args
end

local function resolve(state, arg)
    if not arg or arg == "" then return state.cwd end
    arg = arg:gsub("\\", "/")
    if arg == "~" then return "" end
    if arg:sub(1, 1) == "/" then return FS.Clean(arg) end
    return FS.Clean(FS.Join(state.cwd, arg))
end

local function promptPath(cwd)
    return "~" .. (cwd ~= "" and ("/" .. cwd) or "")
end
Term.PromptPath = promptPath

--- state = { cwd = "", out = function(text, kind), desktop = <opt>, started = <opt time> }
--  kind : nil | "dim" | "err" | "ok" | "accent"
local commands = {}
Term.Commands = commands

commands.help = function(st)
    local lines = {
        "Commandes disponibles :",
        "  ls [dossier]        liste le contenu          cd <dossier>   changer de dossier",
        "  pwd                 dossier courant            cat <fichier>  afficher un fichier",
        "  mkdir <nom>         créer un dossier           touch <nom>    créer un fichier vide",
        "  rm <chemin>         supprimer                  mv <a> <b>     renommer / déplacer",
        "  echo <texte> [> f]  écrire (>> pour ajouter)   clear          vider l'écran",
        "  open <fichier>      ouvrir dans le Bloc-notes  browse <...>   ouvrir le navigateur",
        "  play [station]      lancer la musique          stop           arrêter la musique",
        "  wallpaper <nom>     changer le fond d'écran    theme          infos système",
        "  date  whoami  hostname  uname  uptime  neofetch  ping <hôte>  exit",
    }
    for _, l in ipairs(lines) do st.out(l, l:sub(1, 1) ~= " " and "accent" or nil) end
end

commands.pwd = function(st) st.out("/" .. st.cwd) end

commands.clear = function(st) if st.clear then st.clear() end end
commands.cls = commands.clear

commands.ls = function(st, args)
    local target = resolve(st, args[1])
    if not target then st.out("ls: chemin invalide", "err") return end
    local res, err = FS.List(target)
    if not res then st.out("ls: " .. (err or "erreur"), "err") return end
    if #res.dirs == 0 and #res.files == 0 then st.out("(vide)", "dim") return end
    for _, d in ipairs(res.dirs) do st.out(string.format("  %-34s <dossier>", d .. "/"), "accent") end
    for _, f in ipairs(res.files) do st.out(string.format("  %-34s %s", f.name, FS.FormatSize(f.size))) end
end
commands.dir = commands.ls

commands.cd = function(st, args)
    local target = resolve(st, args[1] or "~")
    if not target then st.out("cd: chemin invalide", "err") return end
    if target ~= "" and not FS.IsDir(target) then st.out("cd: dossier introuvable", "err") return end
    st.cwd = target
end

commands.cat = function(st, args)
    if not args[1] then st.out("usage: cat <fichier>", "err") return end
    local target = resolve(st, args[1])
    if not target then st.out("cat: chemin invalide", "err") return end
    local text, err = FS.Read(target)
    if not text then st.out("cat: " .. (err or "erreur"), "err") return end
    if text == "" then st.out("(fichier vide)", "dim") return end
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do st.out(line) end
end
commands.type = commands.cat

commands.mkdir = function(st, args)
    if not args[1] then st.out("usage: mkdir <nom>", "err") return end
    local target = resolve(st, args[1])
    if not target then st.out("mkdir: chemin invalide", "err") return end
    local ok, err = FS.MkDir(target)
    if not ok then st.out("mkdir: " .. (err or "erreur"), "err") end
end

--- Chemin cible d'un fichier texte (extension .txt garantie) ou nil.
local function fileTarget(st, arg)
    local full = resolve(st, arg)
    if not full or full == "" then return nil end
    local base = FS.FileName(FS.Basename(full))
    if not base then return nil end
    return FS.Join(FS.Parent(full), base)
end

commands.touch = function(st, args)
    if not args[1] then st.out("usage: touch <nom>", "err") return end
    local target = fileTarget(st, args[1])
    if not target then st.out("touch: nom invalide", "err") return end
    if FS.Exists(target) then return end
    local ok, err = FS.Write(target, "")
    if not ok then st.out("touch: " .. (err or "erreur"), "err") end
end

commands.rm = function(st, args)
    if not args[1] then st.out("usage: rm <chemin>", "err") return end
    local target = resolve(st, args[1])
    if not target or target == "" then st.out("rm: chemin invalide", "err") return end
    local ok, err = FS.Delete(target)
    if not ok then st.out("rm: " .. (err or "erreur"), "err") end
end

commands.mv = function(st, args)
    if not args[2] then st.out("usage: mv <source> <destination>", "err") return end
    local a, b = resolve(st, args[1]), resolve(st, args[2])
    if not a or not b then st.out("mv: chemin invalide", "err") return end
    -- déplacer vers un dossier existant : on garde le nom
    if FS.IsDir(b) then b = FS.Join(b, FS.Basename(a)) end
    local ok, err = FS.Rename(a, b)
    if not ok then st.out("mv: " .. (err or "erreur"), "err") end
end

commands.echo = function(st, args, raw)
    local text = raw:gsub("^%s*echo%s*", "")
    local body, op, dest = text:match("^(.-)%s*(>>?)%s*(.-)%s*$")
    if not op or dest == "" then st.out(text) return end
    body = body:gsub('^"(.*)"$', "%1")
    local target = fileTarget(st, dest)
    if not target then st.out("echo: nom invalide", "err") return end
    local old = ""
    if op == ">>" and FS.Exists(target) then old = (FS.Read(target) or "") .. "\n" end
    local ok, err = FS.Write(target, old .. body)
    if not ok then st.out("echo: " .. (err or "erreur"), "err") end
end

commands.open = function(st, args)
    if not args[1] then st.out("usage: open <fichier.txt>", "err") return end
    local name = args[1]
    if not name:lower():match("%.txt$") then name = name .. ".txt" end
    local target = resolve(st, name)
    if not target or not FS.Exists(target) then st.out("open: fichier introuvable", "err") return end
    if st.desktop then st.desktop:OpenApp("notepad", { path = target }) end
end

commands.browse = function(st, args, raw)
    local text = CW.Trim(raw:gsub("^%s*browse%s*", ""))
    if text == "" then st.out("usage: browse <adresse ou recherche>", "err") return end
    if st.desktop then st.desktop:OpenApp("browser", { input = text }) end
end

commands.play = function(st, args, raw)
    if not CW.CVars.music:GetBool() then st.out("play: musique désactivée par l'administrateur", "err") return end
    local radios = CW.Config.Radios or {}
    local query = CW.Trim(raw:gsub("^%s*play%s*", "")):lower()
    local pick
    if query == "" then
        pick = radios[1]
    elseif tonumber(query) then
        pick = radios[tonumber(query)]
    else
        for _, r in ipairs(radios) do
            if r.name:lower():find(query, 1, true) then pick = r break end
        end
    end
    if not pick then
        st.out("Stations :", "accent")
        for i, r in ipairs(radios) do st.out(string.format("  %d. %s  (%s)", i, r.name, r.genre or "")) end
        return
    end
    if CW.Audio then CW.Audio.Play({ name = pick.name, url = pick.url, genre = pick.genre, preset = true }) end
    st.out("Lecture : " .. pick.name, "ok")
end

commands.stop = function(st)
    if CW.Audio then CW.Audio.Stop() end
    st.out("Musique arrêtée.", "dim")
end

commands.wallpaper = function(st, args)
    local want = (args[1] or ""):lower()
    for _, name in ipairs(UI.Wallpapers) do
        if name == want then
            RunConsoleCommand("cw_wallpaper", name)
            st.out("Fond d'écran : " .. name, "ok")
            return
        end
    end
    st.out("Fonds disponibles : " .. table.concat(UI.Wallpapers, ", "), "accent")
end

commands.date = function(st) st.out(os.date("%A %d %B %Y, %H:%M:%S")) end
commands.whoami = function(st) st.out(IsValid(LocalPlayer()) and LocalPlayer():Nick() or "invite") end
commands.hostname = function(st) st.out("computerweb-" .. (UI.T.id or "nova")) end
commands.uname = function(st) st.out((UI.T.os or "ComputerWeb OS") .. " " .. CW.Version .. " (Garry's Mod)") end

commands.uptime = function(st)
    local s = math.floor(SysTime() - (st.started or SysTime()))
    st.out(string.format("session ouverte depuis %02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60))
end

commands.theme = function(st)
    st.out(string.format("Système : %s  |  disposition : %s  |  écran : %dx%d", UI.T.os, UI.T.layout, ScrW(), ScrH()))
end

commands.neofetch = function(st)
    local art = {
        "   ____  _      ",
        "  / ___|| |     ",
        " | |    | |  /\\ ",
        " | |___ | |_/  \\",
        "  \\____||____/\\_\\",
    }
    local info = {
        (IsValid(LocalPlayer()) and LocalPlayer():Nick() or "invite") .. "@" .. "computerweb-" .. (UI.T.id or "nova"),
        "OS      : " .. (UI.T.os or "ComputerWeb OS") .. " " .. CW.Version,
        "Shell   : cwsh",
        "Écran   : " .. ScrW() .. "x" .. ScrH(),
        "Moteur  : Garry's Mod",
    }
    for i = 1, math.max(#art, #info) do
        st.out(string.format("%-20s %s", art[i] or "", info[i] or ""), i <= #art and "accent" or nil)
    end
end

commands.ping = function(st, args)
    if not args[1] then st.out("usage: ping <hôte>", "err") return end
    st.out("(simulation - aucune requête réseau n'est envoyée)", "dim")
    st.out("PING " .. args[1]:sub(1, 60))
    for i = 1, 3 do
        st.out(string.format("64 octets de %s : icmp_seq=%d ttl=57 temps=%.1f ms", args[1]:sub(1, 60), i, 8 + math.random() * 20))
    end
end

commands.exit = function(st)
    if st.desktop then st.desktop:Shutdown() end
end

--- Exécute une ligne. Renvoie true si la commande existe.
function Term.Run(state, line)
    line = CW.Trim(line)
    if line == "" then return true end
    local args = Term.Split(line)
    local name = (args[1] or ""):lower()
    table.remove(args, 1)
    local fn = commands[name]
    if not fn then
        state.out(name .. ": commande introuvable (tapez 'help')", "err")
        return false
    end
    local ok, err = pcall(fn, state, args, line)
    if not ok then state.out("erreur interne : " .. tostring(err), "err") end
    return true
end

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
local function openTerminal(desktop)
    local win = UI.Window(desktop, {
        title = "Terminal", icon = "terminal", app = "terminal",
        w = S(720), h = S(440), minW = S(420), minH = S(240),
    })
    local content = win:GetContent()

    local lines = {}               -- { texte, genre }
    local scroll = 0               -- lignes remontées
    local history, histPos = {}, 0
    local MAXLINES = 400

    local state = { cwd = "Documents", desktop = desktop, started = SysTime() }
    if not FS.IsDir(state.cwd) then state.cwd = "" end

    local view, push              -- déclarés ici : utilisés par les callbacks ci-dessous
    local promptW = S(150)

    -- Ligne de saisie (BOTTOM) créée AVANT la vue (FILL) : ordre de docking
    local inputRow = vgui.Create("DPanel", content)
    inputRow:Dock(BOTTOM)
    inputRow:SetTall(S(38))
    inputRow:DockPadding(0, S(4), S(6), S(4))
    inputRow.Paint = function(self, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.panel.r, c.panel.g, c.panel.b, 255)
        surface.DrawRect(0, 0, w, h)
        local p = promptPath(state.cwd) .. " " .. (UI.T.mono and "#" or "$")
        draw.SimpleText(p, "CW.MonoBold", S(10), h / 2, c.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("CW.MonoBold")
        promptW = surface.GetTextSize(p) + S(18)
    end

    local entry = UI.Entry(inputRow)
    entry:SetFont("CW.Mono")
    entry:Dock(FILL)
    entry.Think = function(self)
        if self.cwMargin ~= promptW then
            self.cwMargin = promptW
            self:DockMargin(promptW, 0, 0, 0)
        end
    end

    entry.OnEnter = function(self)
        local line = self:GetValue()
        self:SetText("")
        if CW.Trim(line) ~= "" then
            history[#history + 1] = line
            if #history > 60 then table.remove(history, 1) end
        end
        histPos = #history + 1
        push(promptPath(state.cwd) .. " $ " .. line, "dim")
        Term.Run(state, line)
        timer.Simple(0, function() if IsValid(self) then self:RequestFocus() end end)
    end

    local baseKey = entry.OnKeyCodeTyped
    entry.OnKeyCodeTyped = function(self, code)
        if code == KEY_UP and #history > 0 then
            histPos = math.max(1, histPos - 1)
            self:SetText(history[histPos] or "")
            self:SetCaretPos(#self:GetText())
            return true
        elseif code == KEY_DOWN and #history > 0 then
            histPos = math.min(#history + 1, histPos + 1)
            self:SetText(history[histPos] or "")
            self:SetCaretPos(#self:GetText())
            return true
        end
        if baseKey then return baseKey(self, code) end
    end

    -- Zone d'affichage
    view = vgui.Create("DPanel", content)
    view:Dock(FILL)

    local function charsPerLine(w)
        surface.SetFont("CW.Mono")
        local cw = surface.GetTextSize("M")
        return math.max(10, math.floor((w - S(20)) / math.max(cw, 1)))
    end

    push = function(text, kind)
        text = tostring(text):gsub("\t", "    ")
        local width = charsPerLine(view:GetWide() > 0 and view:GetWide() or S(700))
        if #text == 0 then lines[#lines + 1] = { "", kind } end
        while #text > 0 do
            lines[#lines + 1] = { text:sub(1, width), kind }
            text = text:sub(width + 1)
        end
        while #lines > MAXLINES do table.remove(lines, 1) end
        scroll = 0
    end

    state.out = push
    state.clear = function() lines = {}; scroll = 0 end

    view.Paint = function(self, w, h)
        local c = UI.T.c
        surface.SetDrawColor(c.input.r, c.input.g, c.input.b, 255)
        surface.DrawRect(0, 0, w, h)
        local lh = S(18)
        local fit = math.floor((h - S(10)) / lh)
        local last = #lines - scroll
        local first = math.max(1, last - fit + 1)
        local y = h - S(6) - (last - first + 1) * lh
        for i = first, last do
            local l = lines[i]
            local col = c.windowText
            if l[2] == "dim" then col = c.dim
            elseif l[2] == "err" then col = c.danger
            elseif l[2] == "ok" then col = c.ok
            elseif l[2] == "accent" then col = c.accent end
            draw.SimpleText(l[1], "CW.Mono", S(10), y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + lh
        end
    end
    view.OnMouseWheeled = function(self, delta)
        scroll = math.Clamp(scroll + delta * 3, 0, math.max(#lines - 3, 0))
    end

    push(UI.T.os .. " " .. CW.Version .. " - terminal", "accent")
    push("Tapez 'help' pour la liste des commandes.", "dim")
    entry:RequestFocus()
    return win
end

OS.RegisterApp("terminal", {
    name = "Terminal", icon = "terminal", order = 4, single = false,
    open = openTerminal,
})
