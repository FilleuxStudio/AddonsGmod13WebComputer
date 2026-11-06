#!/usr/bin/env python3
"""Génère les icônes PNG (128x128, fond transparent) de ComputerWeb.

Créations 100 % originales (aucun logo de marque). Rendu via Chromium/Playwright.
Usage : python3 tools/gen_icons.py
"""
import math
import os
from playwright.sync_api import sync_playwright

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "materials", "computerweb", "icons")
os.makedirs(OUT, exist_ok=True)

W = 'stroke="#fff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none"'
WF = 'fill="#fff"'


def gear(cx, cy, r_out, r_in, teeth=8, hole=10):
    pts = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step
        for da, r in ((-0.30, r_in), (-0.17, r_out), (0.17, r_out), (0.30, r_in)):
            ang = a + da * step * 1.6
            pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"
    return f'<path d="{d}" fill="#fff"/><circle cx="{cx}" cy="{cy}" r="{hole}" fill="rgba(0,0,0,0.0)" stroke="none"/>'


def tile(c1, c2, inner, rx=30):
    gid = f"g{abs(hash((c1, c2))) % 10**6}"
    return (f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>'
            f'<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="3" stdDeviation="3" flood-opacity="0.35"/></filter></defs>'
            f'<rect x="6" y="6" width="116" height="116" rx="{rx}" fill="url(#{gid})" filter="url(#sh)"/>'
            f'<rect x="6" y="6" width="116" height="58" rx="{rx}" fill="#fff" opacity="0.10"/>'
            f'{inner}')


ICONS = {}

# --- Tuiles d'applications (couleur) ---------------------------------------
globe = (f'<circle cx="64" cy="64" r="30" {W}/>'
         f'<ellipse cx="64" cy="64" rx="13" ry="30" {W} stroke-width="6"/>'
         f'<path d="M34 64 H94 M38 50 H90 M38 78 H90" {W} stroke-width="6"/>')
ICONS["browser"] = tile("#3FA9FF", "#2457E6", globe)

ICONS["files"] = tile("#2BC4B8", "#1479C9",
    '<path d="M28 46 a6 6 0 0 1 6-6 h20 l8 9 h32 a6 6 0 0 1 6 6 v36 a6 6 0 0 1-6 6 H34 a6 6 0 0 1-6-6 z" fill="#fff"/>'
    '<path d="M28 58 h72" stroke="#1479C9" stroke-width="4" opacity="0.35"/>')

ICONS["notepad"] = tile("#FFC247", "#F08A1C",
    '<rect x="34" y="26" width="60" height="76" rx="8" fill="#fff"/>'
    '<path d="M46 48 H82 M46 62 H82 M46 76 H70" stroke="#F08A1C" stroke-width="6" stroke-linecap="round"/>'
    '<path d="M34 26 h60 v12 h-60 z" fill="#F08A1C" opacity="0.35"/>')

