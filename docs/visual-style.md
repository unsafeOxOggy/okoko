# okoko - visual style (wallpapers)

Wallpapers are drawn by `lib/wallgen.py` from the active theme, one set per theme
(`okoko-wall`, `Super+q` next, `Super+Shift+q` re-render).

- **Subject**: exact geometry only. Coordinates are computed (root systems, polytope
  vertices, de Bruijn pentagrid), edges are pairs at minimal distance, and the 2D image
  comes from a computed projection: Coxeter plane (E8, H4, B5), stereographic projection
  (24-cell, Hopf fibration). The image is scaled uniformly, never stretched; vertices
  stay circles.
- **Palette (60-30-10)**: `BG` background (60), `SURFACE`/`MUTED` far edges and halo
  (30), `ACCENT`/`ACCENT2`/`FG` near edges and vertices (10, focal point).
- **Depth**: near = thicker, more opaque, accent colour; far = thin, faint, surface
  colour. Drawn far to near.
- **One focal point** per wallpaper (the figure, or the 5-fold centre of the Penrose
  tiling), lots of empty background: windows sit on top of it.
- **Halo**: concentric circles at low opacity, no blur filter, no gradient.
- **Line style**: round caps and joins everywhere; one weight range per design.
- **Text**: only in `kali` (the Kali zsh prompt, JetBrainsMono Nerd Font).

Designs: `e8` (Gosset 4_21, 240 vertices, 6720 edges, 30-fold), `h4` (600-cell, 30-gon
Petrie polygon), `stereo` (24-cell, arcs), `hopf` (Villarceau circles on nested tori),
`penrose` (P3 rhombs), `kali` (5-cube + prompt). Checked on every theme, light
(catppuccin-latte) included.

All figures are original constructions (no third-party artwork); references:
Wikipedia "Coxeter element" (Coxeter plane method), "E8 (mathematics)", "600-cell",
"Penrose tiling" (de Bruijn's pentagrid), "Hopf fibration".
