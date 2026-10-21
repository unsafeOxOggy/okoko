#!/usr/bin/env python3
"""okoko wallgen - geometric wallpapers drawn from a theme palette, as SVG.

Every figure is built from exact coordinates and a computed projection (never drawn by
eye, never stretched: the image is scaled uniformly). Standard library only.

  python3 -I wallgen.py --theme themes/okoko.theme --design e8 [--size 2560x1440] > out.svg
  python3 -I wallgen.py --list

Designs:
  e8        Gosset 4_21 polytope (E8 root system): 240 vertices, 6720 edges, Coxeter plane
  h4        600-cell, H4 Coxeter plane (30-gon Petrie polygon): 120 vertices, 720 edges
  stereo    24-cell, stereographic projection S3 -> R3: edges become circle arcs
  hopf      Hopf fibration: fibres over latitude rings of S2, stereographic projection
  penrose   Penrose P3 rhomb tiling from de Bruijn's pentagrid
  kali      5-cube (penteract) in its Coxeter plane + the Kali shell prompt
"""
import argparse
import cmath
import itertools
import math
import re
import sys

PHI = (1 + 5 ** 0.5) / 2
DESIGNS = ("e8", "h4", "stereo", "hopf", "penrose", "kali")


# -- palette ------------------------------------------------------------------------------
def load_theme(path):
    """Read KEY="#RRGGBB" pairs from a .theme file (parsed, never executed)."""
    pal = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            for k, v in re.findall(r'\b([A-Z0-9_]+)="(#[0-9A-Fa-f]{6})"', line):
                pal[k] = v.upper()
    for k in ("BG", "SURFACE", "ACCENT", "ACCENT2", "FG", "MUTED"):
        if k not in pal:
            sys.exit(f"theme {path}: {k} missing")
    return pal


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def mix(c1, c2, t):
    a, b = rgb(c1), rgb(c2)
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(a, b))


# -- linear algebra (small, exact enough) ---------------------------------------------------
def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def reflect(v, r):
    k = 2 * dot(v, r) / dot(r, r)
    return [x - k * y for x, y in zip(v, r)]


def coxeter_plane(simple, h):
    """Orthonormal basis of the Coxeter plane: the real plane of the eigenvector of the
    Coxeter element (product of the simple reflections) for exp(2 pi i / h)."""
    n = len(simple)
    cols = []
    for j in range(n):
        v = [1.0 if i == j else 0.0 for i in range(n)]
        for r in reversed(simple):
            v = reflect(v, r)
        cols.append(v)
    lam = cmath.exp(2j * math.pi / h)
    m = [[complex(cols[j][i]) - (lam if i == j else 0) for j in range(n)] for i in range(n)]
    # null vector of m by Gaussian elimination with partial pivoting
    piv_cols, row = [], 0
    for c in range(n):
        p = max(range(row, n), key=lambda r: abs(m[r][c]), default=None)
        if p is None or abs(m[p][c]) < 1e-9:
            continue
        m[row], m[p] = m[p], m[row]
        for r in range(n):
            if r != row and abs(m[r][c]) > 0:
                f = m[r][c] / m[row][c]
                m[r] = [a - f * b for a, b in zip(m[r], m[row])]
        piv_cols.append(c)
        row += 1
    free = next(c for c in range(n) if c not in piv_cols)
    v = [0j] * n
    v[free] = 1
    for r, c in enumerate(piv_cols):
        v[c] = -m[r][free] / m[r][c]
    a, b = [z.real for z in v], [z.imag for z in v]
    na = math.sqrt(dot(a, a))
    a = [x / na for x in a]
    b = [x - dot(a, b) * y for x, y in zip(b, a)]
    nb = math.sqrt(dot(b, b))
    return a, [x / nb for x in b]


def min_edges(verts, tol=1e-6):
    d2 = lambda p, q: sum((x - y) ** 2 for x, y in zip(p, q))
    m = min(d2(p, q) for p, q in itertools.combinations(verts, 2))
    return [(i, j) for i, j in itertools.combinations(range(len(verts)), 2)
            if abs(d2(verts[i], verts[j]) - m) < tol]


# -- polytopes ------------------------------------------------------------------------------
def e8_roots():
    out = []
    for i, j in itertools.combinations(range(8), 2):
        for si, sj in itertools.product((-1.0, 1.0), repeat=2):
            v = [0.0] * 8
            v[i], v[j] = si, sj
            out.append(v)
    for s in itertools.product((-0.5, 0.5), repeat=8):
        if sum(1 for x in s if x < 0) % 2 == 0:
            out.append(list(s))
    return out


