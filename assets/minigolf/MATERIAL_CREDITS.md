# Minigolf assets

The putter mesh and its brushed metal, moulded rubber and powdercoat textures are retained original project assets from the archived Golf Minus integration. Those material maps were generated procedurally in Blender by its equipment authoring tools. Driver, iron and clubhouse assets are not included.

The eight waterfront props are original project artwork authored through Blender MCP. Their reproducible source is `source/minigolf/build_props.py`; the meshes use plain material colours and no downloaded textures. The timber deck and turf shaders are original procedural materials.

Water-location scenery, HDR panoramas and ambience retain their existing attribution in the root `ASSET_CREDITS.md`. No Walkabout course layouts, artwork, audio or branding are used.

## Location decoration revision

Eleven additional original low-poly meshes were authored with Blender MCP using `source/minigolf/build_location_props.py`: shore pebbles, coastal granite, bleached driftwood, cattails, meadow grass, dune grass, mossy cedar with fern fronds, snow-capped alpine granite, shell banks, rope-wrapped mooring posts and channel markers. Meshes are joined by material to limit scene nodes and draw calls. Blender source colours are converted from sRGB to linear before export.

`textures/weathered_wood.png` and `textures/shore_stone.png` were painted through Krita MCP. Editable `.kra` originals and replayable drawing command lists are in `source/minigolf/textures/`. The MCP stroke operation currently mishandles nonzero bounding-box origins; the final artwork uses its working line/ellipse drawing operations. The maps add subtle grain and mineral flecks to palette-tinted deck, bank, soil, stone and timber materials. No external textures or new third-party artwork were downloaded.

## Shore shuttle

`shore_ferry.glb` is an original six-seat moored launch authored through Blender MCP from `source/minigolf/build_shore_ferry.py` (406 polygons, seven material meshes). It appears only at Lakeside, Gray Pier and Bell Park, whose course platforms extend over water. Land-based courses have no shuttle. The hull uses original solid-color materials; wooden parts reuse the authored wood texture where applicable.