ICONS["music"] = tile("#FF5CA8", "#7B3FE4",
    '<path d="M54 80 V40 L90 32 V72" stroke="#fff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    '<ellipse cx="46" cy="82" rx="12" ry="9" fill="#fff"/><ellipse cx="82" cy="74" rx="12" ry="9" fill="#fff"/>')

ICONS["terminal"] = tile("#2B3442", "#0D1218",
    '<path d="M34 46 L58 64 L34 82" stroke="#38F5A8" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    '<path d="M68 86 H96" stroke="#38F5A8" stroke-width="10" stroke-linecap="round"/>')

ICONS["settings"] = tile("#7D8AA3", "#3C4658", gear(64, 64, 34, 26, 8) +
    '<circle cx="64" cy="64" r="11" fill="#47526A"/>')


# --- Micro-applications ------------------------------------------------------
ICONS["editor"] = tile("#5B8CFF", "#2B3EC9",
    '<rect x="32" y="24" width="64" height="80" rx="8" fill="#fff"/>'
    '<path d="M44 44 H84 M44 58 H84 M44 72 H66" stroke="#2B3EC9" stroke-width="6" stroke-linecap="round"/>'
    '<path d="M70 98 L100 54 a6 6 0 0 1 9 8 L82 104 z" fill="#FFC247" stroke="#fff" stroke-width="4" stroke-linejoin="round"/>')

ICONS["calc"] = tile("#4B5568", "#1E2533",
    '<rect x="30" y="22" width="68" height="84" rx="9" fill="#EDF1F8"/>'
    '<rect x="38" y="30" width="52" height="20" rx="4" fill="#2BC4B8"/>'
    + "".join(f'<rect x="{38 + c * 14}" y="{58 + r * 15}" width="10" height="10" rx="3" fill="{"#F08A1C" if c == 3 else "#8FA1C4"}"/>'
              for r in range(3) for c in range(4)))

ICONS["mines"] = tile("#FF6A5C", "#B3242E",
    '<circle cx="64" cy="66" r="22" fill="#1B1F2A"/>'
    + "".join(f'<path d="M64 66 L{64+math.cos(a)*34:.1f} {66+math.sin(a)*34:.1f}" stroke="#1B1F2A" stroke-width="7" stroke-linecap="round"/>' for a in [i*math.pi/4 for i in range(8)])
    + '<circle cx="56" cy="58" r="6" fill="#fff" opacity="0.8"/>')

ICONS["paint"] = tile("#FF9F43", "#E0357B",
    '<path d="M64 28 C36 28 24 50 28 70 C32 90 52 102 68 100 C80 99 78 88 86 84 C98 78 104 70 100 52 C96 36 82 28 64 28 Z" fill="#fff"/>'
    '<circle cx="48" cy="56" r="7" fill="#E0357B"/><circle cx="66" cy="44" r="7" fill="#FFC247"/>'
    '<circle cx="86" cy="56" r="7" fill="#2BC4B8"/><circle cx="50" cy="78" r="7" fill="#5B8CFF"/>')


# --- Outils Cipher -------------------------------------------------------------
ICONS["netlab"] = tile("#12303F", "#04100C",
    '<circle cx="64" cy="66" r="34" stroke="#2BFFA0" stroke-width="5" fill="none" opacity="0.9"/>'
    '<circle cx="64" cy="66" r="20" stroke="#2BFFA0" stroke-width="4" fill="none" opacity="0.6"/>'
    '<circle cx="64" cy="66" r="6" fill="#2BFFA0"/>'
    '<path d="M64 66 L92 44" stroke="#2BFFA0" stroke-width="5" stroke-linecap="round"/>'
    '<circle cx="86" cy="52" r="5" fill="#FF5C6C"/><circle cx="44" cy="78" r="4" fill="#2BFFA0" opacity="0.8"/>')

ICONS["matrix"] = tile("#06150F", "#010504",
    "".join(f'<text x="{x}" y="{y}" font-family="monospace" font-weight="700" font-size="22" fill="#2BFFA0" opacity="{o}">{c}</text>'
            for x, y, o, c in [(26,44,0.35,"1"),(26,66,0.65,"0"),(26,88,1,"7"),(50,34,0.4,"A"),(50,56,0.7,"3"),(50,78,1,"X"),(50,100,0.45,"0"),
                               (74,48,0.4,"9"),(74,70,0.75,"F"),(74,92,1,"1"),(98,40,0.35,"0"),(98,62,0.65,"B"),(98,84,1,"4")]))

# --- Dossier / fichier (couleur, sans tuile) --------------------------------
ICONS["folder"] = (
    '<defs><linearGradient id="fg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD76A"/><stop offset="1" stop-color="#F2A93B"/></linearGradient>'
    '<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="3" stdDeviation="3" flood-opacity="0.3"/></filter></defs>'
    '<path d="M12 36 a8 8 0 0 1 8-8 h30 l10 12 h48 a8 8 0 0 1 8 8 v48 a8 8 0 0 1-8 8 H20 a8 8 0 0 1-8-8 z" fill="#E59A2C" filter="url(#sh)"/>'
    '<path d="M12 52 a8 8 0 0 1 8-8 h88 a8 8 0 0 1 8 8 v40 a8 8 0 0 1-8 8 H20 a8 8 0 0 1-8-8 z" fill="url(#fg)"/>')

ICONS["file"] = (
    '<defs><filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="3" stdDeviation="3" flood-opacity="0.3"/></filter></defs>'
    '<path d="M28 10 h46 l28 28 v72 a8 8 0 0 1-8 8 H28 a8 8 0 0 1-8-8 V18 a8 8 0 0 1 8-8 z" fill="#F4F7FC" stroke="#B9C4DA" stroke-width="4" filter="url(#sh)"/>'
    '<path d="M74 10 v28 h28" fill="#C8D3EA" stroke="#B9C4DA" stroke-width="4" stroke-linejoin="round"/>'
    '<path d="M36 62 H84 M36 76 H84 M36 90 H66" stroke="#8FA1C4" stroke-width="6" stroke-linecap="round"/>')

# --- Glyphes blancs (teintés dans le jeu) -----------------------------------
ICONS["back"] = f'<path d="M80 24 L40 64 L80 104" {W}/>'
ICONS["forward"] = f'<path d="M48 24 L88 64 L48 104" {W}/>'
ICONS["reload"] = (f'<path d="M100 64 a36 36 0 1 1 -11 -26" {W}/>'
                   f'<path d="M92 20 V44 H68" {W}/>')
ICONS["home"] = (f'<path d="M20 66 L64 26 L108 66" {W}/>'
                 f'<path d="M34 58 V100 H54 V74 H74 V100 H94 V58" {W}/>')
ICONS["menu"] = f'<circle cx="64" cy="26" r="9" {WF}/><circle cx="64" cy="64" r="9" {WF}/><circle cx="64" cy="102" r="9" {WF}/>'
ICONS["up"] = f'<path d="M34 76 L64 46 L94 76" {W}/><path d="M64 48 V100" {W}/>'
ICONS["close"] = f'<path d="M32 32 L96 96 M96 32 L32 96" {W}/>'
ICONS["search"] = f'<circle cx="54" cy="54" r="28" {W}/><path d="M76 76 L104 104" {W}/>'
ICONS["power"] = f'<path d="M44 34 a42 42 0 1 0 40 0" {W}/><path d="M64 14 V62" {W}/>'
ICONS["newfolder"] = (f'<path d="M14 40 a6 6 0 0 1 6-6 h24 l8 10 h40 a6 6 0 0 1 6 6 v40 a6 6 0 0 1-6 6 H20 a6 6 0 0 1-6-6 z" {W} stroke-width="8"/>'
                      f'<path d="M96 70 V104 M79 87 H113" {W} stroke-width="9"/>')
ICONS["newfile"] = (f'<path d="M30 14 h38 l26 26 v68 a6 6 0 0 1-6 6 H30 a6 6 0 0 1-6-6 V20 a6 6 0 0 1 6-6 z" {W} stroke-width="8"/>'
                    f'<path d="M68 14 v26 h26" {W} stroke-width="8"/><path d="M59 64 V96 M43 80 H75" {W} stroke-width="9"/>')
ICONS["rename"] = (f'<path d="M22 106 L28 82 L82 28 a10 10 0 0 1 14 0 l4 4 a10 10 0 0 1 0 14 L46 100 z" {W} stroke-width="8"/>'
                   f'<path d="M72 38 L90 56" {W} stroke-width="8"/>')
ICONS["trash"] = (f'<path d="M24 36 H104" {W}/><path d="M50 36 V22 H78 V36" {W}/>'
                  f'<path d="M32 36 L38 106 H90 L96 36" {W}/><path d="M54 54 V90 M74 54 V90" {W} stroke-width="8"/>')
ICONS["save"] = (f'<path d="M20 26 a6 6 0 0 1 6-6 H88 L108 40 V102 a6 6 0 0 1-6 6 H26 a6 6 0 0 1-6-6 z" {W} stroke-width="8"/>'
                 f'<path d="M40 20 V46 H80 V20" {W} stroke-width="8"/><rect x="38" y="70" width="52" height="30" rx="4" {W} stroke-width="8"/>')
ICONS["open"] = (f'<path d="M14 42 a6 6 0 0 1 6-6 h24 l8 10 h40 a6 6 0 0 1 6 6 v10" {W} stroke-width="8"/>'
                 f'<path d="M14 106 L28 62 a6 6 0 0 1 6-4 h82 a4 4 0 0 1 4 5 L104 104 a6 6 0 0 1-6 4 H20 z" {W} stroke-width="8"/>')
ICONS["play"] = f'<path d="M40 24 L100 64 L40 104 Z" {WF}/>'
ICONS["pause"] = f'<rect x="32" y="24" width="22" height="80" rx="5" {WF}/><rect x="74" y="24" width="22" height="80" rx="5" {WF}/>'
ICONS["stop"] = f'<rect x="28" y="28" width="72" height="72" rx="10" {WF}/>'
ICONS["next"] = f'<path d="M26 26 L80 64 L26 102 Z" {WF}/><rect x="86" y="26" width="16" height="76" rx="5" {WF}/>'
ICONS["prev"] = f'<path d="M102 26 L48 64 L102 102 Z" {WF}/><rect x="26" y="26" width="16" height="76" rx="5" {WF}/>'
ICONS["volume"] = (f'<path d="M20 50 H42 L70 26 V102 L42 78 H20 Z" {WF}/>'
                   f'<path d="M86 46 a26 26 0 0 1 0 36" {W} stroke-width="8"/><path d="M98 32 a46 46 0 0 1 0 64" {W} stroke-width="8"/>')


def page(name, body):
    return (f'<!doctype html><meta charset="utf-8"><body style="margin:0;background:transparent">'
            f'<svg id="s" xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{body}</svg>')


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={"width": 128, "height": 128}, device_scale_factor=1)
        pg = ctx.new_page()
        for name, body in ICONS.items():
            pg.set_content(page(name, body))
            pg.locator("#s").screenshot(path=os.path.join(OUT, f"{name}.png"), omit_background=True)
        browser.close()
    print(f"{len(ICONS)} icônes générées dans {os.path.abspath(OUT)}")


if __name__ == "__main__":
    main()
