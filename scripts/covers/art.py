"""Cover illustrations as SVG (360x500). Rendered to images by render.js.

Each entry: (id, category, svg_body). Keep shapes simple and flat with soft gradients.
"""
import math
import random

W, H = 360, 500


def rng(seed):
    return random.Random(seed)


def grad(id_, *stops, x2=0, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rgrad(id_, *stops, cx=0.5, cy=0.5, r=0.7):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


def bg(color):
    return f'<rect width="{W}" height="{H}" fill="{color}"/>'


def stars(seed, n=60, ymax=H, color="#fff", rmax=1.8):
    r = rng(seed)
    return "".join(
        f'<circle cx="{r.uniform(0, W):.1f}" cy="{r.uniform(0, ymax):.1f}" r="{r.uniform(0.5, rmax):.2f}" fill="{color}" opacity="{r.uniform(0.35, 1):.2f}"/>'
        for _ in range(n))


def wave_path(y, amp, wl, color, phase=0, opacity=1):
    pts = [f"M0 {H}", f"L0 {y}"]
    x = 0
    while x <= W + wl:
        pts.append(f"Q{x + wl / 4:.1f} {y - amp + (phase % 2) * 0:.1f} {x + wl / 2:.1f} {y}")
        pts.append(f"T{x + wl:.1f} {y}")
        x += wl
    pts.append(f"L{W} {H}Z")
    return f'<path d="{" ".join(pts)}" fill="{color}" opacity="{opacity}"/>'


def hills(y, color, seed, bumps=3, amp=40):
    r = rng(seed)
    d = f"M0 {H} L0 {y}"
    step = W / bumps
    for i in range(bumps):
        x0 = i * step
        d += f" C{x0 + step * 0.3:.0f} {y - amp * r.uniform(0.6, 1.2):.0f} {x0 + step * 0.7:.0f} {y - amp * r.uniform(-0.2, 0.6):.0f} {x0 + step:.0f} {y + r.uniform(-10, 10):.0f}"
    d += f" L{W} {H}Z"
    return f'<path d="{d}" fill="{color}"/>'


def pine(x, base, w, h, color):
    return f'<path d="M{x} {base} L{x + w / 2} {base - h} L{x + w} {base}Z" fill="{color}"/>'


def pine_tiered(x, base, w, h, color, trunk="#5b3b2a"):
    s = f'<rect x="{x - w * 0.06}" y="{base - h * 0.12}" width="{w * 0.12}" height="{h * 0.14}" fill="{trunk}"/>'
    for i in range(3):
        tw = w * (1 - i * 0.22)
        top = base - h * (0.45 + i * 0.27)
        bot = base - h * (0.08 + i * 0.27)
        s += f'<path d="M{x - tw / 2} {bot} L{x} {top - h * 0.08} L{x + tw / 2} {bot}Z" fill="{color}"/>'
    return s


def moon(cx, cy, r, color="#FFF3C4", glow=True):
    s = ""
    if glow:
        s += f'<circle cx="{cx}" cy="{cy}" r="{r * 2.2}" fill="{color}" opacity=".08"/><circle cx="{cx}" cy="{cy}" r="{r * 1.5}" fill="{color}" opacity=".1"/>'
    s += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>'
    s += f'<circle cx="{cx - r * .3}" cy="{cy - r * .2}" r="{r * .18}" fill="#000" opacity=".07"/><circle cx="{cx + r * .3}" cy="{cy + r * .3}" r="{r * .12}" fill="#000" opacity=".07"/>'
    return s


def cloud(x, y, s=1, color="#fff", op=1):
    return (f'<g transform="translate({x} {y}) scale({s})" fill="{color}" opacity="{op}">'
            '<ellipse cx="0" cy="0" rx="34" ry="16"/><circle cx="-14" cy="-10" r="16"/><circle cx="12" cy="-14" r="20"/></g>')


def birds(x, y, n=3, color="#7a4a4a", seed=1):
    r = rng(seed)
    s = ""
    for _ in range(n):
        bx, by = x + r.uniform(-30, 30), y + r.uniform(-15, 15)
        s += f'<path d="M{bx - 6} {by} q3 -4 6 0 q3 -4 6 0" stroke="{color}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    return s


def pattern(seed, n, fn):
    r = rng(seed)
    return "".join(fn(r, i) for i in range(n))


def grid_pattern(step_x, step_y, fn, offset_rows=True):
    out = []
    row = 0
    y = -step_y / 2
    while y < H + step_y:
        x = (step_x / 2 if (offset_rows and row % 2) else 0) - step_x / 2
        col = 0
        while x < W + step_x:
            out.append(fn(x, y, row, col))
            x += step_x
            col += 1
        y += step_y
        row += 1
    return "".join(out)


COVERS = []


def cover(id_, cat):
    def deco(fn):
        COVERS.append((id_, cat, fn))
        return fn
    return deco


# ---------------------------------------------------------------- Landscapes
@cover("dunes", "landscapes")
def _():
    return (f'<defs>{grad("g", (0, "#FDE8CF"), (1, "#F7BE92"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
            f'<circle cx="180" cy="270" r="70" fill="#FFF4E4"/>' + birds(110, 150, 3, "#8a5a4a", 3)
            + hills(300, "#EE9A74", 1, 2, 50) + hills(350, "#D46F5F", 2, 3, 40) + hills(410, "#A84E5A", 3, 2, 35)
            + hills(460, "#7E3D52", 4, 3, 20))


@cover("night-peaks", "landscapes")
def _():
    return (f'<defs>{grad("g", (0, "#0F1636"), (1, "#26407F"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
            + stars(11, 80, 330) + moon(250, 120, 34)
            + f'<path d="M0 380 L110 290 L190 350 L280 270 L360 330 L360 500 L0 500Z" fill="#2D4185"/>'
            + '<path d="M280 270 L300 286 L262 288Z" fill="#fff" opacity=".9"/><path d="M110 290 L124 302 L96 303Z" fill="#fff" opacity=".8"/>'
            + '<path d="M0 440 L150 350 L250 420 L360 380 L360 500 L0 500Z" fill="#17224D"/>')


@cover("sea-sun", "landscapes")
def _():
    s = bg("#F4EEE3") + '<circle cx="235" cy="150" r="38" fill="#E8654A"/>'
    cols = ["#A9D3D2", "#7DBBC0", "#5AA0AD", "#3E8496", "#2C6A80", "#22566C"]
    for i, c in enumerate(cols):
        s += wave_path(260 + i * 40, 12, 72, c)
    return s


@cover("pine-forest", "landscapes")
def _():
    r = rng(5)
    s = f'<defs>{grad("g", (0, "#EDF3EA"), (1, "#CFE2D2"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += '<circle cx="110" cy="120" r="36" fill="#FFF8E4"/>'
    for layer, (base, col) in enumerate([(330, "#9CC2A6"), (400, "#6E9F80"), (470, "#457A5D"), (520, "#2C5A43")]):
        x = -20
        while x < W + 20:
            w = r.uniform(26, 44)
            s += pine(x, base, w, w * r.uniform(2.2, 3.2), col)
            x += w * 0.55
        s += f'<rect x="0" y="{base - 1}" width="{W}" height="{H}" fill="{col}"/>'
    return s


@cover("desert", "landscapes")
def _():
    return (bg("#FCEEDD") + '<circle cx="230" cy="170" r="44" fill="#FFF6EA"/>'
            + hills(300, "#EFC6A0", 7, 2, 40) + hills(350, "#E0A479", 8, 2, 45) + hills(410, "#C27F57", 9, 3, 35)
            + hills(460, "#965A3C", 10, 2, 25))


@cover("sea-sunset", "landscapes")
def _():
    s = f'<defs>{grad("g", (0, "#3A2A63"), (0.55, "#C9476B"), (1, "#F7A06B"))}</defs><rect width="{W}" height="340" fill="url(#g)"/>'
    s += stars(21, 30, 160, rmax=1.3)
    s += '<circle cx="180" cy="340" r="58" fill="#FFD9A0"/>'
    s += '<rect y="340" width="360" height="160" fill="#2B2552"/>'
    for i in range(7):
        w = 110 - i * 13
        s += f'<rect x="{180 - w / 2}" y="{352 + i * 14}" width="{w}" height="4" rx="2" fill="#FFD9A0" opacity="{0.8 - i * 0.08:.2f}"/>'
    return s


@cover("planet", "landscapes")
def _():
    return (f'<defs>{rgrad("g", (0, "#7B3FC4"), (1, "#1C0B3A"), cx=0.4, cy=0.35, r=0.9)}'
            f'{grad("p", (0, "#F7B7A3"), (1, "#C96B8A"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
            + stars(31, 90)
            + '<circle cx="190" cy="270" r="62" fill="url(#p)"/>'
            + '<path d="M150 255 Q190 245 232 262" stroke="#fff" stroke-opacity=".25" stroke-width="7" fill="none"/>'
            + '<ellipse cx="190" cy="275" rx="110" ry="24" fill="none" stroke="#FCE3D8" stroke-width="7" transform="rotate(-12 190 275)"/>'
            + '<path d="M126 262 A62 62 0 0 0 252 262" fill="url(#p)" transform="rotate(-12 190 275)" opacity="0"/>'
            + '<circle cx="80" cy="110" r="9" fill="#F7D57A"/>')


@cover("aurora", "landscapes")
def _():
    return (f'<defs>{grad("g", (0, "#071322"), (1, "#0F2A3C"))}<filter id="b"><feGaussianBlur stdDeviation="14"/></filter>'
            f'{grad("a", (0, "#5FF2B0"), (1, "#2BB3A8"), x2=1, y2=0)}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
            + stars(41, 70)
            + '<path d="M-20 230 C60 150 120 260 200 190 S330 150 380 200 L380 240 C320 200 260 260 190 240 S60 220 -20 280Z" fill="url(#a)" filter="url(#b)" opacity=".85"/>'
            + '<path d="M-20 180 C80 120 160 210 240 150 S340 120 380 140" stroke="#9BF7D0" stroke-width="10" fill="none" filter="url(#b)" opacity=".6"/>'
            + '<path d="M0 420 L50 380 L90 410 L150 350 L210 410 L260 370 L300 400 L360 360 L360 500 L0 500Z" fill="#050B12"/>')


@cover("moon-phases", "landscapes")
def _():
    s = f'<defs>{grad("g", (0, "#1E2453"), (1, "#2B2F66"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + stars(51, 50)
    ys = [130, 190, 250, 310, 370]
    for i, y in enumerate(ys):
        s += f'<circle cx="180" cy="{y}" r="20" fill="#FFF0C9"/>'
        off = [-14, -26, 0, 26, 14][i]
        if i != 2:
            s += f'<circle cx="{180 + off}" cy="{y}" r="20" fill="#1F2558"/>'
    return s


@cover("lake", "landscapes")
def _():
    s = f'<defs>{grad("g", (0, "#F8E6D8"), (1, "#DCE8F1"))}{grad("w", (0, "#B9D2E6"), (1, "#8FB3D2"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += '<circle cx="240" cy="130" r="30" fill="#FFF5E8"/>' + birds(120, 110, 3, "#6a6a8a", 9)
    mtn = '<path d="M20 290 L120 160 L170 220 L230 140 L340 290Z" fill="#8F96C8"/><path d="M120 160 L140 186 L126 182 L112 192 L100 186Z" fill="#fff"/><path d="M230 140 L254 172 L238 166 L222 178 L210 168Z" fill="#fff"/>'
    s += mtn
    s += f'<rect y="290" width="360" height="210" fill="url(#w)"/>'
    s += f'<g transform="translate(0 580) scale(1 -1)" opacity=".35">{mtn}</g>'
    for x in [0, 30, 300, 330]:
        s += pine(x, 292, 34, 90, "#2F6B55")
        s += f'<g transform="translate(0 584) scale(1 -1)" opacity=".3">{pine(x, 292, 34, 90, "#2F6B55")}</g>'
    s += '<path d="M168 360 h30 l-5 7 h-20z" fill="#C8553D"/><rect x="182" y="345" width="2" height="15" fill="#5a4a4a"/>'
    for i in range(5):
        s += f'<rect x="{60 + i * 50}" y="{320 + i * 25}" width="40" height="2" rx="1" fill="#fff" opacity=".5"/>'
    return s


# ---------------------------------------------------------------- Travel
@cover("compass", "travel")
def _():
    s = bg("#F2E4C4")
    r = rng(61)
    for _ in range(8):
        x, y = r.uniform(0, W), r.uniform(0, H)
        s += f'<path d="M{x:.0f} {y:.0f} q30 -20 60 0 t60 0" stroke="#C9AE7E" stroke-width="2" fill="none" opacity=".6"/>'
    s += '<path d="M60 430 C120 380 80 330 140 300" stroke="#C0453A" stroke-width="3" stroke-dasharray="8 7" fill="none"/>'
    s += '<path d="M290 60 l10 18 l-20 0z M300 90 l8 14 l-16 0z" fill="#B49865" opacity=".7"/>'
    cx, cy = 180, 240
    s += f'<circle cx="{cx}" cy="{cy}" r="96" fill="#D8A84A"/><circle cx="{cx}" cy="{cy}" r="86" fill="#F7EEDC"/><circle cx="{cx}" cy="{cy}" r="86" fill="none" stroke="#B88A33" stroke-width="2"/>'
    s += f'<circle cx="{cx}" cy="{cy - 100}" r="10" fill="none" stroke="#D8A84A" stroke-width="6"/>'
    for a in range(0, 360, 15):
        L = 12 if a % 90 == 0 else 6
        x1 = cx + math.cos(math.radians(a)) * 82
        y1 = cy + math.sin(math.radians(a)) * 82
        x2 = cx + math.cos(math.radians(a)) * (82 - L)
        y2 = cy + math.sin(math.radians(a)) * (82 - L)
        s += f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#8C6A2E" stroke-width="1.5"/>'
    s += f'<path d="M{cx} {cy - 64} L{cx + 14} {cy} L{cx} {cy + 64} L{cx - 14} {cy}Z" fill="#2B3E6B"/><path d="M{cx} {cy - 64} L{cx + 14} {cy} L{cx - 14} {cy}Z" fill="#D2483B"/>'
    s += f'<path d="M{cx - 64} {cy} L{cx} {cy - 10} L{cx + 64} {cy} L{cx} {cy + 10}Z" fill="#2B3E6B" opacity=".5"/><circle cx="{cx}" cy="{cy}" r="6" fill="#D8A84A"/>'
    return s


@cover("camper", "travel")
def _():
    s = bg("#BFE6F3") + '<circle cx="270" cy="90" r="34" fill="#FFE59A"/>' + cloud(90, 110, 1) + birds(200, 150, 2, "#5a6a7a", 4)
    s += '<rect y="250" width="360" height="40" fill="#3FA7C9"/><rect y="288" width="360" height="212" fill="#F4D8A6"/>'
    s += '<g transform="translate(60 250)">'
    s += '<rect x="20" y="-8" width="200" height="10" rx="5" fill="#F5A54A"/>'
    s += '<rect x="0" y="0" width="240" height="120" rx="34" fill="#F8F3E8"/>'
    s += '<path d="M0 70 h240 v16 a34 34 0 0 1 -34 34 h-172 a34 34 0 0 1 -34 -34z" fill="#E8663D"/>'
    s += '<rect x="22" y="18" width="52" height="36" rx="10" fill="#7CC6E0"/><rect x="88" y="18" width="52" height="36" rx="8" fill="#7CC6E0"/><rect x="154" y="18" width="62" height="36" rx="8" fill="#7CC6E0"/>'
    s += '<circle cx="120" cy="78" r="9" fill="#F8F3E8"/>'
    s += '<circle cx="56" cy="122" r="22" fill="#2E2E36"/><circle cx="56" cy="122" r="9" fill="#C9C9CF"/><circle cx="186" cy="122" r="22" fill="#2E2E36"/><circle cx="186" cy="122" r="9" fill="#C9C9CF"/>'
    s += '</g>'
    s += '<path d="M40 330 q5 -10 10 0 M300 470 q5 -10 10 0 M250 320 q4 -8 8 0" stroke="#7BA05B" stroke-width="2" fill="none"/>'
    return s


@cover("postcards", "travel")
def _():
    s = bg("#5D93A8")
    s += '<g transform="rotate(-10 140 170)"><rect x="50" y="90" width="190" height="130" rx="4" fill="#fff"/><rect x="60" y="100" width="170" height="110" fill="#F7A86B"/><circle cx="145" cy="170" r="26" fill="#FFE1A8"/><rect x="60" y="175" width="170" height="35" fill="#3E6E9C"/><path d="M90 175 q8 -40 4 -60 M94 120 q20 -6 26 4 M94 120 q-18 -8 -24 2" stroke="#2C3E33" stroke-width="4" fill="none"/></g>'
    s += '<g transform="rotate(8 220 330)"><rect x="110" y="250" width="210" height="150" rx="4" fill="#FBF6EC"/><rect x="122" y="262" width="110" height="126" fill="#BFE0EE"/><path d="M122 388 L160 320 L190 360 L210 330 L232 388Z" fill="#6E8FB3"/><path d="M122 388 Q170 370 232 388Z" fill="#7BAA6A"/>'
    s += '<rect x="262" y="266" width="42" height="50" fill="#E25A4A"/><rect x="266" y="270" width="34" height="42" fill="#FBF6EC" opacity=".25"/><circle cx="270" cy="300" r="14" fill="none" stroke="#3a3a3a" stroke-width="1.5" opacity=".6"/>'
    s += '<line x1="245" y1="340" x2="305" y2="340" stroke="#B9AE9C" stroke-width="2"/><line x1="245" y1="356" x2="305" y2="356" stroke="#B9AE9C" stroke-width="2"/><line x1="245" y1="372" x2="290" y2="372" stroke="#B9AE9C" stroke-width="2"/></g>'
    s += '<g transform="rotate(-4 120 430)"><rect x="40" y="400" width="140" height="90" rx="4" fill="#fff"/><rect x="48" y="408" width="124" height="74" fill="#F2C94C"/><path d="M48 482 L90 440 L120 470 L140 450 L172 482Z" fill="#E07A3E"/></g>'
    return s


@cover("suitcase", "travel")
def _():
    s = bg("#F2C14E")
    s += '<rect x="140" y="110" width="80" height="40" rx="14" fill="none" stroke="#7A4E2D" stroke-width="12"/>'
    s += '<rect x="70" y="140" width="220" height="260" rx="26" fill="#2A7F84"/>'
    for x in [120, 240]:
        s += f'<rect x="{x - 8}" y="140" width="16" height="260" fill="#7A4E2D"/>'
    s += '<circle cx="180" cy="220" r="26" fill="#F7EEDC"/><text x="180" y="227" font-family="Georgia" font-size="16" text-anchor="middle" fill="#2A7F84">Roma</text>'
    s += '<rect x="150" y="285" width="70" height="40" rx="6" fill="#E8663D" transform="rotate(-8 185 305)"/>'
    s += '<path d="M160 350 l14 -24 l14 24z" fill="#F7EEDC"/><circle cx="210" cy="355" r="12" fill="#F2C14E"/>'
    s += '<circle cx="100" cy="415" r="12" fill="#3a3a3a"/><circle cx="260" cy="415" r="12" fill="#3a3a3a"/>'
    return s


@cover("balloon", "travel")
def _():
    s = f'<defs>{grad("g", (0, "#BFE3F5"), (1, "#FBE6D6"))}<clipPath id="bc"><circle cx="180" cy="200" r="90"/></clipPath></defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += cloud(70, 120, 1.1) + cloud(290, 330, 0.9) + cloud(80, 420, 0.8, op=.8)
    s += '<g clip-path="url(#bc)">'
    cols = ["#E8553D", "#F7C548", "#2A9D8F", "#F7C548", "#E8553D", "#F4EFE6", "#2A9D8F"]
    for i, c in enumerate(cols):
        s += f'<rect x="{90 + i * 26}" y="100" width="26" height="200" fill="{c}"/>'
    s += '</g>'
    s += '<path d="M110 250 Q180 330 250 250 L205 320 L155 320Z" fill="#D2483B" opacity="0"/>'
    s += '<path d="M118 245 L160 330 M242 245 L200 330" stroke="#6b4a33" stroke-width="2"/>'
    s += '<rect x="158" y="330" width="44" height="34" rx="4" fill="#9A6B43"/><rect x="158" y="330" width="44" height="8" fill="#7A4E2D"/>'
    return s


@cover("paper-plane", "travel")
def _():
    s = bg("#8EC8EA") + cloud(80, 380, 1.2) + cloud(280, 140, 0.9) + cloud(300, 430, 0.7, op=.8)
    s += '<path d="M40 420 C110 380 120 300 200 290" stroke="#fff" stroke-width="3" stroke-dasharray="10 8" fill="none" opacity=".9"/>'
    s += '<g transform="translate(200 200) rotate(-18)"><path d="M0 60 L120 0 L40 80Z" fill="#fff"/><path d="M40 80 L120 0 L55 100Z" fill="#DCE9F2"/><path d="M40 80 L55 100 L50 76Z" fill="#B9CFDF"/><path d="M0 60 L40 80 L120 0Z" fill="#F4F8FB"/></g>'
    return s


# ---------------------------------------------------------------- City
@cover("rooftops", "city")
def _():
    r = rng(71)
    s = f'<defs>{grad("g", (0, "#2D2A5B"), (1, "#8A5E8C"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + stars(72, 40, 250)
    s += '<path d="M280 90 a26 26 0 1 0 22 40 a20 20 0 1 1 -22 -40z" fill="#FFF0C4"/>'
    x = 0
    while x < W:
        w = r.uniform(60, 90)
        h = r.uniform(110, 200)
        top = H - h
        col = r.choice(["#2A2244", "#352A55", "#3E2F5E"])
        s += f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{col}"/><path d="M{x - 6} {top} L{x + w / 2} {top - 40} L{x + w + 6} {top}Z" fill="{col}"/>'
        s += f'<rect x="{x + w * 0.7}" y="{top - 40}" width="10" height="26" fill="{col}"/>'
        for wx in [x + w * 0.2, x + w * 0.55]:
            for wy in range(int(top + 20), H - 20, 40):
                lit = r.random() < 0.55
                s += f'<rect x="{wx:.0f}" y="{wy}" width="14" height="18" rx="2" fill="{"#FFD27A" if lit else "#1E1835"}"/>'
        x += w + 4
    return s


@cover("skyline", "city")
def _():
    r = rng(81)
    s = f'<defs>{grad("g", (0, "#0B1430"), (1, "#1C2B5A"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + stars(82, 50, 220) + moon(80, 90, 18, glow=True)
    x = -5
    while x < W:
        w = r.uniform(30, 60)
        h = r.uniform(150, 330)
        top = H - h
        s += f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{r.choice(["#14204A", "#1A2858", "#101A3E"])}"/>'
        for wy in range(int(top + 8), H, 12):
            for wx in range(int(x + 5), int(x + w - 5), 9):
                if r.random() < 0.35:
                    s += f'<rect x="{wx}" y="{wy}" width="4" height="5" fill="#FFD77A" opacity="{r.uniform(.6, 1):.2f}"/>'
        x += w + 2
    return s


@cover("canal-houses", "city")
def _():
    r = rng(91)
    s = bg("#BFE3F3") + cloud(80, 80, 0.9) + cloud(280, 60, 0.7)
    cols = ["#E8663D", "#F2C14E", "#2A9D8F", "#E07A9A", "#5B8DEF", "#F4A261", "#7BB662", "#C2725A"]
    x = 0
    i = 0
    while x < W:
        w = 46
        h = r.uniform(170, 230)
        top = 330 - h
        c = cols[i % len(cols)]
        s += f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{c}"/>'
        s += f'<path d="M{x} {top} L{x + w / 2} {top - 26} L{x + w} {top}Z" fill="{c}"/>'
        for wy in range(int(top + 14), 315, 30):
            s += f'<rect x="{x + 8}" y="{wy}" width="11" height="16" fill="#FDF7EC"/><rect x="{x + 27}" y="{wy}" width="11" height="16" fill="#FDF7EC"/>'
        x += w + 1
        i += 1
    s += '<rect y="330" width="360" height="170" fill="#3D7FA6"/>'
    for k in range(10):
        s += f'<rect x="{r.uniform(0, 330):.0f}" y="{345 + k * 15}" width="{r.uniform(20, 60):.0f}" height="3" rx="1.5" fill="#fff" opacity=".35"/>'
    s += '<path d="M200 410 h70 l-10 14 h-50z" fill="#C8553D"/>'
    return s


@cover("tram", "city")
def _():
    s = bg("#C5E4F2") + cloud(80, 90, 0.8)
    s += '<rect x="0" y="150" width="120" height="200" fill="#F2B8A2"/><rect x="120" y="120" width="110" height="230" fill="#F6DFA4"/><rect x="230" y="160" width="130" height="190" fill="#A9CBB7"/>'
    for bx, by, bw in [(0, 150, 120), (120, 120, 110), (230, 160, 130)]:
        for wx in range(bx + 14, bx + bw - 14, 26):
            for wy in range(by + 16, 330, 36):
                s += f'<rect x="{wx}" y="{wy}" width="14" height="20" fill="#5C6F84" opacity=".7"/>'
    s += '<line x1="0" y1="200" x2="360" y2="150" stroke="#333" stroke-width="1.5"/>'
    s += '<rect y="350" width="360" height="150" fill="#B9B2A8"/><line x1="0" y1="470" x2="360" y2="410" stroke="#7d756b" stroke-width="3"/>'
    s += '<g transform="rotate(-9 180 360)"><rect x="70" y="290" width="230" height="110" rx="16" fill="#F2C11C"/><rect x="70" y="370" width="230" height="20" fill="#E5A50E"/>'
    for wx in [86, 136, 186, 236]:
        s += f'<rect x="{wx}" y="306" width="40" height="44" rx="6" fill="#DDF0F7"/>'
    s += '<rect x="70" y="352" width="230" height="6" fill="#fff"/><line x1="180" y1="290" x2="200" y2="245" stroke="#333" stroke-width="3"/>'
    s += '<circle cx="110" cy="402" r="12" fill="#333"/><circle cx="260" cy="402" r="12" fill="#333"/></g>'
    return s


# ---------------------------------------------------------------- Cooking
@cover("coffee", "cooking")
def _():
    s = bg("#F5CDAA")
    r = rng(101)
    for _ in range(18):
        x, y, a = r.uniform(20, 340), r.uniform(20, 480), r.uniform(0, 180)
        if 90 < x < 270 and 170 < y < 380:
            continue
        s += f'<g transform="translate({x:.0f} {y:.0f}) rotate({a:.0f})"><ellipse rx="9" ry="13" fill="#5A3A25"/><path d="M0 -11 q-4 11 0 22" stroke="#F5CDAA" stroke-width="2" fill="none"/></g>'
    s += '<ellipse cx="180" cy="340" rx="110" ry="24" fill="#FBF6EE"/><ellipse cx="180" cy="336" rx="80" ry="12" fill="#EADFCF"/>'
    s += '<path d="M110 250 h140 v40 a70 52 0 0 1 -140 0z" fill="#FBF6EE"/><path d="M110 270 h140 v8 h-140z M112 290 h136 v6 h-136z" fill="#D9534F"/>'
    s += '<ellipse cx="180" cy="250" rx="70" ry="12" fill="#6B4026"/>'
    s += '<path d="M250 262 a22 22 0 0 1 0 44" stroke="#FBF6EE" stroke-width="10" fill="none"/>'
    for x in [160, 180, 200]:
        s += f'<path d="M{x} 225 q-10 -15 0 -30 t0 -30" stroke="#FBF6EE" stroke-width="3" fill="none" opacity=".8" stroke-linecap="round"/>'
    return s


@cover("lemons", "cooking")
def _():
    r = rng(111)

    def lemon(x, y, row, col):
        a = r.uniform(-40, 40)
        return (f'<g transform="translate({x:.0f} {y:.0f}) rotate({a:.0f})"><ellipse rx="26" ry="19" fill="#F7D33F"/><ellipse cx="25" cy="0" rx="6" ry="4" fill="#F7D33F"/>'
                f'<ellipse cx="-8" cy="-7" rx="8" ry="3" fill="#fff" opacity=".4"/><path d="M-26 0 q-10 -18 -26 -14 q8 14 26 14" fill="#4BA35B"/></g>')
    return bg("#2F5D8A") + grid_pattern(110, 90, lemon)


@cover("utensils", "cooking")
def _():
    s = bg("#F4F1EB")
    for y in range(0, 400, 30):
        s += f'<line x1="0" y1="{y}" x2="360" y2="{y}" stroke="#E2DDD3" stroke-width="2"/>'
    for x in range(0, 360, 50):
        for y in range(0, 400, 60):
            s += f'<line x1="{x + (25 if (y // 30) % 2 else 0)}" y1="{y}" x2="{x + (25 if (y // 30) % 2 else 0)}" y2="{y + 30}" stroke="#E2DDD3" stroke-width="2"/>'
    s += '<rect x="40" y="110" width="280" height="8" rx="4" fill="#8E8E95"/><circle cx="40" cy="114" r="8" fill="#6E6E75"/><circle cx="320" cy="114" r="8" fill="#6E6E75"/>'
    s += '<path d="M90 118 v120" stroke="#B5813F" stroke-width="7" stroke-linecap="round"/><ellipse cx="90" cy="262" rx="18" ry="28" fill="#C99252"/>'
    s += '<path d="M150 118 v90" stroke="#3E8E7E" stroke-width="7" stroke-linecap="round"/>' + "".join(
        f'<path d="M150 205 C{150 + d} 250 {150 + d} 290 150 305 C{150 - d} 290 {150 - d} 250 150 205" stroke="#9A9AA2" stroke-width="2" fill="none"/>' for d in [8, 18, 28])
    s += '<path d="M210 118 v110" stroke="#D2483B" stroke-width="7" stroke-linecap="round"/><rect x="194" y="226" width="32" height="56" rx="6" fill="#3a3a40"/><line x1="203" y1="236" x2="203" y2="272" stroke="#F4F1EB" stroke-width="3"/><line x1="217" y1="236" x2="217" y2="272" stroke="#F4F1EB" stroke-width="3"/>'
    s += '<path d="M270 118 v130" stroke="#9A9AA2" stroke-width="6" stroke-linecap="round"/><path d="M248 250 a22 22 0 0 0 44 0z" fill="#9A9AA2"/>'
    s += '<rect y="400" width="360" height="100" fill="#B98552"/><rect y="400" width="360" height="12" fill="#A0703F"/>'
    return s


@cover("egg-pan", "cooking")
def _():
    s = bg("#BFE6D8")
    for x in range(0, 360, 40):
        s += f'<rect x="{x}" y="0" width="20" height="500" fill="#fff" opacity=".35"/>'
    for y in range(0, 500, 40):
        s += f'<rect x="0" y="{y}" width="360" height="20" fill="#fff" opacity=".35"/>'
    s += '<path d="M250 330 L330 440" stroke="#2A2A2E" stroke-width="22" stroke-linecap="round"/>'
    s += '<circle cx="170" cy="240" r="110" fill="#2A2A2E"/><circle cx="170" cy="240" r="92" fill="#3A3A40"/>'
    s += '<path d="M120 200 C110 150 200 140 220 190 C260 220 230 300 180 290 C120 300 90 260 120 200Z" fill="#FBFBF7"/>'
    s += '<circle cx="172" cy="226" r="28" fill="#F6B53A"/><circle cx="164" cy="218" r="8" fill="#fff" opacity=".5"/>'
    return s


@cover("teapot", "cooking")
def _():
    s = bg("#E7F2E1")
    r = rng(131)
    for _ in range(9):
        x, y, a = r.uniform(20, 340), r.uniform(20, 200), r.uniform(0, 360)
        s += f'<path d="M{x:.0f} {y:.0f} q8 -12 16 0 q-8 12 -16 0z" fill="#7FB069" transform="rotate({a:.0f} {x:.0f} {y:.0f})"/>'
    s += '<rect y="380" width="360" height="120" fill="#9FCB8B"/>'
    s += '<path d="M250 300 q50 -30 60 -60" stroke="#E8735A" stroke-width="14" stroke-linecap="round" fill="none"/>'
    s += '<path d="M100 290 q-40 -10 -30 40 q10 20 34 14" stroke="#E8735A" stroke-width="12" fill="none"/>'
    s += '<ellipse cx="180" cy="320" rx="90" ry="76" fill="#E8735A"/><rect x="95" y="378" width="170" height="14" rx="7" fill="#C95A43"/>'
    s += '<path d="M120 300 h120" stroke="#FBEFE0" stroke-width="10"/>' + "".join(f'<circle cx="{x}" cy="300" r="3" fill="#E8735A"/>' for x in range(130, 240, 14))
    s += '<ellipse cx="180" cy="250" rx="40" ry="10" fill="#C95A43"/><circle cx="180" cy="236" r="9" fill="#C95A43"/>'
    s += '<path d="M275 380 h44 v10 a22 18 0 0 1 -44 0z" fill="#FBEFE0"/><ellipse cx="297" cy="392" rx="32" ry="6" fill="#FBEFE0"/>'
    return s


@cover("avocados", "cooking")
def _():
    def avo(x, y, row, col):
        a = 15 if (row + col) % 2 else -15
        return (f'<g transform="translate({x:.0f} {y:.0f}) rotate({a})"><path d="M0 -34 C22 -34 28 0 26 14 C24 34 -24 34 -26 14 C-28 0 -22 -34 0 -34Z" fill="#3E6B2E"/>'
                f'<path d="M0 -27 C16 -27 21 0 19 12 C17 27 -17 27 -19 12 C-21 0 -16 -27 0 -27Z" fill="#CFE38E"/><circle cx="0" cy="10" r="11" fill="#8A5A34"/></g>')
    return bg("#F6D4CA") + grid_pattern(80, 86, avo)


@cover("strawberries", "cooking")
def _():
    s = bg("#DDEEF5")
    r = rng(151)
    for _ in range(7):
        x, y = r.uniform(30, 330), r.uniform(30, 220)
        s += f'<g transform="translate({x:.0f} {y:.0f})">' + "".join(
            f'<circle cx="{math.cos(a) * 6:.1f}" cy="{math.sin(a) * 6:.1f}" r="5" fill="#fff"/>' for a in [i * 1.2566 for i in range(5)]) + '<circle r="3.5" fill="#F2C14E"/></g>'
    s += '<path d="M70 290 h220 a110 90 0 0 1 -220 0z" fill="#fff"/><path d="M80 320 h200 M92 345 h176" stroke="#3E6CB0" stroke-width="7"/>'

    def berry(x, y, s_=1.0):
        out = f'<g transform="translate({x} {y}) scale({s_})"><path d="M0 22 C-22 10 -20 -12 0 -10 C20 -12 22 10 0 22Z" fill="#E23B3B"/>'
        out += "".join(f'<ellipse cx="{dx}" cy="{dy}" rx="1.2" ry="2" fill="#FBE29A"/>' for dx, dy in [(-8, -2), (0, 4), (8, -2), (-4, 10), (4, 10), (0, -5)])
        out += '<path d="M-10 -10 l5 -6 l5 4 l5 -6 l5 6 l5 -4 l5 6z" fill="#3E9B57" transform="translate(-5 0)"/></g>'
        return out
    for (x, y) in [(110, 280), (140, 268), (175, 262), (210, 266), (245, 280), (128, 252), (160, 245), (195, 242), (228, 254)]:
        s += berry(x, y, 1.1)
    s += berry(60, 430, 1.3) + berry(300, 420, 1.2) + berry(260, 460, 1.0)
    return s


@cover("bread", "cooking")
def _():
    s = bg("#DCE8F2") + '<rect y="400" width="360" height="100" fill="#FBF7EF"/><rect y="412" width="360" height="6" fill="#3E6CB0"/><rect y="424" width="360" height="3" fill="#3E6CB0"/>'
    for a in [30, -30]:
        s += f'<g transform="translate(180 260) rotate({a})"><rect x="-26" y="-150" width="52" height="300" rx="26" fill="#D8A15A"/>'
        s += "".join(f'<path d="M-14 {y} q14 -12 28 0" stroke="#F3D49A" stroke-width="5" fill="none" stroke-linecap="round"/>' for y in range(-110, 120, 40)) + '</g>'
    s += '<g transform="translate(180 390)"><path d="M-70 0 C-60 -50 60 -50 70 0 C40 10 -40 10 -70 0Z" fill="#E2A24E"/><path d="M-30 -32 C-20 -10 20 -10 30 -32" stroke="#C47F2E" stroke-width="4" fill="none"/><path d="M-55 -15 q15 10 25 -10 M55 -15 q-15 10 -25 -10" stroke="#C47F2E" stroke-width="4" fill="none"/></g>'
    return s


# ---------------------------------------------------------------- Study & work
@cover("lightbulb", "study")
def _():
    s = f'<defs>{rgrad("g", (0, "#F7D86B"), (1, "#F7D86B00"), r=0.5)}</defs>' + bg("#1E2E5C")
    s += '<circle cx="180" cy="210" r="120" fill="url(#g)" opacity=".35"/>'
    for a in range(-150, -20, 26):
        x1 = 180 + math.cos(math.radians(a)) * 92
        y1 = 210 + math.sin(math.radians(a)) * 92
        x2 = 180 + math.cos(math.radians(a)) * 120
        y2 = 210 + math.sin(math.radians(a)) * 120
        s += f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="#F7D86B" stroke-width="7" stroke-linecap="round"/>'
    s += '<path d="M180 140 a66 66 0 0 1 40 118 v24 h-80 v-24 a66 66 0 0 1 40 -118z" fill="#F7D86B"/>'
    s += '<path d="M168 280 v-40 l12 -14 l12 14 v40" stroke="#E0A93A" stroke-width="4" fill="none"/>'
    s += '<rect x="142" y="282" width="76" height="14" rx="5" fill="#B9BDC8"/><rect x="146" y="298" width="68" height="14" rx="5" fill="#9AA0AE"/><path d="M160 314 h40 l-8 14 h-24z" fill="#6E7484"/>'
    s += '<ellipse cx="160" cy="180" rx="10" ry="18" fill="#fff" opacity=".45" transform="rotate(20 160 180)"/>'
    return s


@cover("pencils", "study")
def _():
    s = bg("#F5F0E4")
    cols = ["#E8553D", "#F29E38", "#F2C94C", "#7BB662", "#2A9D8F", "#3E6CB0", "#6C4FA3", "#2E2E36"]
    for i, c in enumerate(cols):
        x = 52 + i * 34
        top = 120 + (i * 37 % 5) * 22
        s += f'<rect x="{x}" y="{top}" width="26" height="{460 - top}" fill="{c}"/><rect x="{x + 9}" y="{top}" width="8" height="{460 - top}" fill="#fff" opacity=".18"/>'
        s += f'<path d="M{x} {top} L{x + 13} {top - 40} L{x + 26} {top}Z" fill="#F4D3A3"/><path d="M{x + 8} {top - 25} L{x + 13} {top - 40} L{x + 18} {top - 25}Z" fill="{c}"/>'
    return s


@cover("bookshelf", "study")
def _():
    r = rng(171)
    s = bg("#F6EFE1")
    for shelf_y in [230, 410]:
        s += f'<rect x="20" y="{shelf_y}" width="320" height="12" fill="#A9774A"/>'
        x = 36
        while x < 300:
            w = r.uniform(16, 26)
            h = r.uniform(80, 130)
            c = r.choice(["#E8553D", "#2A9D8F", "#3E6CB0", "#F2C14E", "#6C4FA3", "#7BB662", "#E07A9A", "#264653"])
            if r.random() < 0.12:
                s += f'<rect x="{x}" y="{shelf_y - h * 0.85}" width="{w}" height="{h * .85}" fill="{c}" transform="rotate(14 {x + w} {shelf_y})"/>'
                x += w + 18
                continue
            s += f'<rect x="{x:.0f}" y="{shelf_y - h:.0f}" width="{w:.0f}" height="{h:.0f}" fill="{c}"/><rect x="{x:.0f}" y="{shelf_y - h + 12:.0f}" width="{w:.0f}" height="4" fill="#fff" opacity=".4"/>'
            x += w + 2
        if shelf_y == 230:
            s += '<path d="M300 230 h30 l-4 -34 h-22z" fill="#C2725A"/>' + "".join(
                f'<ellipse cx="{315 + dx}" cy="{180 + dy}" rx="8" ry="18" fill="#4F9A5C" transform="rotate({dx * 3} {315 + dx} {196})"/>' for dx, dy in [(-10, 0), (0, -10), (10, 0)])
    return s


@cover("rocket", "study")
def _():
    s = f'<defs>{grad("g", (0, "#2C2A6B"), (0.7, "#7B4FA3"), (1, "#C985B8"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + stars(181, 50, 350)
    s += '<circle cx="80" cy="120" r="18" fill="#F4A261"/><ellipse cx="80" cy="120" rx="30" ry="6" fill="none" stroke="#F7D9B8" stroke-width="3" transform="rotate(-20 80 120)"/><circle cx="290" cy="90" r="6" fill="#F2C14E"/>'
    s += '<path d="M168 330 q12 70 12 90 q0 -20 12 -90z" fill="#F7A440"/><path d="M174 330 q6 40 6 60 q0 -20 6 -60z" fill="#FFE07A"/>'
    s += '<path d="M180 120 C220 160 220 260 210 320 h-60 C140 260 140 160 180 120Z" fill="#F7F4EE"/>'
    s += '<path d="M180 120 C196 136 205 152 210 170 h-60 C155 152 164 136 180 120Z" fill="#E23B3B"/>'
    s += '<circle cx="180" cy="215" r="20" fill="#BFC6D4"/><circle cx="180" cy="215" r="13" fill="#5BC0EB"/>'
    s += '<path d="M150 270 L120 330 L152 320Z M210 270 L240 330 L208 320Z" fill="#E23B3B"/><rect x="152" y="300" width="56" height="10" fill="#E23B3B"/>'
    for cx, cy, rr in [(90, 470, 50), (160, 450, 44), (230, 470, 52), (300, 455, 46), (20, 480, 40), (350, 480, 40)]:
        s += f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="#F3E8F2"/>'
    return s


@cover("typewriter", "study")
def _():
    s = bg("#F7D5CC") + '<rect y="400" width="360" height="100" fill="#A9774A"/>'
    s += '<rect x="120" y="130" width="120" height="120" fill="#FBF8F2"/>' + "".join(f'<line x1="134" y1="{y}" x2="226" y2="{y}" stroke="#C9C2B6" stroke-width="2"/>' for y in range(150, 240, 14))
    s += '<rect x="60" y="230" width="240" height="40" rx="14" fill="#2F7A78"/><rect x="40" y="240" width="20" height="16" rx="4" fill="#2A2A2E"/><rect x="300" y="240" width="20" height="16" rx="4" fill="#2A2A2E"/>'
    s += '<path d="M50 270 h260 l20 120 h-300z" fill="#3A918D"/>'
    for row in range(4):
        for k in range(9 - row % 2):
            s += f'<circle cx="{78 + k * 26 + (row % 2) * 13}" cy="{300 + row * 22}" r="8" fill="#FBF8F2"/><circle cx="{78 + k * 26 + (row % 2) * 13}" cy="{300 + row * 22}" r="8" fill="none" stroke="#2A2A2E" stroke-width="2"/>'
    return s


@cover("fountain-pen", "study")
def _():
    s = bg("#FBF7EC") + "".join(f'<line x1="0" y1="{y}" x2="360" y2="{y}" stroke="#D7E1EC" stroke-width="1.5"/>' for y in range(60, 500, 28))
    s += '<line x1="50" y1="0" x2="50" y2="500" stroke="#F2B3B3" stroke-width="2"/>'
    s += '<path d="M60 280 C90 220 140 230 120 270 C100 310 60 300 90 260 C120 220 170 250 150 300" stroke="#26407F" stroke-width="4" fill="none" stroke-linecap="round"/>'
    s += '<g transform="translate(240 200) rotate(35)"><rect x="-14" y="-170" width="28" height="160" rx="12" fill="#1E2A4A"/><rect x="-14" y="-60" width="28" height="8" fill="#D8A84A"/>'
    s += '<path d="M-12 -10 L12 -10 L4 40 L0 50 L-4 40Z" fill="#D8A84A"/><line x1="0" y1="10" x2="0" y2="46" stroke="#1E2A4A" stroke-width="2"/></g>'
    s += '<rect x="230" y="370" width="70" height="70" rx="12" fill="#1E2A4A"/><rect x="246" y="352" width="38" height="22" rx="4" fill="#2A2A2E"/><rect x="240" y="390" width="50" height="26" rx="4" fill="#FBF7EC"/>'
    return s


# ---------------------------------------------------------------- Plants
@cover("cactus", "plants")
def _():
    s = bg("#F6D7D3")
    s += '<path d="M180 330 v-170 a26 26 0 0 1 52 0 v170z" fill="#4F9A5C"/>'
    s += '<path d="M158 280 h-30 a18 18 0 0 1 -18 -18 v-50 a14 14 0 0 1 28 0 v40 h20z" fill="#4F9A5C"/><path d="M232 250 h26 v-40 a14 14 0 0 1 28 0 v50 a18 18 0 0 1 -18 18 h-36z" fill="#4F9A5C"/>'
    s += '<path d="M194 170 v150 M206 160 v160 M218 170 v150" stroke="#3E7F4A" stroke-width="2"/>'
    s += '<circle cx="206" cy="132" r="10" fill="#F27A9A"/><circle cx="206" cy="132" r="4" fill="#F7D04C"/>'
    s += '<path d="M140 330 h132 l-14 100 h-104z" fill="#D27A5A"/><rect x="132" y="322" width="148" height="22" rx="4" fill="#E08C6A"/>'
    return s


@cover("monstera", "plants")
def _():
    def leaf(x, y, sc, a, c):
        L = 220 * sc
        out = f'<g transform="translate({x} {y}) rotate({a})"><path d="M0 0 C{L * .2} {-L * .55} {L * .85} {-L * .45} {L} 0 C{L * .85} {L * .45} {L * .2} {L * .55} 0 0Z" fill="{c}"/>'
        out += f'<path d="M0 0 L{L * .95} 0" stroke="#F2EDDF" stroke-width="{L * .02:.1f}" opacity=".7"/>'
        for i in range(1, 6):
            t = i / 6
            for side in (-1, 1):
                out += f'<path d="M{L * t:.1f} {side * L * .04:.1f} L{L * (t + .08):.1f} {side * L * .36 * math.sin(math.pi * t):.1f}" stroke="#F2EDDF" stroke-width="{L * .035:.1f}" stroke-linecap="round"/>'
        return out + '</g>'
    return bg("#F2EDDF") + leaf(320, 140, 1.1, 210, "#2F7A4D") + leaf(30, 420, 1.0, -30, "#1F5C3A") + leaf(330, 480, 0.8, 230, "#3F8F5C")


@cover("flower-vase", "plants")
def _():
    s = bg("#FBEDB8")
    stems = [(-60, 140, "#E8553D"), (-25, 110, "#F7F4EE"), (10, 90, "#F27A9A"), (45, 120, "#6C4FA3"), (75, 160, "#F29E38")]
    for dx, top, c in stems:
        s += f'<path d="M180 330 Q{180 + dx * .4} {top + 100} {180 + dx} {top}" stroke="#4F8A5B" stroke-width="4" fill="none"/>'
        cx, cy = 180 + dx, top
        s += "".join(f'<circle cx="{cx + math.cos(a) * 11:.1f}" cy="{cy + math.sin(a) * 11:.1f}" r="9" fill="{c}"/>' for a in [i * 1.2566 for i in range(5)])
        s += f'<circle cx="{cx}" cy="{cy}" r="6" fill="#F2C14E"/>'
    s += '<path d="M150 320 h60 c10 40 30 60 30 100 a60 40 0 0 1 -120 0 c0 -40 20 -60 30 -100z" fill="#3E6CB0"/><path d="M134 400 q46 20 92 0" stroke="#FBEDB8" stroke-width="4" fill="none"/>'
    return s


@cover("mushroom", "plants")
def _():
    s = bg("#E4EFDA") + '<rect y="400" width="360" height="100" fill="#A8CC8C"/>'
    r = rng(201)
    for _ in range(14):
        x = r.uniform(0, 360)
        s += f'<path d="M{x:.0f} 410 l4 -16 l4 16" fill="#7FB069"/>'
    s += '<path d="M150 410 C150 340 160 300 165 280 h30 C200 300 210 340 210 410z" fill="#F7F1E3"/>'
    s += '<path d="M80 290 C80 180 280 180 280 290 Q180 310 80 290Z" fill="#D9382F"/>'
    for cx, cy, rr in [(130, 250, 14), (180, 225, 12), (230, 252, 15), (160, 275, 8), (210, 278, 8), (105, 280, 7), (255, 282, 7)]:
        s += f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="#FBF6EC"/>'
    s += '<path d="M270 410 C270 380 274 370 276 360 h12 c2 10 6 20 6 50z" fill="#F7F1E3"/><path d="M252 365 C252 320 312 320 312 365 Q282 372 252 365Z" fill="#D9382F"/><circle cx="282" cy="345" r="6" fill="#FBF6EC"/>'
    return s


@cover("tulips", "plants")
def _():
    s = f'<defs>{grad("g", (0, "#CFE7F5"), (1, "#F3EEDB"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += '<circle cx="90" cy="110" r="30" fill="#FFF0BF"/>' + cloud(260, 90, 0.8)
    s += '<g transform="translate(270 200)"><path d="M-14 120 L-8 0 h16 l6 120z" fill="#E9E1D2"/><path d="M-10 0 l10 -14 l10 14z" fill="#C2725A"/>'
    s += "".join(f'<rect x="-3" y="-60" width="6" height="60" fill="#8B5E3C" transform="rotate({a} 0 -6)"/>' for a in [20, 110, 200, 290]) + '</g>'
    s += hills(330, "#9CCB7A", 211, 2, 20) + hills(380, "#7FB069", 212, 3, 15)
    r = rng(213)
    cols = ["#E23B3B", "#7B4FA3", "#F2C14E", "#F27A9A"]
    for row, (y0, scale) in enumerate([(400, 0.8), (440, 1.0), (490, 1.25)]):
        x = -10 + row * 12
        while x < W + 20:
            c = r.choice(cols)
            h = 40 * scale
            s += f'<path d="M{x} {y0} v-{h}" stroke="#4F8A5B" stroke-width="{3 * scale:.1f}"/>'
            s += f'<path d="M{x - 9 * scale} {y0 - h} q0 -{18 * scale} {9 * scale} -{22 * scale} q{9 * scale} {4 * scale} {9 * scale} {22 * scale} q-{9 * scale} {8 * scale} -{18 * scale} 0z" fill="{c}"/>'
            x += 26 * scale
    return s


# ---------------------------------------------------------------- Sports
@cover("padel", "sports")
def _():
    s = bg("#2F6FC0") + '<rect x="30" y="30" width="300" height="440" fill="none" stroke="#fff" stroke-width="4" opacity=".8"/><line x1="30" y1="250" x2="330" y2="250" stroke="#fff" stroke-width="4" opacity=".8"/><line x1="180" y1="120" x2="180" y2="380" stroke="#fff" stroke-width="4" opacity=".8"/>'
    s += '<rect x="0" y="236" width="360" height="28" fill="#1E4C8A" opacity=".5"/>'
    s += '<g transform="translate(170 220) rotate(-30)"><rect x="-10" y="70" width="20" height="90" rx="8" fill="#2A2A2E"/><ellipse cx="0" cy="0" rx="70" ry="84" fill="#F4F1EA"/><ellipse cx="0" cy="0" rx="70" ry="84" fill="none" stroke="#E8553D" stroke-width="8"/>'
    s += "".join(f'<circle cx="{x}" cy="{y}" r="4" fill="#2F6FC0"/>' for x in range(-40, 50, 16) for y in range(-50, 60, 16) if (x / 70) ** 2 + (y / 84) ** 2 < 0.62) + '</g>'
    s += '<circle cx="270" cy="380" r="22" fill="#D9F04A"/><path d="M250 372 q20 10 40 0 M250 388 q20 -10 40 0" stroke="#fff" stroke-width="3" fill="none"/>'
    return s


@cover("sneaker", "sports")
def _():
    s = f'<defs>{grad("g", (0, "#FCE6D4"), (1, "#F7C3B0"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + '<circle cx="110" cy="110" r="34" fill="#FFE2A6"/>'
    s += '<rect y="360" width="360" height="140" fill="#E86F55"/>' + "".join(f'<line x1="0" y1="{y}" x2="360" y2="{y}" stroke="#fff" stroke-width="3" opacity=".7"/>' for y in [390, 440, 490])
    s += '<g transform="translate(40 230)"><path d="M20 100 C10 60 30 30 70 20 L120 10 C150 40 180 60 240 70 C270 76 285 90 280 110 L20 120Z" fill="#5A55D6"/>'
    s += '<path d="M10 110 h275 v20 h-275z" fill="#FBF8F2"/><path d="M70 20 L120 10 L130 30 L80 40Z" fill="#7A76E6"/><path d="M150 60 l-30 30 M170 66 l-30 30 M190 70 l-30 30" stroke="#FBF8F2" stroke-width="5" stroke-linecap="round"/>'
    s += '<path d="M200 80 C220 76 260 80 275 100" stroke="#F2C14E" stroke-width="6" fill="none"/></g>'
    for y in [270, 300, 330]:
        s += f'<line x1="0" y1="{y}" x2="40" y2="{y}" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity=".8"/>'
    return s


@cover("bicycle", "sports")
def _():
    s = bg("#CDEBDD") + hills(400, "#A8D5BA", 221, 2, 20)
    st = 'stroke="#2E3A59" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"'
    s += f'<circle cx="100" cy="320" r="56" {st}/><circle cx="260" cy="320" r="56" {st}/>'
    s += f'<path d="M100 320 L150 230 L240 230 L180 320 Z M150 230 L180 320 M240 230 L260 320 M240 230 L230 200 h24 M150 230 L140 210 h-20" {st}/>'
    s += '<circle cx="180" cy="320" r="10" fill="#E8553D"/><path d="M230 200 h24" stroke="#E8553D" stroke-width="8" stroke-linecap="round"/><path d="M120 210 h26" stroke="#2E3A59" stroke-width="10" stroke-linecap="round"/>'
    s += '<path d="M228 196 q10 -30 40 -20" stroke="none" fill="none"/><rect x="216" y="160" width="40" height="30" rx="4" fill="#F2C14E"/><circle cx="226" cy="158" r="8" fill="#E23B3B"/><circle cx="244" cy="156" r="8" fill="#7BB662"/>'
    return s


# ---------------------------------------------------------------- Summer
@cover("beach", "summer")
def _():
    s = bg("#F4DBA8") + '<path d="M0 0 h360 v150 q-60 30 -120 10 t-120 10 t-120 -10z" fill="#3FB7C9"/><path d="M0 150 q60 20 120 10 t120 -10 t120 10" stroke="#fff" stroke-width="6" fill="none" opacity=".8"/>'
    s += '<g transform="translate(80 300) rotate(-20)"><rect width="70" height="150" rx="6" fill="#fff"/>' + "".join(f'<rect y="{y}" width="70" height="14" fill="#3E6CB0"/>' for y in range(10, 150, 28)) + '</g>'
    s += '<circle cx="230" cy="260" r="70" fill="#fff"/>' + "".join(
        f'<path d="M230 260 L{230 + math.cos(math.radians(a)) * 70:.1f} {260 + math.sin(math.radians(a)) * 70:.1f} A70 70 0 0 1 {230 + math.cos(math.radians(a + 45)) * 70:.1f} {260 + math.sin(math.radians(a + 45)) * 70:.1f}Z" fill="#E8553D"/>' for a in range(0, 360, 90))
    s += '<circle cx="230" cy="260" r="7" fill="#fff"/>'
    s += '<circle cx="290" cy="420" r="20" fill="#fff"/><path d="M270 420 a20 20 0 0 1 40 0z" fill="#F2C14E"/><path d="M280 404 q10 16 20 32" stroke="#3E6CB0" stroke-width="5" fill="none"/>'
    return s


@cover("ice-cream", "summer")
def _():
    s = bg("#CFE9F3")
    cones = [(100, 260, "#F7A8C0"), (180, 230, "#A8E6CF"), (260, 260, "#7A4A30")]
    for x, top, c in cones:
        s += f'<path d="M{x - 34} {top + 30} L{x} {top + 190} L{x + 34} {top + 30}Z" fill="#E8B26A"/>'
        s += "".join(f'<line x1="{x - 30 + k * 12}" y1="{top + 34}" x2="{x - 10 + k * 8}" y2="{top + 150}" stroke="#C98F4A" stroke-width="2"/>' for k in range(5))
        s += f'<circle cx="{x}" cy="{top + 10}" r="40" fill="{c}"/><path d="M{x - 40} {top + 18} q10 18 20 4 q10 18 20 2 q10 18 20 2 q10 18 20 -6" fill="{c}"/>'
    s += '<circle cx="260" cy="214" r="10" fill="#D9382F"/><path d="M260 204 q4 -14 14 -18" stroke="#4F8A5B" stroke-width="3" fill="none"/>'
    s += "".join(f'<rect x="{165 + dx}" y="{205 + dy}" width="8" height="3" rx="1.5" fill="{c}" transform="rotate({dx * 4} {169 + dx} {206 + dy})"/>' for dx, dy, c in [(0, 0, "#E8553D"), (14, 10, "#F2C14E"), (-12, 14, "#3E6CB0"), (6, 22, "#fff")])
    return s


@cover("watermelon", "summer")
def _():
    r = rng(241)

    def slice_(x, y, row, col):
        a = r.uniform(-25, 25) + (180 if row % 2 else 0)
        return (f'<g transform="translate({x:.0f} {y:.0f}) rotate({a:.0f})"><path d="M-32 0 A32 32 0 0 0 32 0Z" fill="#3E9B57"/><path d="M-27 0 A27 27 0 0 0 27 0Z" fill="#F25F6B"/>'
                + "".join(f'<ellipse cx="{math.cos(t) * 15:.1f}" cy="{math.sin(t) * 15:.1f}" rx="1.6" ry="2.6" fill="#2B2D33"/>' for t in [0.6, 1.2, 1.8, 2.5]) + '</g>')
    return bg("#C3E8D2") + grid_pattern(96, 80, slice_)


@cover("palm-sunset", "summer")
def _():
    s = f'<defs>{grad("g", (0, "#FFD38A"), (0.6, "#F59060"), (1, "#E25F6B"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += '<circle cx="190" cy="330" r="80" fill="#FFE9B0"/>' + birds(240, 160, 2, "#8a4a4a", 5)
    s += '<rect y="330" width="360" height="170" fill="#5B3A78"/>' + "".join(f'<rect x="{190 - (90 - k * 12)}" y="{345 + k * 16}" width="{(90 - k * 12) * 2}" height="4" rx="2" fill="#FFE9B0" opacity=".55"/>' for k in range(6))

    def palm(x, base, h, lean):
        out = f'<path d="M{x} {base} Q{x + lean * .4} {base - h * .5} {x + lean} {base - h}" stroke="#2B1F3A" stroke-width="9" fill="none"/>'
        tx, ty = x + lean, base - h
        for a in [-160, -120, -60, -20, 20, -90]:
            ex, ey = tx + math.cos(math.radians(a)) * 70, ty + math.sin(math.radians(a)) * 40 + 30
            out += f'<path d="M{tx} {ty} Q{(tx + ex) / 2} {ty - 30} {ex:.0f} {ey:.0f} Q{(tx + ex) / 2} {ty - 10} {tx} {ty}Z" fill="#2B1F3A"/>'
        return out
    s += palm(70, 340, 200, 30) + palm(300, 340, 150, -20)
    return s


@cover("flamingo", "summer")
def _():
    s = f'<defs>{grad("g", (0, "#D9EEF5"), (1, "#F7E8E0"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + cloud(280, 90, 0.8) + '<circle cx="80" cy="300" r="26" fill="#FFF0D8"/>'
    s += '<path d="M0 320 q60 -20 120 0 t120 0 t120 0 v180 h-360z" fill="#7FCBCB"/>'

    def flam(x, y, sc, flip=1):
        return (f'<g transform="translate({x} {y}) scale({sc * flip} {sc})"><ellipse cx="0" cy="0" rx="40" ry="26" fill="#F48FA8"/><path d="M-10 -20 q-30 -10 -14 -60 q10 -20 26 -10" stroke="#F48FA8" stroke-width="9" fill="none" stroke-linecap="round"/>'
                '<path d="M2 -90 l14 6 l-8 8z" fill="#2B2B2B"/><path d="M0 24 v80 M10 24 v40 l14 10" stroke="#E57A93" stroke-width="4" fill="none"/><path d="M-30 -6 q20 -14 50 0" stroke="#E0708C" stroke-width="5" fill="none"/></g>')
    s += flam(150, 260, 1.1) + flam(260, 300, 0.85, -1)
    return s


@cover("sailboat", "summer")
def _():
    s = bg("#BFE3F5") + '<circle cx="280" cy="100" r="30" fill="#FFE07A"/>' + cloud(90, 110, 0.9) + birds(200, 150, 2, "#5a6a7a", 8)
    s += '<path d="M180 120 L180 330 L90 330Z" fill="#FBF8F2"/><path d="M190 140 L190 330 L270 330Z" fill="#E8553D"/><rect x="180" y="110" width="6" height="230" fill="#7A4E2D"/>'
    s += '<path d="M90 340 h190 l-26 36 h-140z" fill="#264653"/>'
    for i, c in enumerate(["#3E8EB8", "#2F78A3", "#256590"]):
        s += wave_path(380 + i * 35, 10, 60, c)
    return s


# ---------------------------------------------------------------- Autumn
@cover("autumn-trees", "autumn")
def _():
    s = bg("#FBE3CB") + '<circle cx="250" cy="110" r="34" fill="#FFF3E0"/>'
    s += hills(400, "#E8A86A", 251, 2, 20)
    for x, y, rr, c in [(90, 300, 60, "#E8743C"), (180, 280, 80, "#F29E38"), (270, 310, 55, "#D9542E")]:
        s += f'<rect x="{x - 6}" y="{y}" width="12" height="{420 - y}" fill="#7A4E2D"/><circle cx="{x}" cy="{y}" r="{rr}" fill="{c}"/><circle cx="{x - rr * .3}" cy="{y - rr * .3}" r="{rr * .4}" fill="#fff" opacity=".12"/>'
    s += '<rect y="420" width="360" height="80" fill="#D98C4A"/>'
    r = rng(252)
    for _ in range(14):
        x, y, a = r.uniform(0, 360), r.uniform(150, 480), r.uniform(0, 360)
        s += f'<path d="M{x:.0f} {y:.0f} q6 -8 12 0 q-6 8 -12 0z" fill="{r.choice(["#E8553D", "#F2C14E", "#C2412D"])}" transform="rotate({a:.0f} {x:.0f} {y:.0f})"/>'
    return s


@cover("pumpkins", "autumn")
def _():
    s = bg("#2F5A50")
    s += '<path d="M0 60 Q180 120 360 60" stroke="#3a2a1a" stroke-width="2" fill="none"/>'
    for i in range(10):
        t = i / 9
        x = t * 360
        y = 60 + 60 * 4 * t * (1 - t) * 0.5
        s += f'<path d="M{x - 8:.0f} {y:.0f} l8 16 l8 -16z" fill="{["#E8553D", "#F2C14E", "#F29E38"][i % 3]}"/>'
    s += '<rect y="380" width="360" height="120" fill="#7A4E2D"/><rect y="380" width="360" height="10" fill="#5E3A1F"/>'

    def pumpkin(x, y, rx, ry, c):
        out = f'<rect x="{x - 4}" y="{y - ry - 14}" width="8" height="18" rx="3" fill="#5E7A3A"/>'
        for k, dx in enumerate([-rx * .55, rx * .55, 0]):
            out += f'<ellipse cx="{x + dx:.0f}" cy="{y}" rx="{rx * .55:.0f}" ry="{ry}" fill="{c}" opacity="{1 if k < 2 else 1}"/>'
        out += f'<ellipse cx="{x}" cy="{y}" rx="{rx * .4:.0f}" ry="{ry}" fill="#000" opacity=".06"/>'
        return out
    s += pumpkin(110, 340, 80, 48, "#F28A2E") + pumpkin(250, 350, 60, 38, "#F4A63E") + pumpkin(190, 370, 42, 26, "#F6EAD3")
    r = rng(261)
    for _ in range(8):
        x, y, a = r.uniform(0, 360), r.uniform(120, 300), r.uniform(0, 360)
        s += f'<path d="M{x:.0f} {y:.0f} q6 -8 12 0 q-6 8 -12 0z" fill="#E8853C" transform="rotate({a:.0f} {x:.0f} {y:.0f})"/>'
    return s


@cover("rain", "autumn")
def _():
    s = f'<defs>{grad("g", (0, "#8FA3B8"), (1, "#B9C6D3"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + cloud(90, 70, 1.3, "#E7ECF1") + cloud(270, 60, 1.1, "#E7ECF1")
    r = rng(271)
    for _ in range(60):
        x, y = r.uniform(0, 360), r.uniform(100, 440)
        s += f'<line x1="{x:.0f}" y1="{y:.0f}" x2="{x - 4:.0f}" y2="{y + 14:.0f}" stroke="#fff" stroke-width="2" opacity=".55" stroke-linecap="round"/>'
    s += '<path d="M90 250 A90 70 0 0 1 270 250 Q247 236 225 250 Q202 236 180 250 Q157 236 135 250 Q112 236 90 250Z" fill="#F2C11C"/>'
    s += '<path d="M180 180 v-14" stroke="#3a3a3a" stroke-width="4"/><path d="M180 250 v120 a14 14 0 0 1 -28 0" stroke="#3a3a3a" stroke-width="5" fill="none" stroke-linecap="round"/>'
    s += '<ellipse cx="180" cy="430" rx="120" ry="16" fill="#6F8499" opacity=".6"/><ellipse cx="140" cy="430" rx="24" ry="4" fill="none" stroke="#fff" stroke-width="2" opacity=".6"/>'
    return s


@cover("knit", "autumn")
def _():
    s = bg("#B9573A")
    for col in range(6):
        x = col * 60 + 30
        for y in range(0, 520, 40):
            s += f'<path d="M{x - 22} {y} q22 20 0 40 M{x + 22} {y} q-22 20 0 40" stroke="#9A4329" stroke-width="10" fill="none"/>'
        s += f'<line x1="{x + 30}" y1="0" x2="{x + 30}" y2="500" stroke="#A44A2F" stroke-width="6"/>'
    s += '<line x1="140" y1="200" x2="280" y2="400" stroke="#D8C7A8" stroke-width="6" stroke-linecap="round"/><line x1="230" y1="200" x2="150" y2="390" stroke="#D8C7A8" stroke-width="6" stroke-linecap="round"/>'
    s += '<circle cx="200" cy="370" r="52" fill="#F4EAD6"/>' + "".join(f'<path d="M{160 + k * 10} 340 q30 30 {50 - k * 6} 70" stroke="#DCCDB0" stroke-width="3" fill="none"/>' for k in range(6))
    s += '<path d="M150 400 q-60 30 -100 90" stroke="#F4EAD6" stroke-width="3" fill="none"/>'
    return s


# ---------------------------------------------------------------- Winter
def snowflake(x, y, size, op=1):
    out = f'<g transform="translate({x} {y})" stroke="#fff" stroke-width="{max(1.5, size / 10):.1f}" stroke-linecap="round" opacity="{op}">'
    for a in range(0, 360, 60):
        ex, ey = math.cos(math.radians(a)) * size, math.sin(math.radians(a)) * size
        out += f'<line x1="0" y1="0" x2="{ex:.1f}" y2="{ey:.1f}"/>'
        for t in (0.55,):
            bx, by = ex * t, ey * t
            for d in (-40, 40):
                cx = bx + math.cos(math.radians(a + d)) * size * .3
                cy = by + math.sin(math.radians(a + d)) * size * .3
                out += f'<line x1="{bx:.1f}" y1="{by:.1f}" x2="{cx:.1f}" y2="{cy:.1f}"/>'
    return out + '</g>'


@cover("snowflakes", "winter")
def _():
    s = f'<defs>{grad("g", (0, "#3D74C4"), (1, "#7FB2E5"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += snowflake(180, 230, 60) + snowflake(70, 90, 26, .8) + snowflake(290, 110, 30, .8) + snowflake(80, 380, 22, .7) + snowflake(300, 360, 28, .7)
    r = rng(281)
    for _ in range(40):
        s += f'<circle cx="{r.uniform(0, 360):.0f}" cy="{r.uniform(0, 500):.0f}" r="{r.uniform(1, 3):.1f}" fill="#fff" opacity=".7"/>'
    s += '<path d="M0 440 q90 -30 180 0 t180 0 v60 h-360z" fill="#EEF5FC"/>'
    return s


@cover("cabin", "winter")
def _():
    s = f'<defs>{grad("g", (0, "#0F1A3C"), (1, "#2C3F78"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + stars(291, 60, 280) + moon(90, 90, 20)
    s += '<path d="M0 380 Q180 330 360 380 V500 H0Z" fill="#E8EEF7"/>'
    s += '<path d="M120 380 v-70 h120 v70z" fill="#7A4E2D"/><path d="M106 316 L180 250 L254 316Z" fill="#5E3A1F"/><path d="M100 318 L180 246 L260 318 L250 322 L180 262 L110 322Z" fill="#fff"/>'
    s += '<rect x="150" y="330" width="28" height="26" fill="#FFD27A"/><line x1="164" y1="330" x2="164" y2="356" stroke="#7A4E2D" stroke-width="3"/><rect x="196" y="336" width="24" height="44" fill="#4A2E18"/>'
    s += '<rect x="214" y="250" width="14" height="40" fill="#5E3A1F"/>' + "".join(f'<circle cx="{224 + k * 10}" cy="{236 - k * 18}" r="{6 + k * 2}" fill="#fff" opacity="{0.45 - k * .1:.2f}"/>' for k in range(4))
    for x, sc in [(40, 1.0), (290, 1.1), (330, 0.8)]:
        s += pine_tiered(x, 390, 60 * sc, 120 * sc, "#1F4D3A") + f'<path d="M{x - 18 * sc} {390 - 58 * sc} l{18 * sc} -10 l{18 * sc} 10z M{x - 12 * sc} {390 - 90 * sc} l{12 * sc} -8 l{12 * sc} 8z" fill="#fff"/>'
    return s


@cover("penguin", "winter")
def _():
    s = bg("#CDE7F5") + snowflake(70, 80, 12, .9) + snowflake(290, 140, 10, .9) + snowflake(250, 60, 8, .9)
    s += '<rect y="370" width="360" height="130" fill="#4F9BC9"/><path d="M60 380 L300 380 L280 410 L80 410Z" fill="#F3F8FC"/>'
    s += '<ellipse cx="180" cy="290" rx="62" ry="90" fill="#2A2E3A"/><ellipse cx="180" cy="305" rx="44" ry="70" fill="#F7F7F2"/><circle cx="180" cy="220" r="44" fill="#2A2E3A"/>'
    s += '<ellipse cx="180" cy="230" rx="30" ry="24" fill="#F7F7F2"/><circle cx="168" cy="222" r="4" fill="#2A2E3A"/><circle cx="192" cy="222" r="4" fill="#2A2E3A"/><path d="M174 234 l6 8 l6 -8z" fill="#F2A33A"/>'
    s += '<path d="M138 256 h84 v14 h-84z" fill="#E23B3B"/><path d="M200 266 h16 v40 h-16z" fill="#E23B3B"/>' + "".join(f'<rect x="{144 + k * 16}" y="258" width="6" height="10" fill="#fff" opacity=".6"/>' for k in range(5))
    s += '<path d="M120 290 q-30 20 -10 60" stroke="#2A2E3A" stroke-width="16" stroke-linecap="round" fill="none"/><path d="M240 290 q34 -10 40 -50" stroke="#2A2E3A" stroke-width="16" stroke-linecap="round" fill="none"/>'
    s += '<ellipse cx="160" cy="378" rx="16" ry="6" fill="#F2A33A"/><ellipse cx="200" cy="378" rx="16" ry="6" fill="#F2A33A"/>'
    return s


@cover("cocoa", "winter")
def _():
    s = bg("#2E4366") + snowflake(60, 70, 10, .5) + snowflake(300, 100, 12, .5) + snowflake(280, 260, 8, .4) + snowflake(70, 300, 9, .4)
    s += '<rect x="70" y="390" width="220" height="40" rx="6" fill="#B4362E"/>' + "".join(f'<path d="M{80 + k * 22} 410 l6 -8 l6 8 l-6 8z" fill="#F4EAD6"/>' for k in range(10))
    s += '<rect y="430" width="360" height="70" fill="#7A4E2D"/>'
    s += '<path d="M110 230 h140 v120 a30 30 0 0 1 -30 30 h-80 a30 30 0 0 1 -30 -30z" fill="#FBF7EF"/><path d="M250 260 a32 32 0 0 1 0 64" stroke="#FBF7EF" stroke-width="14" fill="none"/>'
    s += snowflake(180, 300, 24).replace('#fff', '#C9473E')
    s += '<ellipse cx="180" cy="230" rx="70" ry="12" fill="#6B3E25"/>' + "".join(f'<rect x="{x}" y="{y}" width="20" height="16" rx="5" fill="#fff"/>' for x, y in [(140, 212), (164, 206), (190, 210), (210, 216)])
    for x in [155, 180, 205]:
        s += f'<path d="M{x} 195 q-10 -15 0 -30 t0 -30" stroke="#fff" stroke-width="3" fill="none" opacity=".6" stroke-linecap="round"/>'
    return s


@cover("xmas-tree", "winter")
def _():
    s = bg("#A9283A")
    r = rng(301)
    for _ in range(30):
        s += f'<circle cx="{r.uniform(0, 360):.0f}" cy="{r.uniform(0, 420):.0f}" r="{r.uniform(1, 2.5):.1f}" fill="#fff" opacity=".5"/>'
    s += '<rect x="168" y="380" width="24" height="40" fill="#6B3E25"/>'
    for i, (w, top, bot) in enumerate([(240, 250, 390), (190, 180, 310), (140, 120, 230)]):
        s += f'<path d="M{180 - w / 2} {bot} L180 {top} L{180 + w / 2} {bot}Z" fill="{["#1E6B45", "#25804F", "#2E9358"][i]}"/>'
    s += '<path d="M180 92 l7 16 l17 1 l-13 11 l4 17 l-15 -9 l-15 9 l4 -17 l-13 -11 l17 -1z" fill="#F7D04C"/>'
    for x, y, c in [(150, 210, "#F7D04C"), (205, 200, "#5BC0EB"), (130, 290, "#F25F6B"), (230, 280, "#F7D04C"), (180, 260, "#fff"), (110, 360, "#5BC0EB"), (250, 360, "#F25F6B"), (190, 340, "#F7D04C")]:
        s += f'<circle cx="{x}" cy="{y}" r="7" fill="{c}"/>'
    s += '<rect y="420" width="360" height="80" fill="#F3EEE6"/>'
    s += '<rect x="80" y="390" width="50" height="40" fill="#F7D04C"/><rect x="101" y="390" width="8" height="40" fill="#E23B3B"/><rect x="230" y="400" width="56" height="30" fill="#5BC0EB"/><rect x="254" y="400" width="8" height="30" fill="#fff"/>'
    return s


# ---------------------------------------------------------------- Animals
@cover("cat", "animals")
def _():
    s = bg("#B7E1DA") + '<ellipse cx="180" cy="430" rx="120" ry="18" fill="#E8865A" opacity=".8"/><ellipse cx="180" cy="430" rx="100" ry="12" fill="#F2A27A"/>'
    s += '<path d="M240 420 q70 -10 60 -70 q-6 -20 -20 -10" stroke="#F29E4C" stroke-width="16" stroke-linecap="round" fill="none"/>'
    s += '<ellipse cx="180" cy="350" rx="70" ry="80" fill="#F29E4C"/><ellipse cx="180" cy="370" rx="40" ry="55" fill="#FBE3C6"/>'
    s += '<circle cx="180" cy="240" r="58" fill="#F29E4C"/><path d="M130 220 L132 160 L170 196Z M230 220 L228 160 L190 196Z" fill="#F29E4C"/><path d="M138 206 L140 176 L160 196Z M222 206 L220 176 L200 196Z" fill="#F7B9A8"/>'
    s += '<path d="M156 240 q8 -8 16 0 M188 240 q8 -8 16 0" stroke="#3A2A2A" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M175 256 h10 l-5 6z" fill="#E9707E"/>'
    s += '<path d="M120 256 l30 4 M120 268 l30 -2 M240 256 l-30 4 M240 268 l-30 -2" stroke="#3A2A2A" stroke-width="2"/>'
    s += '<path d="M180 190 v18 M166 194 l4 14 M194 194 l-4 14" stroke="#E07F2E" stroke-width="5" stroke-linecap="round"/>'
    return s


@cover("dog", "animals")
def _():
    s = bg("#F7C948")
    r = rng(321)
    for _ in range(8):
        x, y = r.uniform(20, 340), r.uniform(20, 480)
        if 70 < x < 290 and 120 < y < 420:
            continue
        s += f'<g transform="translate({x:.0f} {y:.0f})" fill="#E5A82E"><circle r="6"/><circle cx="-7" cy="-9" r="3"/><circle cx="0" cy="-12" r="3"/><circle cx="7" cy="-9" r="3"/></g>'
    s += '<path d="M80 420 q100 -80 200 0z" fill="#C9473E"/><rect x="120" y="360" width="120" height="16" rx="8" fill="#C9473E"/><circle cx="180" cy="390" r="12" fill="#F7D04C"/>'
    s += '<ellipse cx="180" cy="260" rx="90" ry="100" fill="#A86B3D"/><ellipse cx="180" cy="300" rx="56" ry="54" fill="#F4E1C7"/>'
    s += '<path d="M96 200 C60 220 60 320 96 330 C120 300 120 240 110 200Z M264 200 C300 220 300 320 264 330 C240 300 240 240 250 200Z" fill="#6E4325"/>'
    s += '<circle cx="150" cy="248" r="10" fill="#2A1E16"/><circle cx="210" cy="248" r="10" fill="#2A1E16"/><circle cx="153" cy="245" r="3" fill="#fff"/><circle cx="213" cy="245" r="3" fill="#fff"/>'
    s += '<ellipse cx="180" cy="285" rx="18" ry="12" fill="#2A1E16"/><path d="M180 297 v14 q-12 10 -24 0 M180 311 q12 10 24 0" stroke="#2A1E16" stroke-width="3" fill="none"/><path d="M170 316 q10 22 20 0z" fill="#E9707E"/>'
    return s


@cover("fishbowl", "animals")
def _():
    s = bg("#FCE7D6") + '<rect y="400" width="360" height="100" fill="#E8C8A8"/>'
    s += '<circle cx="180" cy="290" r="110" fill="#DFF2F6" opacity=".7"/><path d="M76 260 A110 110 0 0 0 284 260 Z" fill="#7FCBDD" opacity=".9" transform="translate(0 30)"/>'
    s += '<circle cx="180" cy="290" r="110" fill="none" stroke="#B7DCE5" stroke-width="5"/><ellipse cx="180" cy="186" rx="60" ry="10" fill="none" stroke="#B7DCE5" stroke-width="5"/>'
    s += '<path d="M130 390 q-10 -40 6 -70 q10 30 -6 70 M150 392 q4 -50 20 -66 q0 40 -20 66" fill="#4F9A5C"/><ellipse cx="200" cy="388" rx="40" ry="10" fill="#E8C8A8"/>'
    s += '<g transform="translate(200 300)"><ellipse rx="26" ry="16" fill="#F28A2E"/><path d="M22 0 l22 -14 v28z" fill="#F28A2E"/><circle cx="-12" cy="-4" r="3" fill="#2A2A2A"/></g>'
    s += '<g transform="translate(140 330) scale(.6)"><ellipse rx="26" ry="16" fill="#F2C14E"/><path d="M22 0 l22 -14 v28z" fill="#F2C14E"/><circle cx="-12" cy="-4" r="3" fill="#2A2A2A"/></g>'
    s += '<circle cx="176" cy="268" r="5" fill="#fff" opacity=".7"/><circle cx="168" cy="250" r="3.5" fill="#fff" opacity=".7"/><ellipse cx="120" cy="250" rx="10" ry="30" fill="#fff" opacity=".35" transform="rotate(20 120 250)"/>'
    return s


@cover("birds-wire", "animals")
def _():
    s = f'<defs>{grad("g", (0, "#E9E3F5"), (1, "#F9E4EA"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + '<circle cx="260" cy="120" r="32" fill="#fff" opacity=".8"/>' + cloud(90, 100, 0.8)
    for y0, sag in [(250, 30), (350, 24)]:
        s += f'<path d="M0 {y0} Q180 {y0 + sag * 2} 360 {y0}" stroke="#4A4A5A" stroke-width="2" fill="none"/>'
    birds_def = [(70, 250, 30, "#E8553D"), (120, 250, 30, "#5B8DEF"), (230, 250, 30, "#F2C14E"), (100, 350, 24, "#7BB662"), (200, 350, 24, "#E07A9A"), (280, 350, 24, "#2A9D8F")]
    for x, y0, sag, c in birds_def:
        t = x / 360
        y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * (y0 + sag * 2) + t ** 2 * y0
        s += f'<g transform="translate({x} {y - 14:.0f})"><ellipse rx="14" ry="11" fill="{c}"/><circle cx="10" cy="-8" r="8" fill="{c}"/><path d="M17 -9 l7 2 l-7 2z" fill="#F2A33A"/><circle cx="12" cy="-10" r="1.6" fill="#222"/><path d="M-12 2 l-10 6 l12 -2z" fill="{c}"/></g>'
    return s


@cover("fox", "animals")
def _():
    s = f'<defs>{grad("g", (0, "#BFE3D3"), (1, "#E5F2E9"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    s += '<path d="M290 70 a24 24 0 1 0 20 36 a18 18 0 1 1 -20 -36z" fill="#FFF3C4"/>'
    for x in [20, 70, 300, 340]:
        s += pine(x - 30, 440, 60, 180, "#7FB79A")
    s += '<rect y="430" width="360" height="70" fill="#9ACB9F"/>'
    s += '<path d="M230 420 q90 -20 70 -110 q-10 -30 -30 -10 q20 60 -50 90z" fill="#E8743C"/><path d="M290 316 q-14 -12 -22 0 q4 16 22 0" fill="#FBF3E8"/>'
    s += '<path d="M120 430 C110 330 150 280 180 280 C210 280 250 330 240 430Z" fill="#E8743C"/><path d="M150 430 C150 360 165 330 180 330 C195 330 210 360 210 430Z" fill="#FBF3E8"/>'
    s += '<path d="M130 200 L140 140 L170 186Z M230 200 L220 140 L190 186Z" fill="#E8743C"/><path d="M138 186 L144 158 L160 182Z M222 186 L216 158 L200 182Z" fill="#3A2A2A"/>'
    s += '<path d="M120 200 Q180 160 240 200 L180 300Z" fill="#E8743C"/><path d="M130 216 Q160 240 180 300 Q200 240 230 216 Q205 250 180 250 Q155 250 130 216Z" fill="#FBF3E8"/>'
    s += '<path d="M156 228 q8 -6 16 0 M188 228 q8 -6 16 0" stroke="#3A2A2A" stroke-width="3.5" fill="none" stroke-linecap="round"/><circle cx="180" cy="296" r="7" fill="#3A2A2A"/>'
    return s


@cover("whale", "animals")
def _():
    s = f'<defs>{grad("g", (0, "#2D7FB8"), (1, "#123E6B"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>'
    for i in range(5):
        s += f'<path d="M{40 + i * 70} 0 L{10 + i * 70} 500" stroke="#fff" stroke-width="18" opacity=".04"/>'
    s += '<path d="M50 300 C60 220 200 200 260 250 C290 270 300 250 320 220 C330 260 320 290 300 300 C320 320 330 340 320 360 C300 330 280 320 260 330 C200 380 60 380 50 300Z" fill="#26517E"/>'
    s += '<path d="M60 310 C90 350 200 360 250 320 C200 340 110 340 60 310Z" fill="#9CC3DE"/>' + "".join(f'<line x1="{90 + k * 22}" y1="{328 + k % 2}" x2="{94 + k * 22}" y2="{342}" stroke="#7FA9C7" stroke-width="2"/>' for k in range(6))
    s += '<circle cx="100" cy="280" r="6" fill="#0E2A48"/><path d="M150 330 q20 30 50 20 q-30 -6 -50 -20" fill="#1E4470"/>'
    r = rng(341)
    for _ in range(10):
        s += f'<circle cx="{r.uniform(60, 200):.0f}" cy="{r.uniform(80, 230):.0f}" r="{r.uniform(3, 9):.1f}" fill="none" stroke="#fff" stroke-width="2" opacity=".5"/>'
    s += '<path d="M0 460 q30 -40 50 0 q20 -50 40 0 M280 470 q20 -40 40 0 q20 -30 40 0" fill="#1F6B5A"/>'
    return s


@cover("owl", "animals")
def _():
    s = bg("#1E2850") + stars(351, 40) + '<circle cx="180" cy="220" r="120" fill="#F6E7B8"/>'
    s += '<path d="M40 380 Q180 360 320 380" stroke="#5E3A1F" stroke-width="16" stroke-linecap="round" fill="none"/>'
    s += '<path d="M110 370 C100 260 130 210 180 210 C230 210 260 260 250 370Z" fill="#8A6040"/><path d="M140 370 C135 300 155 270 180 270 C205 270 225 300 220 370Z" fill="#D9B98C"/>'
    s += "".join(f'<path d="M{155 + (k % 3) * 25} {290 + (k // 3) * 22} q8 8 16 0" stroke="#A9825A" stroke-width="3" fill="none"/>' for k in range(9))
    s += '<path d="M120 230 L125 190 L150 214Z M240 230 L235 190 L210 214Z" fill="#8A6040"/>'
    s += '<circle cx="152" cy="244" r="24" fill="#F4E8D0"/><circle cx="208" cy="244" r="24" fill="#F4E8D0"/><circle cx="152" cy="244" r="12" fill="#F2A33A"/><circle cx="208" cy="244" r="12" fill="#F2A33A"/><circle cx="152" cy="244" r="6" fill="#1E1E1E"/><circle cx="208" cy="244" r="6" fill="#1E1E1E"/>'
    s += '<path d="M174 266 l6 12 l6 -12z" fill="#F2A33A"/><path d="M160 372 v12 M172 372 v12 M190 372 v12 M202 372 v12" stroke="#F2A33A" stroke-width="5" stroke-linecap="round"/>'
    return s


@cover("bunny", "animals")
def _():
    s = bg("#E3F1E1")
    r = rng(361)
    for _ in range(10):
        x, y = r.uniform(20, 340), r.uniform(20, 480)
        if 90 < x < 270 and 80 < y < 420:
            continue
        s += f'<g transform="translate({x:.0f} {y:.0f})">' + "".join(f'<circle cx="{math.cos(a) * 5:.1f}" cy="{math.sin(a) * 5:.1f}" r="4" fill="#fff"/>' for a in [i * 1.2566 for i in range(5)]) + '<circle r="2.5" fill="#F2C14E"/></g>'
    s += '<ellipse cx="148" cy="170" rx="24" ry="80" fill="#F7F4EE" transform="rotate(-8 148 170)"/><ellipse cx="212" cy="170" rx="24" ry="80" fill="#F7F4EE" transform="rotate(8 212 170)"/>'
    s += '<ellipse cx="148" cy="174" rx="11" ry="58" fill="#F7C6CF" transform="rotate(-8 148 170)"/><ellipse cx="212" cy="174" rx="11" ry="58" fill="#F7C6CF" transform="rotate(8 212 170)"/>'
    s += '<ellipse cx="180" cy="300" rx="90" ry="80" fill="#F7F4EE"/><circle cx="150" cy="290" r="8" fill="#2A2A2A"/><circle cx="210" cy="290" r="8" fill="#2A2A2A"/><circle cx="153" cy="287" r="2.5" fill="#fff"/><circle cx="213" cy="287" r="2.5" fill="#fff"/>'
    s += '<path d="M172 312 h16 l-8 8z" fill="#F29BAE"/><path d="M180 320 v8 q-8 8 -16 2 M180 328 q8 8 16 2" stroke="#2A2A2A" stroke-width="2.5" fill="none"/>'
    s += '<ellipse cx="128" cy="320" rx="14" ry="8" fill="#F7C6CF" opacity=".7"/><ellipse cx="232" cy="320" rx="14" ry="8" fill="#F7C6CF" opacity=".7"/>'
    return s


# ---------------------------------------------------------------- Patterns
@cover("leaves", "patterns")
def _():
    r = rng(401)

    def leaf(x, y, row, col):
        a = r.uniform(0, 360)
        c = r.choice(["#3F7F56", "#C2725A", "#E2A24E", "#2F5E44"])
        return (f'<g transform="translate({x:.0f} {y:.0f}) rotate({a:.0f})"><path d="M0 -30 C18 -14 18 14 0 30 C-18 14 -18 -14 0 -30Z" fill="{c}"/>'
                f'<path d="M0 -26 V26" stroke="#F6EFE2" stroke-width="1.5" opacity=".6"/></g>')
    return bg("#F6EFE2") + grid_pattern(70, 64, leaf)


@cover("hearts", "patterns")
def _():
    def heart(x, y, row, col):
        c = "#E8505B" if (row + col) % 2 else "#F7F1F2"
        return f'<path d="M{x} {y + 10} C{x - 22} {y - 6} {x - 10} {y - 22} {x} {y - 10} C{x + 10} {y - 22} {x + 22} {y - 6} {x} {y + 10}Z" fill="{c}"/>'
    return bg("#F7C9D2") + grid_pattern(50, 46, heart)


@cover("tartan", "patterns")
def _():
    s = bg("#A9283A")
    for x in range(0, 360, 90):
        s += f'<rect x="{x + 20}" y="0" width="34" height="500" fill="#1E3A5F" opacity=".6"/><rect x="{x + 62}" y="0" width="6" height="500" fill="#F2C14E" opacity=".7"/><rect x="{x + 4}" y="0" width="3" height="500" fill="#fff" opacity=".5"/>'
    for y in range(0, 500, 90):
        s += f'<rect x="0" y="{y + 20}" width="360" height="34" fill="#1E3A5F" opacity=".55"/><rect x="0" y="{y + 62}" width="360" height="6" fill="#F2C14E" opacity=".65"/><rect x="0" y="{y + 4}" width="360" height="3" fill="#fff" opacity=".45"/>'
    for i in range(-50, 50):
        s += f'<line x1="{i * 8}" y1="0" x2="{i * 8 + 500}" y2="500" stroke="#000" stroke-width="1" opacity=".05"/>'
    return s


@cover("seigaiha", "patterns")
def _():
    out = [bg("#24396B")]
    r_ = 36
    row = 0
    y = -r_ * 0.2
    while y < H + r_:
        off = 0 if row % 2 == 0 else r_
        x = -r_ + off
        while x < W + r_:
            for i, k in enumerate([1.0, 0.78, 0.56, 0.34]):
                out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r_ * k:.1f}" fill="{"#EDE8DC" if i % 2 == 0 else "#24396B"}"/>')
            x += r_ * 2
        y += r_ * 0.5
        row += 1
    return "".join(out)


