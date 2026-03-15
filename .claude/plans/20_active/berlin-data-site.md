# berlin.soli.blue - Berlin Open Data Visualization

Minimalistic, visually stunning data visualization site for Berlin's open data. Hosted on Cloudflare Pages. Project lives at `/Users/soli/Desktop/CODING/berlin/`.

## Goals
- Beautiful, icon-driven navigation between data views (Trees, Transit, Air, People)
- Three themes: Light (white), Majorelle (deep navy #0C0F1F), Dark (black)
- Start with the tree visualization (434K street trees from Berlin's Baumkataster)
- Interactive map with clustering, stats bar, click-to-inspect
- Zero backend, static site, no build step beyond optional bundling

## Tech Stack
- Vanilla HTML/CSS/JS, ES modules
- MapLibre GL JS (free, no API key, open source)
- CARTO basemaps (Positron for light, Dark Matter for dark/majorelle)
- Lucide icons from CDN
- CSS custom properties for theme system
- Berlin WFS API for tree data (GeoJSON, no auth)

## Design
```
┌──────────────────────────────────────────────┐
│  berlin.data    🌳 Trees  🚇 Transit  ...  ☀️ │  ← nav
├──────────────────────────────────────────────┤
│                                              │
│              [Interactive Map]               │
│                                              │
├──────────────────────────────────────────────┤
│  434,450 trees  │  Avg 38yr  │  Linden 22%  │  ← stats
└──────────────────────────────────────────────┘
```

## Phase 1 (now): Tree Map
- Fetch trees from WFS with count limit, cluster on map
- Color clusters by density (green gradient)
- Click cluster to zoom, click tree for details popup
- Floating stats bar with totals
- Theme switching (3 themes, cycle with button)

## Phase 2: More data views
- Transit radar (live BVG positions)
- Air quality (15 stations, hourly)
- Demographics (448 LOR micro-areas)

## Files
- `berlin/index.html`
- `berlin/style.css`
- `berlin/main.js`