def e8_simple():
    e = lambda i: [1.0 if k == i else 0.0 for k in range(8)]
    sub = lambda a, b: [x - y for x, y in zip(a, b)]
    s = [[0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5],
         [x + y for x, y in zip(e(0), e(1))]]
    s += [sub(e(k + 1), e(k)) for k in range(6)]
    return s


def cell600():
    out = set()
    for i in range(4):
        for sgn in (-1.0, 1.0):
            v = [0.0] * 4
            v[i] = sgn
            out.add(tuple(v))
    out |= set(itertools.product((-0.5, 0.5), repeat=4))
    for signs in itertools.product((-1, 1), repeat=3):
        base = (signs[0] * PHI / 2, signs[1] * 0.5, signs[2] / (2 * PHI), 0.0)
        for p in itertools.permutations(range(4)):
            if sum(1 for a, b in itertools.combinations(p, 2) if a > b) % 2 == 0:
                out.add(tuple(base[k] for k in p))
    return [list(v) for v in sorted(out)]


def h4_simple(roots):
    """Find 4 roots with the H4 Coxeter diagram (5-3-3): dots -cos(pi/5), -1/2, -1/2."""
    c5, c3 = -math.cos(math.pi / 5), -0.5
    near = lambda x, y: abs(x - y) < 1e-6
    a1 = roots[0]
    for a2 in roots:
        if not near(dot(a1, a2), c5):
            continue
        for a3 in roots:
            if not (near(dot(a2, a3), c3) and near(dot(a1, a3), 0)):
                continue
            for a4 in roots:
                if near(dot(a3, a4), c3) and near(dot(a1, a4), 0) and near(dot(a2, a4), 0):
                    return [a1, a2, a3, a4]
    sys.exit("H4 simple roots not found")


def cell24():
    out = []
    for i, j in itertools.combinations(range(4), 2):
        for si, sj in itertools.product((-1.0, 1.0), repeat=2):
            v = [0.0] * 4
            v[i], v[j] = si, sj
            out.append(v)
    return out


# -- SVG helpers ------------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h, pal, title):
        self.w, self.h, self.pal = w, h, pal
        self.items = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
                      f'width="{w}" height="{h}" role="img" aria-labelledby="t">',
                      f'<title id="t">{title}</title>',
                      f'<rect width="{w}" height="{h}" fill="{pal["BG"]}"/>']

    def add(self, s):
        self.items.append(s)

    def svg(self):
        return "\n".join(self.items + ["</svg>"])


def fit(pts, cx, cy, radius):
    """Uniform scale + translate so the points fit a circle of `radius` around (cx, cy)."""
    r = max(math.hypot(x, y) for x, y in pts) or 1
    k = radius / r
    return [(cx + x * k, cy - y * k) for x, y in pts]


def wire(cv, P, E, depth, near, far, wmin, wmax, omin, omax):
    """Edges sorted far -> near; width, opacity and colour follow depth (0 near, 1 far)."""
    items = []
    for i, j in E:
        t = (depth[i] + depth[j]) / 2
        items.append((t, f'<line x1="{P[i][0]:.1f}" y1="{P[i][1]:.1f}" x2="{P[j][0]:.1f}" '
                         f'y2="{P[j][1]:.1f}" stroke="{mix(near, far, t)}" '
                         f'stroke-width="{wmin + (wmax - wmin) * (1 - t):.2f}" '
                         f'stroke-opacity="{omin + (omax - omin) * (1 - t):.2f}"/>'))
    items.sort(key=lambda it: -it[0])
    cv.add('<g stroke-linecap="round">')
    for _, s in items:
        cv.add(s)
    cv.add("</g>")


def norm_depth(vals):
    lo, hi = min(vals), max(vals)
    return [(v - lo) / (hi - lo) if hi - lo > 1e-12 else 0.0 for v in vals]


def halo(cv, cx, cy, r, color, steps=6, opacity=0.05):
    """Soft glow behind the focal figure, as concentric circles (no blur filter)."""
    for k in range(steps, 0, -1):
        cv.add(f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r * k / steps:.0f}" fill="{color}" '
               f'fill-opacity="{opacity:.3f}"/>')


