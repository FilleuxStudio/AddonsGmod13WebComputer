#!/usr/bin/env python3
"""Génère fonds d'écran (1280x720 jpg), icônes d'entités (256x256 png) et visuels
de couverture. Créations originales, rendues via Chromium/Playwright."""
import os, random, math
from playwright.sync_api import sync_playwright

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WALL = os.path.join(ROOT, "materials", "computerweb", "wall")
ENT = os.path.join(ROOT, "materials", "entities")
DOCS = os.path.join(ROOT, "docs")
for d in (WALL, ENT, DOCS):
    os.makedirs(d, exist_ok=True)


def blobs(seed, colors, n=6, w=1280, h=720):
    r = random.Random(seed)
    out = ""
    for i in range(n):
        c = colors[i % len(colors)]
        out += (f'<circle cx="{r.randint(0,w)}" cy="{r.randint(0,h)}" r="{r.randint(180,420)}" '
                f'fill="{c}" opacity="{r.uniform(0.25,0.55):.2f}" filter="url(#b)"/>')
    return out


def wall_svg(name, w=1280, h=720):
    defs = '<defs><filter id="b" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter></defs>'
    if name == "nova":
        bg = '<rect width="100%" height="100%" fill="#0B1B4A"/>' + blobs(1, ["#2F7BFF", "#7A4DFF", "#18C6E8", "#1E3FA8"])
        extra = ''.join(f'<path d="M-100 {600-i*40} C 300 {450-i*30}, 700 {750-i*20}, 1400 {380-i*45}" stroke="#fff" stroke-opacity="0.07" stroke-width="2" fill="none"/>' for i in range(10))
    elif name == "terra":
        bg = '<rect width="100%" height="100%" fill="#3A1030"/>' + blobs(2, ["#E95420", "#8E2A7A", "#F59B3A", "#5A1B4D"])
        extra = ''.join(f'<circle cx="640" cy="720" r="{200+i*90}" stroke="#fff" stroke-opacity="0.06" stroke-width="2" fill="none"/>' for i in range(8))
    elif name == "cipher":
        r = random.Random(3)
        bg = '<rect width="100%" height="100%" fill="#050A10"/>' + blobs(3, ["#0E3A55", "#093B2E"], 4)
        extra = ''.join(f'<text x="{x}" y="{y}" font-family="monospace" font-size="16" fill="#2BFFA0" opacity="{r.uniform(0.05,0.35):.2f}">{"".join(r.choice("01ABCDEF") for _ in range(r.randint(6,16)))}</text>'
                        for x in range(10, w, 70) for y in range(20, h, 26) if r.random() < 0.25)
        extra += ''.join(f'<path d="M0 {y} H{w}" stroke="#2BFFA0" stroke-opacity="0.025" stroke-width="2"/>' for y in range(0, h, 6))
    elif name == "retro":
        bg = '<rect width="100%" height="100%" fill="#008080"/>'
        extra = ('<rect width="100%" height="100%" fill="url(#vg)"/>'
                 + ''.join(f'<circle cx="{x}" cy="{y}" r="2" fill="#fff" opacity="0.10"/>' for x in range(20, w, 48) for y in range(20, h, 48))
                 + '<g opacity="0.10" fill="#fff"><rect x="860" y="470" width="260" height="170" rx="6"/><rect x="880" y="490" width="220" height="120" fill="#008080"/></g>')
        defs = defs.replace('</defs>', '<radialGradient id="vg" cx="0.5" cy="0.5" r="0.75"><stop offset="0.6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.28"/></radialGradient></defs>')
    elif name == "sandbox":
        bg = '<rect width="100%" height="100%" fill="#3B4252"/>' + blobs(4, ["#F2B134", "#5E81AC", "#A3BE8C", "#BF616A"], 5)
        r = random.Random(5)
        extra = ''.join(f'<rect x="{r.randint(0,w)}" y="{r.randint(0,h)}" width="{s}" height="{s}" rx="6" fill="#fff" opacity="0.06" transform="rotate({r.randint(0,80)} 600 360)"/>' for s in [r.randint(40,140) for _ in range(18)])
    elif name == "aurora":
        bg = '<rect width="100%" height="100%" fill="#06141F"/>' + blobs(6, ["#19E3A6", "#2A7BFF", "#A04DFF", "#0FB5C9"], 6)
        extra = ''.join(f'<path d="M0 {260+i*30} C 320 {120+i*25}, 800 {420-i*10}, 1280 {200+i*20}" stroke="#7CFFD2" stroke-opacity="0.08" stroke-width="{10+i*4}" fill="none" filter="url(#b)"/>' for i in range(6))
    else:  # graphite
        bg = '<rect width="100%" height="100%" fill="#14161B"/>' + blobs(7, ["#2A2F3A", "#3A4150", "#1E2230"], 4)
        extra = ''.join(f'<path d="M{i*80} 0 L{i*80+360} {h}" stroke="#fff" stroke-opacity="0.025" stroke-width="30"/>' for i in range(-4, 18))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{bg}{extra}</svg>'


