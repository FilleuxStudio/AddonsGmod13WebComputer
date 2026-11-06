# Changelog

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
