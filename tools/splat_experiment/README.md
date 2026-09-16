# Hybrid environment splat experiments

The active prototype now covers **Lake Pier and Simons Rocks**. See the [latest edge cleanup and inspection comparisons](../../docs/GAUSSIAN_SPLAT_EDGES.md). The [latest refinement](../../docs/GAUSSIAN_SPLAT_REFINEMENT.md) fixes disappearing splats, rebakes Simons from HDR lighting, and connects Lake Pier’s rear platform. See [location results and comparisons](../../docs/GAUSSIAN_SPLAT_LOCATIONS.md). Launch it with:

```bash
./tools/splat_experiment/run.sh
./tools/splat_experiment/run.sh --location=simons_town_rocks
```

Press **1 / 2** to switch locations, **B** to compare with splats disabled, WASD to walk, right mouse to look, R to reset, **L** to compare old/HDR lighting at Simons, and P to save a screenshot and camera pose. Existing mesh floors, barriers, fittings and Simons rock cards remain. The distant panorama and animated shader water supply the background. This remains an isolated desktop viewer.

## Archived Gray Pier experiment

The original Marble 1.1 world was generated from the existing CC0 Gray Pier panorama on 16 September 2026. See [measured results](../../docs/GAUSSIAN_SPLAT_TEST.md). Gray Pier is no longer the target of refinement. Launch its archived viewer:

```bash
./tools/splat_experiment/run.sh --location=gray_pier
```

Its default is the cleaned hybrid: 53,204 nearby splats, a panorama sphere, animated shader water, and the existing dock mesh with walkable collision. WASD walks, right mouse looks, R resets, F toggles the orange test object, T toggles water, and P saves a uniquely named screenshot plus a JSON camera pose in the viewer directory. See [hybrid results](../../docs/GAUSSIAN_SPLAT_HYBRID.md).

```bash
./tools/splat_experiment/run.sh --mode=hybrid
./tools/splat_experiment/run.sh --mode=panorama # same mesh/water, no splats
./tools/splat_experiment/run.sh --mode=full     # original 500k, matched scale
./tools/splat_experiment/run.sh --asset=gray_pier_100k.ply # original free-camera viewer
./tools/splat_experiment/run.sh --asset=gray_pier_500k.ply
```

The original viewer uses WASD and Q/E for free movement. All modes are desktop experiments; no VR locomotion was added.

All generated assets, API metadata, renderer dependencies, import caches and the standalone Godot project are in `test-results/splat-experiment/` (git-ignored). Original game scenes and renderer settings are untouched. Screenshots and compact metrics are retained in `docs/splats/`. The API key is not stored in the repository.

## Reproduction

1. Prepare `test-results/splat-experiment/gray_pier_pano.png`: in Blender load `assets/environment/locations/gray_pier_8k.hdr`, resize to 4096 × 2048, save PNG through `image.save_render` using an AgX scene. The test used Blender 5.2.1.
2. Configure `WLT_API_KEY` or a permissions-600 file `/tmp/worldlabs-api-key`. API credits are separate from a Marble web subscription.
3. `python3 tools/splat_experiment/marble.py submit` uploads the image and submits **one paid generation**. Existing operation metadata prevents duplicate requests. An ambiguous submission failure leaves a marker requiring dashboard verification; do not delete it and blindly resubmit.
4. `python3 tools/splat_experiment/marble.py status` polls once. When ready, `python3 tools/splat_experiment/marble.py download` retrieves the outputs. Downloads contain private asset URLs in metadata: leave those files in the ignored experiment directory.
5. `python3 tools/splat_experiment/setup.py` prepares the project and fetches the pinned MIT GDGS addon if absent. It copies the installed Godot MCP addon and game water shader/panorama for the test.
6. Convert the two tested variants:

```bash
python3 tools/splat_experiment/spz_to_ply.py test-results/splat-experiment/gray_pier_100k.spz test-results/splat-experiment/viewer/gray_pier_100k.ply
python3 tools/splat_experiment/spz_to_ply.py test-results/splat-experiment/gray_pier_500k.spz test-results/splat-experiment/viewer/gray_pier_500k.ply
```

7. Open the viewer in Godot 4.7.2 and allow asset import to finish before playing. Importing 500k points can occupy the editor for over a minute on this machine. The converter preserves source axes; the viewer applies Marble's OpenCV-to-OpenGL Y/Z flip and restores GDGS's removed center.
8. Run the viewer. For repeatable desktop measurements, close any other running game window and use `python3 tools/splat_experiment/benchmark.py gray_pier_500k.ply` (or `gray_pier_100k.ply`). Reports and screenshots are written inside the viewer directory.

`python3 tools/splat_experiment/test_spz.py` checks signed position decoding, quaternion packing, SH channel ordering and truncated input rejection. The converter intentionally supports only legacy v2/v3 SPZ without extensions and SH degree up to 3. Both tested Marble files were v2, degree 0.

The generated world uses source units; metric-scale and ground-offset metadata are recorded in the downloaded world JSON but have not been calibrated against a measured scene. Water height is an experimental setting. These exports are not approved as final gameplay collision or standalone-headset assets.

## Local hybrid cleanup (no API calls)

After converting the 500k export, run the deterministic cleanup in Blender's Python (NumPy included):

```bash
/home/blux/blender-5.2.1-linux-x64/blender --background --python tools/splat_experiment/prepare_hybrid.py
python3 tools/splat_experiment/setup.py
```

Open the isolated viewer project and wait for imports. Then close the running inspection game and benchmark each mode separately:

```bash
python3 tools/splat_experiment/benchmark.py gray_pier_500k.ply --mode full
python3 tools/splat_experiment/benchmark.py gray_pier_500k.ply --mode hybrid
python3 tools/splat_experiment/benchmark.py gray_pier_500k.ply --mode panorama
```

These three modes use a matching camera path, 120 warmup frames and 600 sampled frames. Reports include wall-clock frame intervals, GPU timestamps and Godot memory counters. Captures happen after timing. Hybrid/panorama runs also check three authored floor areas and a side barrier. The mask follows the three manifest floor footprints and excludes each splat’s conservative 4.25-sigma support plus 15 cm. A further 60 cm fade softens the outside edge. The original shore cutouts and ground cover are retained, and the bank apron is reshaped only beyond a half-metre protected border. The source PLY is never overwritten; cropping and alpha fades are written to `gray_pier_near.ply`. Thresholds are specific to this scene, not a general automatic water classifier.

The current visual refinement uses a lake-bounded, opaque variant of the water shader (the standalone viewer has no underwater-fish window). Water and distant-terrain edge colors are matched to the finite panorama sphere. `review_saved_views()` replays the seven captured artifact poses retained in the local viewer, saves `review_*.png`, and writes collision/decoration checks to `review_checks.json`; it requires those local inspection JSONs. See [visual comparisons](../../docs/GAUSSIAN_SPLAT_VISUAL_REVIEW.md).
