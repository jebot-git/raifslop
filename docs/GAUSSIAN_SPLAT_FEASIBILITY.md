# Gaussian splat environment feasibility

Research date: 16 September 2026. Repository baseline: `53c956d`.

Follow-up: [one environment has now been generated and tested in Godot](GAUSSIAN_SPLAT_TEST.md). The assessment below records the research preceding that experiment.

Recommendation: evaluate one small shoreline using an existing licensed scan, then compare a world generated from one of our panoramas. Use splats for static scenery, with authored gameplay geometry and animated water. This is a feasibility assessment; no splat was downloaded, generated, rendered, or benchmarked during this research.

## Fit with this project

The project uses Godot 4.7 Mobile/Vulkan and OpenXR, with desktop, Quest and Pico exports. `scripts/main.gd` combines panoramas, foreground GLBs/collisions and a separate water surface. `scripts/locations.gd` supplies location settings; `scripts/shore.gd` loads foreground geometry. This offers a natural integration point for optional splat scenery per location.

Splats could add translational parallax to nearby banks, rocks, trees and buildings. Existing panoramas cannot uniquely recover unseen surfaces or scene depth: generation from them would infer a plausible environment. A photographed reconstruction requires overlapping views from different positions. Simply rendering many rotations of one panorama supplies no new parallax.

## Acquisition options

| Route | Evidence and cost | Assessment |
|---|---|---|
| Download a captured environment | [Lago di Barcis by ethan3111](https://superspl.at/scene/94a939d7) explicitly lists Download, CC BY 4.0 and 164.56 MB. | Best first procurement candidate. Inspect shore coverage and crop before integration; the listing alone does not establish quality or usable walking space. Preserve attribution and identify modifications. |
| Browse other community scenes | [SuperSplat downloadable collection](https://superspl.at/search?features=downloadable) supports per-asset licenses and source/PLY downloads. [Publisher documentation](https://blog.playcanvas.com/new-in-supersplat-downloadable-splats-licenses-and-social-links/) lists six CC variants. | Useful discovery source, but each asset needs its own license check. Prefer CC BY for editable game scenery; a public viewer alone is not a redistribution license. |
| Generate from our panoramas or prompts | Marble accepts panoramas and exports PLY/SPZ and collider meshes. [Export documentation](https://docs.worldlabs.ai/marble/export/gaussian-splat) and [pricing](https://marble.worldlabs.ai/pricing) list Standard at $20/month for exports and Pro at $35/month with commercial rights. | Most direct route to adding depth to our existing visual themes. Generated geometry needs inspection from walking and crouching viewpoints. Budget Pro for a commercial web-app workflow. |
| Automate generation | [Marble API pricing](https://docs.worldlabs.ai/api/pricing): $1 per 1,250 credits, $5 minimum purchase; standard generation from an existing panorama costs 1,500 credits ($1.20), draft 150 ($0.12). API billing is separate. [API outputs](https://docs.worldlabs.ai/api) include 100k, 500k and full-resolution SPZ plus collider GLB. | Useful for later batch experiments. Prices exclude retries and editing; verify API output terms separately from web subscription entitlements. |
| Capture our own location | [Scaniverse](https://www.nianticspatial.com/products/capture) supports phone capture and splat export. [Current pricing](https://www.nianticspatial.com/pricing) includes limited free mobile processing and PLY/SPZ export. | Good for authentic local fishing spots. Do not assume free export includes commercial rights: account terms and intended use need checking. |
| Train locally from photos/video | [Brush](https://github.com/ArthurBrussee/brush) is Apache-2.0, supports Linux and multiple GPU vendors, takes COLMAP/Nerfstudio datasets and supports masks. | Strong open-source route when we can obtain overlapping captures and camera poses. Local training performance has not been measured here. |

A commissioned capture is also possible: request original overlapping imagery, camera poses, editable splats, metric reference dimensions and explicit game redistribution rights. No supplier quote was obtained.

## Rendering and preparation

[GDGS](https://github.com/ReconWorldLab/godot-gaussian-splatting) is MIT licensed. Its Raster backend supports Mobile and advertises VR/multiview; its Compute backend requires Forward+. The project documents limited real-mobile validation and sorting that may lag camera motion. Force Raster for the first experiment. PLY and SOG v2 are supported; SPZ is not listed as a direct input. It can generate collision proxies, but these still need gameplay cleanup.

A separate [Godot 4.7 Quest 3 viewer](https://github.com/Takio0304/godot-quest3-gs-viewer) uses GDGS and documents fixes for backend selection and head-turn sorting stalls. Its claimed 0.5–1 million splat capacity is a viewer author's rule of thumb, not a measured budget for this game or Pico.

Use [SuperSplat](https://superspl.at/editor) to inspect and remove unwanted regions. [splat-transform](https://github.com/playcanvas/splat-transform) converts SPZ to PLY/SOG and supports transforms and filtering. Retain an editable master. Compressed download size is not GPU memory usage, and format conversion alone does not make a scene cheaper to render.

## Proposed experiment and acceptance criteria

1. Obtain Lago di Barcis with its attribution/license record. Inspect coverage, scale, orientation, holes and foreground quality before choosing a fishing position.
2. Crop a compact static shoreline. Prepare several budgets, initially around 100k, 250k and 500k splats; these are experiment sizes, not performance promises.
3. Add an isolated GDGS Raster scene with our rod, fish, avatar, water and simple collision proxies. Keep the panorama for distant scenery and fallback.
4. Remove captured water where practical. Frozen waves/reflections and moving foliage can produce distracting artifacts; retain animated mesh water and validate the join. The current water reflection uses the panorama, so it will not automatically reflect new splat scenery.
5. Inspect both eyes while translating, crouching and turning quickly. Check water/splat transparency ordering, opaque-object occlusion, clipping, line and fish visibility, and the Field Guide camera's additional viewport.
6. Measure CPU/GPU frame time, peak memory, load time and location unloading on PC VR and each target standalone headset. At 72 Hz the entire frame budget is 13.9 ms; at 90 Hz it is 11.1 ms. Test with actual gameplay and thermal warm-up, not just an empty viewer.
7. If the renderer passes, compare a Marble-generated version of an existing panorama against the captured scene. Approve broader adoption only if parallax and visual quality justify the cost and artifacts.

For capture, prioritize a small static bank with rocks, ground and structures, under steady lighting and low wind. Walk through the intended play area and acquire overlapping views at multiple heights. Mask water and moving subjects during reconstruction where possible. Start with bounded fishing positions rather than assuming unrestricted walking through an incomplete scan.