@cover("herringbone", "patterns")
def _():
    s = bg("#B98552")
    r = rng(421)
    cw, ph = 45, 30  # column width, plank thickness (vertical step)
    for col in range(0, 9):
        x0 = col * cw
        up = col % 2 == 0
        for k in range(-3, 22):
            y = k * ph + (ph / 2 if col % 2 else 0)
            c = r.choice(["#D8AA7A", "#C69060", "#BC8657", "#E0B78A", "#CD9A69"])
            if up:
                pts = f"{x0},{y + cw} {x0 + cw},{y} {x0 + cw},{y + ph} {x0},{y + cw + ph}"
            else:
                pts = f"{x0},{y} {x0 + cw},{y + cw} {x0 + cw},{y + cw + ph} {x0},{y + ph}"
            s += f'<polygon points="{pts}" fill="{c}" stroke="#94643A" stroke-width="1.5"/>'
    return s


@cover("confetti", "patterns")
def _():
    r = rng(431)
    s = bg("#FDECEF")
    cols = ["#E8553D", "#2A9D8F", "#F2C14E", "#5B8DEF", "#E07A9A", "#7BB662"]
    for _ in range(70):
        x, y, a, c = r.uniform(0, 360), r.uniform(0, 500), r.uniform(0, 360), r.choice(cols)
        k = r.random()
        if k < 0.4:
            s += f'<rect x="{x:.0f}" y="{y:.0f}" width="10" height="4" rx="2" fill="{c}" transform="rotate({a:.0f} {x:.0f} {y:.0f})"/>'
        elif k < 0.7:
            s += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="3" fill="{c}"/>'
        else:
            s += f'<path d="M{x:.0f} {y:.0f} q5 -8 10 0 t10 0 t10 0" stroke="{c}" stroke-width="2.5" fill="none" stroke-linecap="round" transform="rotate({a:.0f} {x:.0f} {y:.0f})"/>'
    return s


