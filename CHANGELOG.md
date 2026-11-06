# Changelog

## 2.2.0 — Outils Cipher, radio 3D, nouvelle jaquette

### Nouveautés
- **Cipher** (classe `computerKali` conservée pour la compatibilité) : outils d'ambiance 100 % simulés — application **Réseau** (scan, ping, ports, intrusion simulée), application **Matrix**, commandes `scan`, `ping`, `ports`, `hack` du terminal. Ces outils agissent sur les ordinateurs, écrans et radios placés dans la scène ; aucun trafic réel n'est émis.
- Hook serveur optionnel `ComputerWeb_HackSimulated(ply, ent)` pour brancher un scénario RP.
- **Radio interactive** `cw_radio` (modèle HL2 `citizenradio`) : touche E → choix de la station, marche/arrêt, volume (`cw_radio_volume`) ; son 3D spatialisé, état synchronisé pour tous.
- Applications réservées à un thème (`themes = {...}` dans `OS.RegisterApp`).
- Nouvelle jaquette semi-réaliste (anglais et français) ; anciennes images conservées dans `docs/`.
- README en français (`README.fr.md`) et en anglais (`README.md`).

### Sécurité
- Messages radio/hack revalidés côté serveur (entité, distance, cadence, plages de valeurs).

### Tests
- 651+ vérifications automatiques.

## 2.1.0 — Retro98, micro-applications, personnalisation

### Nouveautés
- **Thème Retro98** et ordinateur `computerRetro` : relief biseauté, barre de titre dégradée, bouton Démarrer, fond turquoise, fanfare de démarrage. Design et sons originaux (aucun logo ni son de marque).
- **Éditeur** : bloc-notes amélioré (rechercher/remplacer, taille de police, police fixe, ligne/colonne, mots, Ctrl+S / Ctrl+F / Ctrl+T).
- **Calculatrice** (évaluateur sans `loadstring`), **Démineur** (3 niveaux, premier clic sûr), **Dessin** (enregistrement dans Documents).
- **Couleur du système** réglable en direct (Paramètres → Couleurs, ou `accent r g b` dans le terminal).
- **Raccourcis de bureau** vers une application, un site ou un fichier, avec icône au choix ; dialogue dédié, gestion dans Paramètres → Bureau, suppression par clic droit.
- Terminal : `start`, `edit`, `calc`, `accent`.

### Sécurité
- Les raccourcis (et leur fichier de sauvegarde) sont entièrement revalidés à la lecture : types, identifiants, URL (garde d'URL), chemins, longueurs, caractères de contrôle.
- Les fichiers de dessin relus sont bornés (couleurs, épaisseurs, coordonnées, nombre de traits et de points).

### Tests
- 552 vérifications automatiques (logique, sécurité, ouverture et dessin de chaque thème/application dans un faux environnement GMod).

## 2.0.0 — Refonte complète

### Nouveautés
- Bureau entièrement redessiné : 4 thèmes (Nova, Terra, Cipher, Sandbox), fenêtres déplaçables / redimensionnables / agrandissables / réductibles, barre des tâches ou dock, menu démarrer, notifications, écran de démarrage avec son.
- Applications : **Navigateur** (onglets de tuiles, moteurs de recherche, SafeSearch), **Fichiers** (dossiers et fichiers `.txt` par joueur), **Bloc-notes**, **Musique** (radios + favoris + URL), **Terminal** (`help`, `ls`, `cd`, `cat`, `neofetch`, `theme`…), **Paramètres** (thème, fond d'écran, diagnostic web).
- Écrans 3D : la page ne se charge que si un joueur est proche, volume selon la distance, télécommande avec la touche E.
- Configuration administrateur (`lua/computerweb/config.lua`) et ConVars `cw_*` en direct.
- Icônes, fonds d'écran, icônes de spawnmenu, sons et visuels de couverture 100 % originaux (scripts de génération dans `tools/`).

### Corrections
- Code modulaire chargé via `lua/autorun/computerweb.lua` avec `AddCSLuaFile` correct (les anciens `include` sans extension ne fonctionnaient plus).
- Chaînes réseau déclarées, anciens `umsg` supprimés, sons `.wav` cohérents.
- Plus de spam dans le chat ; anti-spam par joueur côté serveur.
- Appels API vérifiés dans le wiki : `StopLoading`, `QueueJavascript`, `OnBeginLoadingDocument`.

### Sécurité
- Garde d'URL : schémas dangereux, réseaux privés/loopback/IPv6/IP numériques, astuce `user@host`, liste blanche (sous-domaines inclus), liste noire, hook `ComputerWeb_CanOpenURL`.
- Toutes les requêtes client sont revalidées côté serveur (distance, cooldown, paramètres).
- Aucun pont JavaScript exposé aux sites distants, `SetAllowLua(false)` partout.

### Retiré
- Logos et sons de marques tierces, tuiles Gmail/Facebook, modèle et matériaux tiers inutilisés (`gore_e2b`).