# -- designs ----------------------------------------------------------------------------------
def d_e8(cv):
    pal, w, h = cv.pal, cv.w, cv.h
    V = e8_roots()
    E = [(i, j) for i, j in itertools.combinations(range(len(V)), 2) if abs(dot(V[i], V[j]) - 1) < 1e-9]
    a, b = coxeter_plane(e8_simple(), 30)
    pts = [(dot(v, a), dot(v, b)) for v in V]
    cx, cy, R = w * 0.5, h * 0.5, h * 0.46
    P = fit(pts, cx, cy, R)
    depth = norm_depth([-math.hypot(x, y) for x, y in pts])      # outer rings = near
    halo(cv, cx, cy, R * 1.08, pal["SURFACE"], 7, 0.045)
    wire(cv, P, E, depth, pal["ACCENT2"], pal["SURFACE"], 0.35, 0.9, 0.10, 0.42)
    rings = sorted({round(math.hypot(x - cx, y - cy), 1) for x, y in P})
    for (x, y), t in zip(P, depth):
        cv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{1.6 + 2.2 * (1 - t):.1f}" '
               f'fill="{mix(pal["FG"], pal["ACCENT"], t)}" fill-opacity="{0.35 + 0.5 * (1 - t):.2f}"/>')
    return f"Gosset 4_21 polytope (E8 roots), 240 vertices, {len(E)} edges, Coxeter plane, {len(rings)} rings"


def d_h4(cv):
    pal, w, h = cv.pal, cv.w, cv.h
    V = cell600()
    E = min_edges(V)
    a, b = coxeter_plane(h4_simple(V), 30)
    pts = [(dot(v, a), dot(v, b)) for v in V]
    cx, cy, R = w * 0.64, h * 0.5, h * 0.44
    P = fit(pts, cx, cy, R)
    depth = norm_depth([-math.hypot(x, y) for x, y in pts])
    halo(cv, cx, cy, R * 1.1, pal["SURFACE"], 6, 0.05)
    wire(cv, P, E, depth, pal["ACCENT"], pal["SURFACE"], 0.6, 1.8, 0.18, 0.75)
    for (x, y), t in zip(P, depth):
        cv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{2.2 + 3.5 * (1 - t):.1f}" fill="{mix(pal["ACCENT2"], pal["MUTED"], t)}"/>')
    return f"600-cell, 120 vertices, {len(E)} edges, H4 Coxeter plane (30-gon Petrie polygon)"


def rot4(v, a, b):
    """Double rotation: angle a in the xw plane, b in the yz plane."""
    x, y, z, w_ = v
    x, w_ = math.cos(a) * x - math.sin(a) * w_, math.sin(a) * x + math.cos(a) * w_
    y, z = math.cos(b) * y - math.sin(b) * z, math.sin(b) * y + math.cos(b) * z
    return [x, y, z, w_]


def view3(p, ay=0.55, ax=-0.42):
    x, y, z = p
    x, z = math.cos(ay) * x + math.sin(ay) * z, -math.sin(ay) * x + math.cos(ay) * z
    y, z = math.cos(ax) * y - math.sin(ax) * z, math.sin(ax) * y + math.cos(ax) * z
    return x, y, z


def stereo(v):
    x, y, z, w_ = v
    k = 1 / (1 - w_)
    return x * k, y * k, z * k


def arc_points(V, E, n):
    for i, j in E:
        p, q = V[i], V[j]
        om = math.acos(max(-1.0, min(1.0, dot(p, q))))
        for k in range(n + 1):
            t = k / n
            s1, s2 = math.sin((1 - t) * om) / math.sin(om), math.sin(t * om) / math.sin(om)
            yield [s1 * x + s2 * y for x, y in zip(p, q)]


def d_stereo(cv):
    pal, w, h = cv.pal, cv.w, cv.h
    V = [[c / math.sqrt(2) for c in v] for v in cell24()]       # on the unit 3-sphere
    E = min_edges(V)
    # standard coordinates: no vertex at the pole (w = 1); a search over double rotations
    # found none keeping the arcs farther from it, so the figure stays compact as is
    arcs = []
    for e_ in E:
        arcs.append([view3(stereo(p), 0.5, -0.35) for p in arc_points(V, [e_], 48)])
    flat = [(x, y) for arc in arcs for x, y, _ in arc]
    r = max(math.hypot(x, y) for x, y in flat)
    cx, cy, R = w * 0.5, h * 0.5, h * 0.47
    k = R / r
    zs = [z for arc in arcs for _, _, z in arc]
    zlo, zhi = min(zs), max(zs)
    halo(cv, cx, cy, R * 1.1, pal["SURFACE"], 6, 0.045)
    items = []
    for arc in arcs:
        t = 1 - (sum(z for *_, z in arc) / len(arc) - zlo) / (zhi - zlo)   # far = 1
        d = "M" + " L".join(f"{cx + x * k:.1f},{cy - y * k:.1f}" for x, y, _ in arc)
        items.append((t, f'<path d="{d}" fill="none" stroke="{mix(pal["ACCENT2"], pal["SURFACE"], t)}" '
                         f'stroke-width="{0.9 + 2.8 * (1 - t):.2f}" stroke-opacity="{0.25 + 0.65 * (1 - t):.2f}"/>'))
    items.sort(key=lambda it: -it[0])
    cv.add('<g stroke-linecap="round" stroke-linejoin="round">')
    for _, s in items:
        cv.add(s)
    cv.add("</g>")
    for v in V:
        x, y, z = view3(stereo(v), 0.5, -0.35)
        t = 1 - (z - zlo) / (zhi - zlo)
        cv.add(f'<circle cx="{cx + x * k:.1f}" cy="{cy - y * k:.1f}" r="{3.5 + 6 * (1 - t):.1f}" '
               f'fill="{mix(pal["ACCENT"], pal["MUTED"], t)}"/>')
    return f"24-cell, 24 vertices, {len(E)} edges, stereographic projection from the 3-sphere"