@cover("marble", "patterns")
def _():
    s = f'<defs><filter id="b"><feGaussianBlur stdDeviation="1.2"/></filter></defs>' + bg("#F4F2EE")
    r = rng(441)
    for k in range(9):
        x = r.uniform(-50, 360)
        d = f"M{x:.0f} -10"
        y = -10
        while y < 520:
            x += r.uniform(-40, 50)
            y += r.uniform(40, 80)
            d += f" Q{x + r.uniform(-30, 30):.0f} {y - 30:.0f} {x:.0f} {y:.0f}"
        col = "#C8A35A" if k % 3 == 0 else "#A9A9AE"
        s += f'<path d="{d}" stroke="{col}" stroke-width="{r.uniform(0.8, 2.6):.1f}" fill="none" opacity=".7" filter="url(#b)"/>'
    return s


@cover("constellations", "patterns")
def _():
    s = f'<defs>{grad("g", (0, "#121B45"), (1, "#22306B"))}</defs><rect width="{W}" height="{H}" fill="url(#g)"/>' + stars(451, 90, rmax=1.3)
    groups = [[(60, 80), (100, 100), (140, 90), (170, 130), (150, 170)], [(220, 220), (260, 200), (300, 230), (280, 280), (240, 270), (220, 220)], [(70, 330), (110, 360), (90, 410), (140, 430)], [(230, 380), (270, 400), (310, 370)]]
    for g in groups:
        s += '<polyline points="' + " ".join(f"{x},{y}" for x, y in g) + '" stroke="#fff" stroke-width="1.2" fill="none" opacity=".6"/>'
        s += "".join(f'<circle cx="{x}" cy="{y}" r="3.2" fill="#fff"/>' for x, y in g)
    return s