def screen_glyph(kind, accent, w=256):
    """Petit écran stylisé pour les icônes d'entités."""
    inner = {
        "nova": '<rect x="62" y="128" width="124" height="10" rx="3" fill="#fff" opacity="0.9"/><circle cx="84" cy="133" r="6" fill="#fff"/><rect x="198" y="128" width="18" height="10" rx="3" fill="#fff" opacity="0.5"/>',
        "terra": '<rect x="46" y="48" width="12" height="102" rx="3" fill="#fff" opacity="0.9"/><circle cx="52" cy="62" r="3" fill="%s"/><circle cx="52" cy="80" r="3" fill="%s"/>' % (accent, accent),
        "cipher": '<path d="M70 70 L96 88 L70 106" stroke="#2BFFA0" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="M108 108 H150" stroke="#2BFFA0" stroke-width="8" stroke-linecap="round"/>',
        "sandbox": '<rect x="70" y="66" width="40" height="30" rx="6" fill="#fff" opacity="0.9"/><rect x="120" y="66" width="40" height="30" rx="6" fill="#fff" opacity="0.6"/><rect x="170" y="66" width="40" height="30" rx="6" fill="#fff" opacity="0.4"/>',
        "retro": '<rect x="62" y="64" width="132" height="86" fill="#c0c0c0"/><rect x="62" y="64" width="132" height="14" fill="#000080"/><rect x="68" y="86" width="120" height="58" fill="#fff"/><path d="M76 100 H170 M76 114 H150" stroke="#808080" stroke-width="5"/><rect x="34" y="150" width="188" height="16" fill="#c0c0c0"/><rect x="38" y="154" width="38" height="9" fill="#000080"/>',
        "web": '<circle cx="128" cy="96" r="34" stroke="#fff" stroke-width="7" fill="none"/><ellipse cx="128" cy="96" rx="14" ry="34" stroke="#fff" stroke-width="5" fill="none"/><path d="M94 96 H162" stroke="#fff" stroke-width="5"/>',
        "music": '<path d="M112 120 V72 L156 62 V108" stroke="#fff" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/><ellipse cx="102" cy="122" rx="14" ry="10" fill="#fff"/><ellipse cx="146" cy="110" rx="14" ry="10" fill="#fff"/>',
    }[kind]
    bgs = {"nova": ("#2F7BFF", "#7A4DFF"), "terra": ("#E95420", "#8E2A7A"), "cipher": ("#0E3A55", "#04100C"),
           "sandbox": ("#F2B134", "#5E81AC"), "web": ("#18C6E8", "#2457E6"), "retro": ("#008080", "#006666"), "music": ("#FF5CA8", "#7B3FE4")}[kind]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{w}" viewBox="0 0 256 256">'
            f'<defs><linearGradient id="sc" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{bgs[0]}"/><stop offset="1" stop-color="{bgs[1]}"/></linearGradient>'
            f'<linearGradient id="fr" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4A5568"/><stop offset="1" stop-color="#1A202C"/></linearGradient>'
            f'<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="6" stdDeviation="6" flood-opacity="0.4"/></filter></defs>'
            f'<g filter="url(#sh)"><rect x="24" y="30" width="208" height="150" rx="14" fill="url(#fr)"/>'
            f'<rect x="34" y="40" width="188" height="130" rx="6" fill="url(#sc)"/>'
            f'<rect x="34" y="40" width="188" height="60" rx="6" fill="#fff" opacity="0.10"/>'
            f'<g>{inner}</g>'
            f'<path d="M108 180 H148 L156 212 H100 Z" fill="#2D3748"/><rect x="76" y="210" width="104" height="14" rx="7" fill="#4A5568"/></g></svg>')