def d_hopf(cv):
    pal, w, h = cv.pal, cv.w, cv.h
    # eta = latitude on S2 (as an angle of S3), each ring gives one torus of Villarceau circles
    rings = [(0.30, 10), (0.50, 16), (0.70, 22), (0.88, 28)]
    cols = [pal["ACCENT2"], pal["ACCENT"], pal["FG"], pal["MUTED"]]
    curves = []
    for (eta, n), col in zip(rings, cols):
        for m in range(n):
            xi = 2 * math.pi * m / n
            pts = []
            for k in range(181):
                t = 2 * math.pi * k / 180
                q = [math.cos(eta) * math.cos(t + xi), math.cos(eta) * math.sin(t + xi),
                     math.sin(eta) * math.cos(t), math.sin(eta) * math.sin(t)]
                pts.append(view3(stereo(q), 0.0, -1.05))
            curves.append((col, pts))
    flat = [(x, y) for _, c in curves for x, y, _ in c]
    xs, ys = [p[0] for p in flat], [p[1] for p in flat]
    mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    k = min(w * 0.80 / (max(xs) - min(xs)), h * 0.84 / (max(ys) - min(ys)))
    cx, cy = w * 0.5, h * 0.5
    halo(cv, cx, cy, h * 0.5, pal["SURFACE"], 6, 0.04)
    cv.add('<g fill="none" stroke-linecap="round">')
    segs = []
    zs = [z for _, c in curves for *_, z in c]
    zlo, zhi = min(zs), max(zs)
    for col, c in curves:
        for p, q in zip(c, c[1:]):
            t = 1 - ((p[2] + q[2]) / 2 - zlo) / (zhi - zlo)
            segs.append((t, f'<line x1="{cx + (p[0] - mx) * k:.1f}" y1="{cy - (p[1] - my) * k:.1f}" '
                            f'x2="{cx + (q[0] - mx) * k:.1f}" y2="{cy - (q[1] - my) * k:.1f}" '
                            f'stroke="{mix(col, pal["BG"], 0.10 + 0.60 * t)}" stroke-width="{0.8 + 2.0 * (1 - t):.2f}"/>'))
    segs.sort(key=lambda it: -it[0])
    for _, s in segs:
        cv.add(s)
    cv.add("</g>")
    return f"Hopf fibration, {len(curves)} fibres over {len(rings)} latitude rings of S2, stereographic projection"


def d_penrose(cv):
    pal, w, h = cv.pal, cv.w, cv.h
    e = [(math.cos(2 * math.pi * j / 5), math.sin(2 * math.pi * j / 5)) for j in range(5)]
    gamma = [0.2] * 5                                            # sum is an integer: Penrose
    N = 9
    tiles = {}
    for r, s in itertools.combinations(range(5), 2):
        det = e[r][0] * e[s][1] - e[r][1] * e[s][0]
        for kr in range(-N, N + 1):
            for ks in range(-N, N + 1):
                br, bs = kr - gamma[r], ks - gamma[s]
                zx = (br * e[s][1] - bs * e[r][1]) / det
                zy = (bs * e[r][0] - br * e[s][0]) / det
                K = [math.ceil(zx * e[j][0] + zy * e[j][1] + gamma[j]) for j in range(5)]
                quad = []
                for dr, ds in ((0, 0), (1, 0), (1, 1), (0, 1)):
                    K[r], K[s] = kr + dr, ks + ds
                    quad.append((sum(K[j] * e[j][0] for j in range(5)), sum(K[j] * e[j][1] for j in range(5))))
                key = tuple(sorted((round(x, 6), round(y, 6)) for x, y in quad))
                tiles[key] = (quad, (s - r) % 5 in (1, 4))
    edge = h / 12.5                                               # rhomb side in pixels
    cx, cy = w * 0.34, h * 0.52
    rmax = w * 0.62
    cv.add('<g stroke-linejoin="round">')
    for quad, thick in tiles.values():
        P = [(cx + x * edge, cy - y * edge) for x, y in quad]
        mxp, myp = sum(p[0] for p in P) / 4, sum(p[1] for p in P) / 4
        d = math.hypot(mxp - cx, myp - cy)
        if d > rmax or not (-edge < mxp < w + edge and -edge < myp < h + edge):
            continue
        fade = max(0.0, 1 - d / rmax)
        fill = pal["SURFACE"] if thick else pal["ACCENT"]
        cv.add(f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in P)}" fill="{fill}" '
               f'fill-opacity="{(0.03 if thick else 0.05) + (0.42 if thick else 0.55) * fade ** 2.2:.3f}" '
               f'stroke="{pal["ACCENT2"]}" stroke-opacity="{0.03 + 0.45 * fade ** 2.5:.3f}" stroke-width="1.4"/>')
    cv.add("</g>")
    return "Penrose P3 rhomb tiling (thick and thin rhombs) from de Bruijn's pentagrid"