@cover("terrazzo", "patterns")
def _():
    r = rng(461)
    s = bg("#F3EDE4")
    pal = ["#E76F51", "#2A9D8F", "#E9C46A", "#264653", "#F4A261", "#B5838D"]
    for _ in range(60):
        cx, cy, rr = r.uniform(0, 360), r.uniform(0, 500), r.uniform(6, 18)
        pts = []
        for i in range(5):
            a = i / 5 * 2 * math.pi + r.uniform(-.4, .4)
            q = rr * r.uniform(.6, 1.2)
            pts.append(f"{cx + math.cos(a) * q:.0f},{cy + math.sin(a) * q:.0f}")
        s += f'<polygon points="{" ".join(pts)}" fill="{r.choice(pal)}"/>'
    return s


@cover("blush", "patterns")
def _():
    return (f'<defs><filter id="b"><feGaussianBlur stdDeviation="40"/></filter></defs>' + bg("#FBE3EC")
            + '<circle cx="80" cy="120" r="140" fill="#F4B6CB" filter="url(#b)"/><circle cx="300" cy="200" r="130" fill="#DCC6F2" filter="url(#b)"/>'
            + '<circle cx="140" cy="400" r="150" fill="#F9C2D5" filter="url(#b)"/><circle cx="320" cy="460" r="110" fill="#E8D7F7" filter="url(#b)"/>')