def cover_svg(w=1280, h=640):
    mini = lambda x, y, s, c1, c2, glyph: (
        f'<g transform="translate({x} {y}) scale({s})"><rect width="300" height="200" rx="16" fill="#1A202C"/>'
        f'<rect x="10" y="10" width="280" height="170" rx="8" fill="url(#{c1})"/>'
        f'<rect x="10" y="10" width="280" height="75" rx="8" fill="#fff" opacity="0.08"/>{glyph}</g>')
    gl_bar = ('<rect x="10" y="156" width="280" height="24" fill="#000" opacity="0.4"/><circle cx="26" cy="168" r="6" fill="#fff"/>'
              '<rect x="60" y="62" width="110" height="70" rx="6" fill="#fff" opacity="0.92"/><rect x="60" y="62" width="110" height="14" rx="6" fill="#2F7BFF"/>'
              '<rect x="72" y="88" width="70" height="6" rx="3" fill="#B9C4DA"/><rect x="72" y="102" width="50" height="6" rx="3" fill="#B9C4DA"/>')
    gl_dock = ('<rect x="10" y="10" width="26" height="170" rx="6" fill="#000" opacity="0.4"/>'
               '<circle cx="23" cy="34" r="6" fill="#fff"/><circle cx="23" cy="58" r="6" fill="#F59B3A"/><circle cx="23" cy="82" r="6" fill="#fff"/>'
               '<rect x="70" y="50" width="150" height="90" rx="8" fill="#fff" opacity="0.92"/>')
    gl_term = ('<rect x="40" y="40" width="200" height="110" rx="6" fill="#050A10"/><path d="M54 66 L70 78 L54 90" stroke="#2BFFA0" stroke-width="5" fill="none" stroke-linecap="round"/>'
               '<rect x="80" y="86" width="60" height="5" rx="2" fill="#2BFFA0"/><rect x="54" y="106" width="110" height="4" rx="2" fill="#2BFFA0" opacity="0.5"/>')
    gl_retro = ('<rect x="10" y="10" width="280" height="170" fill="#008080"/><rect x="50" y="34" width="150" height="98" fill="#c0c0c0" stroke="#fff" stroke-width="2"/>'
                '<rect x="54" y="38" width="142" height="14" fill="#000080"/><rect x="60" y="60" width="130" height="64" fill="#fff"/>'
                '<rect x="10" y="156" width="280" height="24" fill="#c0c0c0"/><rect x="16" y="160" width="52" height="16" fill="#c0c0c0" stroke="#000" stroke-width="1"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>
<filter id="b" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="80"/></filter>
<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2F7BFF"/><stop offset="1" stop-color="#7A4DFF"/></linearGradient>
<linearGradient id="g2" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E95420"/><stop offset="1" stop-color="#8E2A7A"/></linearGradient>
<linearGradient id="g3" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0E3A55"/><stop offset="1" stop-color="#04100C"/></linearGradient>
<linearGradient id="g4" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#008080"/><stop offset="1" stop-color="#006666"/></linearGradient>
<linearGradient id="t" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7CC4FF"/><stop offset="1" stop-color="#C58CFF"/></linearGradient>
<filter id="sh" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="14" stdDeviation="14" flood-opacity="0.5"/></filter>
</defs>
<rect width="100%" height="100%" fill="#0A1030"/>
<circle cx="150" cy="120" r="320" fill="#2F7BFF" opacity="0.35" filter="url(#b)"/>
<circle cx="1120" cy="520" r="340" fill="#8E2A7A" opacity="0.40" filter="url(#b)"/>
<circle cx="700" cy="60" r="260" fill="#18C6E8" opacity="0.25" filter="url(#b)"/>
<g stroke="#fff" stroke-opacity="0.05" stroke-width="2">{"".join(f'<path d="M0 {i*40} H1280"/>' for i in range(17))}</g>
<g filter="url(#sh)">
 {mini(800, 350, 0.85, "g3", "", gl_term)}
 {mini(1040, 410, 0.75, "g4", "", gl_retro)}
 {mini(990, 110, 0.9, "g2", "", gl_dock)}
 {mini(790, 80, 1.15, "g1", "", gl_bar)}
</g>
<text x="70" y="270" font-family="Inter, Segoe UI, Helvetica, Arial, sans-serif" font-weight="800" font-size="90" fill="url(#t)">ComputerWeb</text>
<text x="74" y="328" font-family="Inter, Segoe UI, Helvetica, Arial, sans-serif" font-weight="500" font-size="32" fill="#E8EEFF">Ordinateurs jouables pour Garry's Mod</text>
<g font-family="Inter, Segoe UI, Helvetica, Arial, sans-serif" font-weight="600" font-size="24" fill="#fff">
 <rect x="74" y="378" width="170" height="46" rx="23" fill="#fff" opacity="0.14"/><text x="104" y="409">5 thèmes</text>
 <rect x="258" y="378" width="200" height="46" rx="23" fill="#fff" opacity="0.14"/><text x="284" y="409">Navigateur</text>
 <rect x="472" y="378" width="140" height="46" rx="23" fill="#fff" opacity="0.14"/><text x="496" y="409">Radio</text>
 <rect x="74" y="438" width="240" height="46" rx="23" fill="#fff" opacity="0.14"/><text x="100" y="469">Jeux &amp; outils</text>
 <rect x="328" y="438" width="260" height="46" rx="23" fill="#fff" opacity="0.14"/><text x="354" y="469">DarkRP &amp; Sandbox</text>
</g>
<text x="74" y="590" font-family="Inter, Segoe UI, Helvetica, Arial, sans-serif" font-size="22" fill="#9FB0E0">Version 2.1 • par FilleuxStudio</text>
</svg>'''


def icon_svg():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2F7BFF"/><stop offset="1" stop-color="#8E3AE0"/></linearGradient>
<filter id="b" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="40"/></filter>
<filter id="sh" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-opacity="0.45"/></filter></defs>
<rect width="512" height="512" fill="url(#g)"/>
<circle cx="120" cy="90" r="190" fill="#18C6E8" opacity="0.45" filter="url(#b)"/>
<g filter="url(#sh)"><rect x="76" y="110" width="360" height="250" rx="26" fill="#12172A"/>
<rect x="96" y="130" width="320" height="210" rx="12" fill="#1B2A66"/>
<rect x="96" y="130" width="320" height="100" rx="12" fill="#fff" opacity="0.08"/>
<circle cx="256" cy="235" r="62" stroke="#fff" stroke-width="12" fill="none"/>
<ellipse cx="256" cy="235" rx="25" ry="62" stroke="#fff" stroke-width="9" fill="none"/>
<path d="M194 235 H318 M204 207 H308 M204 263 H308" stroke="#fff" stroke-width="9" fill="none"/>
<path d="M216 360 H296 L310 420 H202 Z" fill="#232A44"/><rect x="156" y="416" width="200" height="26" rx="13" fill="#2F3858"/></g>
</svg>'''


def render(pg, svg, path, w, h, jpg=False, scale=1):
    pg.set_viewport_size({"width": w, "height": h})
    pg.set_content(f'<body style="margin:0;background:transparent">{svg}</body>')
    pg.locator("svg").first.screenshot(path=path, omit_background=not jpg, type="jpeg" if jpg else "png",
                                       **({"quality": 88} if jpg else {}))


def main():
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_context(device_scale_factor=1).new_page()
        for n in ["nova", "terra", "cipher", "sandbox", "retro", "aurora", "graphite"]:
            render(pg, wall_svg(n), os.path.join(WALL, n + ".jpg"), 1280, 720, jpg=True)
        for cls, kind in {"computerWindows": "nova", "computerUbuntu": "terra", "computerKali": "cipher",
                          "computerGarrysMod": "sandbox", "computerRetro": "retro", "monitorMusic": "music", "monitorMusciTwo": "web"}.items():
            accent = {"terra": "#E95420"}.get(kind, "#fff")
            render(pg, screen_glyph(kind, accent), os.path.join(ENT, cls + ".png"), 256, 256)
        pg2 = b.new_context(device_scale_factor=2).new_page()
        render(pg2, cover_svg(), os.path.join(DOCS, "cover.jpg"), 1280, 640, jpg=True)
        render(pg2, icon_svg(), os.path.join(DOCS, "icon.jpg"), 512, 512, jpg=True)
        b.close()
    print("ok")


if __name__ == "__main__":
    main()
