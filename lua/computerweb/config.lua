--[[----------------------------------------------------------------------------
    ComputerWeb - CONFIGURATION (fichier à modifier par l'administrateur)

    Ce fichier est chargé côté serveur ET côté client (il est envoyé
    automatiquement aux joueurs). Après modification, redémarrez la map
    (ou le serveur) pour que tout le monde reçoive la nouvelle version.

    Réglages "en direct" (sans redémarrage) : voir les ConVars `cw_*`
    dans le README (ex. `cw_url_filter 1`, `cw_browser_enabled 0`).
------------------------------------------------------------------------------]]

ComputerWeb = ComputerWeb or {}

ComputerWeb.Config = {

    ---------------------------------------------------------------------------
    -- NAVIGATEUR
    ---------------------------------------------------------------------------

    -- Moteurs de recherche proposés. `url` doit contenir %s (la requête).
    -- `safe` est ajouté à l'URL quand `cw_safesearch 1` (recherche protégée).
    SearchEngines = {
        duckduckgo = { name = "DuckDuckGo", url = "https://html.duckduckgo.com/html/?q=%s", safe = "&kp=1" },
        bing       = { name = "Bing",       url = "https://www.bing.com/search?q=%s",       safe = "&adlt=strict" },
        google     = { name = "Google",     url = "https://www.google.com/search?q=%s",     safe = "&safe=active" },
    },
    DefaultSearchEngine = "duckduckgo",

    -- Raccourcis de la page d'accueil du navigateur.
    -- (Volontairement SANS Gmail / Facebook : se connecter à un vrai compte
    --  dans un jeu est risqué, et ces sites bloquent les navigateurs intégrés.)
    HomeTiles = {
        { name = "Wikipédia",     url = "https://fr.wikipedia.org/",           color = Color(70, 130, 220) },
        { name = "YouTube",       url = "https://www.youtube.com/",            color = Color(220, 60, 60)  },
        { name = "Wiki GMod",     url = "https://wiki.facepunch.com/gmod/",    color = Color(60, 170, 200) },
        { name = "Steam",         url = "https://store.steampowered.com/",     color = Color(60, 80, 120)  },
        { name = "OpenStreetMap", url = "https://www.openstreetmap.org/",      color = Color(80, 170, 100) },
        { name = "Météo France",  url = "https://meteofrance.com/",            color = Color(230, 150, 50) },
    },

    ---------------------------------------------------------------------------
    -- FILTRAGE (utile pour un serveur RP / DarkRP)
    ---------------------------------------------------------------------------

    -- Utilisés uniquement si `cw_url_filter 1` (liste blanche stricte).
    -- Un domaine autorise aussi ses sous-domaines (wikipedia.org => fr.wikipedia.org).
    AllowedDomains = {
        "duckduckgo.com", "bing.com", "google.com",
        "wikipedia.org", "wikimedia.org",
        "youtube.com", "ytimg.com", "googlevideo.com",
        "facepunch.com", "steampowered.com", "steamstatic.com",
        "openstreetmap.org", "meteofrance.com",
    },

    -- Toujours bloqués, quel que soit le mode.
    BlockedDomains = {
        -- "exemple.com",
    },

    ---------------------------------------------------------------------------
    -- MUSIQUE (application "Musique")
    ---------------------------------------------------------------------------

    -- Flux audio directs (jouables via sound.PlayURL, sans dépendre du moteur
    -- web). URLs officielles SomaFM - ajoutez les vôtres au même format.
    Radios = {
        { name = "Groove Salad",   genre = "Ambient / Downtempo", url = "https://ice.somafm.com/groovesalad"  },
        { name = "Deep Space One", genre = "Ambient / Espace",    url = "https://ice.somafm.com/deepspaceone" },
        { name = "Drone Zone",     genre = "Ambient",             url = "https://ice.somafm.com/dronezone"    },
        { name = "Secret Agent",   genre = "Lounge / Espion",     url = "https://ice.somafm.com/secretagent"  },
        { name = "Lush",           genre = "Chill / Vocal",       url = "https://ice.somafm.com/lush"         },
    },

    ---------------------------------------------------------------------------
    -- ÉCRANS 3D (entités monitorMusic / monitorMusciTwo)
    ---------------------------------------------------------------------------

    -- Pages proposées dans la télécommande des écrans (touche E sur l'écran).
    -- Anciennes vidéos conservées pour mémoire (à vérifier / remplacer) :
    --   vXoJI2AkSBo, cxVKech_xKU, HLL9d34sg3Y, o_3t40p8ky8, c6TvN5Cgdjo
    ScreenPresets = {
        { name = "Écran 1 (par défaut)", url = "https://www.youtube.com/watch?v=aOa_H4srt74" },
        { name = "Écran 2 (par défaut)", url = "https://www.youtube.com/watch?v=DGNewPg2FDI" },
        { name = "YouTube - accueil",    url = "https://www.youtube.com/" },
        { name = "Wikipédia",            url = "https://fr.wikipedia.org/" },
    },
}