@cover("map", "travel")
def _():
    s = bg("#A9D6E5")
    r = rng(471)
    for _ in range(12):
        x, y = r.uniform(0, 330), r.uniform(0, 500)
        s += f'<path d="M{x:.0f} {y:.0f} q10 -8 20 0 t20 0" stroke="#fff" stroke-width="2.5" fill="none" opacity=".7"/>'
    s += '<path d="M50 100 C120 10 250 40 300 120 C360 200 300 280 250 270 C180 260 100 280 60 220 C20 170 30 130 50 100Z" fill="#F2E2B6"/>'
    s += '<circle cx="140" cy="140" r="30" fill="#9CCB86"/><circle cx="175" cy="160" r="24" fill="#86BC72"/>' + pine(120, 140, 14, 22, "#4F8A5B") + pine(150, 150, 12, 20, "#4F8A5B")
    s += '<path d="M230 180 C270 260 90 300 110 420" stroke="#D64545" stroke-width="4" stroke-dasharray="10 8" fill="none"/>'
    s += '<path d="M230 150 c-14 0 -22 10 -22 22 c0 16 22 34 22 34 s22 -18 22 -34 c0 -12 -8 -22 -22 -22z" fill="#D64545"/><circle cx="230" cy="172" r="7" fill="#fff"/>'
    s += '<circle cx="270" cy="410" r="36" fill="#fff" opacity=".9"/><path d="M270 380 l9 30 l-9 30 l-9 -30z" fill="#24396B"/><path d="M270 380 l9 30 h-18z" fill="#D64545"/>'
    return s


CATEGORY_ORDER = ["landscapes", "travel", "city", "cooking", "study", "plants", "sports", "summer", "autumn", "winter", "animals", "patterns"]


def svg(fn):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{fn()}</svg>'
