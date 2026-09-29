#!/usr/bin/env python3
"""Build an offline gallery from the Godot-rendered overview/detail images."""
import json,html
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/minigolf-gallery'
NOTES={
'lakeside':'Warm shore pebbles, dry grasses and weathered timber.',
'lake_pier':'Iron bollards, rope-wrapped posts and channel markers with cool quay colours.',
'gray_pier':'Cattails and reed beds with grey, weathered boardwalk timber.',
'bell_park_pier':'Regatta boats, channel markers and reservoir grasses.',
'simons_town_rocks':'Rounded coastal granite and sandy shell pockets.',
'blouberg_sunrise_2':'Dune grass, pale driftwood and warm sand accents.',
'secluded_beach':'Granite shoulders, bleached branches and sheltered sandy planting beds.',
'fish_hoek_beach':'Bleached driftwood, beach grass and cool pale sand.',
'meadow_bend':'Flowering meadow grasses and warm river pebbles.',
'boulder_run':'Granite clusters, wet-stone colours and river-margin planting.',
'cedar_creek':'Mossy cedar, fern fronds and shaded woodland colours.',
'glacier_run':'Snow-capped granite, pale stone and cold alpine colours.'}
cards=[];links=[]
for key,note in NOTES.items():
 data=json.loads((ROOT/'assets/minigolf/courses'/f'{key}.json').read_text())
 title=key.replace('_',' ').title().replace('Blouberg Sunrise 2','Blouberg')
 images=''.join(f'<a href="after/{key}-{view}.png" target="_blank"><img loading="lazy" src="after/{key}-{view}.png" alt="{html.escape(title)} {view}"><span>{view.title()} · Open full size</span></a>' for view in ['overview','detail'])
 cards.append(f'<article id="{key}" data-name="{title.lower()}"><header><h2>{title}</h2><p class="course">{html.escape(data["name"])}</p><p>{note}</p></header><div class="pictures">{images}</div></article>')
 links.append(f'| {title} | [Overview](after/{key}-overview.png) | [Detail](after/{key}-detail.png) |')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Waterfront minigolf — course previews</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101e20;color:#e7e8df;font:16px/1.55 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:35px 24px}h1{font-size:clamp(28px,4vw,48px);margin:8px 0}h2{margin:0;font-size:25px}p{max-width:900px;color:#bbc8bd}.eyebrow{letter-spacing:.18em;text-transform:uppercase;color:#d7bd86;font-size:13px}input{width:min(100%,420px);padding:12px 16px;margin:16px 0 28px;background:#213331;border:1px solid #69816f;border-radius:6px;color:white;font:inherit}article{border:1px solid #344a42;border-radius:10px;overflow:hidden;margin:0 0 28px;background:#192b29}header{padding:22px 26px}header p{margin:5px 0}.course{color:#d7bd86}.pictures{display:grid;grid-template-columns:1fr 1fr;gap:2px}a{color:#d7bd86;text-decoration:none}img{display:block;width:100%;aspect-ratio:1.6;object-fit:contain;background:#0c1718}a span{display:block;padding:9px 18px;font-size:13px}@media(max-width:750px){.pictures{grid-template-columns:1fr}}[hidden]{display:none!important}</style>
<main><div class="eyebrow">Ultimate Boomer Simulator · Art review</div><h1>Waterfront minigolf</h1><p>12 locations · 18 holes each. Overview and detail renders of the revised course decorations, using each water’s panorama, sun preset and the game’s sky lighting. The preview includes the modeled shoreline and uses a simplified water plane. Boats appear only at offshore sites; other players are omitted.</p><label for="filter">Find a location</label><br><input id="filter" type="search" placeholder="Search lakes, beaches or rivers…" autocomplete="off">'''+''.join(cards)+'''<p>Original props authored through Blender MCP. Wood and stone textures painted through Krita MCP. Open any image for its full-resolution PNG.</p></main><script>document.getElementById('filter').addEventListener('input',e=>document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.name.includes(e.target.value.toLowerCase())));</script></html>'''
OUT.mkdir(parents=True,exist_ok=True);(OUT/'index.html').write_text(page)
(OUT/'PREVIEWS.md').write_text('# Minigolf location previews\n\n'+ '\n'.join(['| Location | Course | Decorations |','|---|---|---|']+links)+'\n')
print(OUT/'index.html')