def d_kali(cv):
    pal, w, h = cv.pal, cv.w, cv.h
    V = [list(v) for v in itertools.product((-1.0, 1.0), repeat=5)]
    E = min_edges(V)
    step = math.pi / 5                                           # B5 Coxeter plane (10-fold)
    pts = [(sum(v[i] * math.cos(i * step) for i in range(5)), sum(v[i] * math.sin(i * step) for i in range(5)))
           for v in V]
    cx, cy, R = w * 0.70, h * 0.45, h * 0.40
    P = fit(pts, cx, cy, R)
    depth = norm_depth([-math.hypot(x, y) for x, y in pts])
    halo(cv, cx, cy, R * 1.12, pal["SURFACE"], 6, 0.05)
    wire(cv, P, E, depth, pal["ACCENT2"], pal["SURFACE"], 0.8, 2.4, 0.2, 0.8)
    for (x, y), t in zip(P, depth):
        cv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{2.5 + 4 * (1 - t):.1f}" fill="{mix(pal["ACCENT"], pal["MUTED"], t)}"/>')
    # the Kali zsh prompt: data drawn by the wallpaper, written as escapes (ASCII source)
    fs = round(h / 26)
    x0, y0 = round(w * 0.07), round(h * 0.76)
    font = "JetBrainsMono Nerd Font, JetBrains Mono, DejaVu Sans Mono, monospace"
    l1 = ("\u250c\u2500\u2500(", "kali\u327fkali", ")-[", "~", "]")
    c1 = (pal["ACCENT"], pal["ACCENT2"], pal["ACCENT"], pal["FG"], pal["ACCENT"])
    cv.add(f'<g font-family="{font}" font-size="{fs}" font-weight="bold">')
    cv.add(f'<text x="{x0}" y="{y0}">' + "".join(f'<tspan fill="{c}">{s}</tspan>' for s, c in zip(l1, c1)) + "</text>")
    cv.add(f'<text x="{x0}" y="{y0 + round(fs * 1.3)}"><tspan fill="{pal["ACCENT"]}">\u2514\u2500</tspan>'
           f'<tspan fill="{pal["ACCENT2"]}">$ </tspan></text>')
    cv.add(f'<rect x="{x0 + round(fs * 2.45)}" y="{y0 + round(fs * 0.45)}" width="{round(fs * 0.6)}" '
           f'height="{round(fs * 1.05)}" fill="{pal["FG"]}" fill-opacity="0.8"/>')
    cv.add("</g>")
    return f"5-cube (penteract), 32 vertices, {len(E)} edges, B5 Coxeter plane, with the Kali shell prompt"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--theme")
    ap.add_argument("--design", choices=DESIGNS)
    ap.add_argument("--size", default="2560x1440")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        print("\n".join(DESIGNS))
        return
    if not (a.theme and a.design):
        ap.error("--theme and --design are required")
    m = re.fullmatch(r"(\d{3,5})x(\d{3,5})", a.size)
    if not m:
        ap.error("--size must be WIDTHxHEIGHT")
    w, h = int(m[1]), int(m[2])
    pal = load_theme(a.theme)
    cv = Canvas(w, h, pal, "")
    title = globals()["d_" + a.design](cv)
    cv.items[1] = f'<title id="t">okoko wallpaper: {title}</title>'
    sys.stdout.write(cv.svg() + "\n")


if __name__ == "__main__":
    main()
