# Resume development

Current milestone: Real AI Fishing 0.1.0, Godot 4.7.2, Mobile/Vulkan.

The game has eighteen fish species, fourteen per location, four baked foregrounds,
four native 4K panoramas, six baits, rod progression, a handheld Guide with photos,
VRM avatars and tracking, eight-player ENet multiplayer and positional voice.
See [README](README.md) for controls and feature documentation.

Run `./run.sh --desktop` for desktop practice, `./run.sh` with an active OpenXR
runtime for PC VR, or `./run.sh --server` for a dedicated server. Set `GODOT_BIN`
to the Godot executable if the local fallback is unavailable.

## Release cleanup

See [cleanup notes](docs/CLEANUP.md) and [release instructions](docs/RELEASE.md).
Current editable Blender sources, original textures, recordings and license
records are retained under `source/`, excluded from Godot import. Native 4K HDR
originals have one canonical copy under `assets/environment/locations/`.
Docs images are also excluded from import. Generated raw XR captures belong in
ignored `test-results/xr/`. Superseded procedural fish and unlit runtime scenery
were retired; the location manifest points directly at the baked models.

Release signing files live in ignored `.release-signing/` and must remain private.
Build output, Gradle files, Godot caches and player saves are not source assets.
Use `tools/build_release.py` and `tools/package_release.py` for all four targets.

## Remaining work

- Physical Quest/Pico and Windows runtime acceptance, microphone and tracker
  hardware validation, comfort and sustained performance measurements.
- Existing Godot/OpenXR teardown diagnostics are recorded in
  [validation notes](docs/VALIDATION.md); synthetic passes do not establish
  physical headset comfort or performance.
- Gaussian splatting remains an assessment: see
  [renderer audit and experiment gates](docs/GAUSSIAN_SPLATTING.md). Both
  shortlisted paths need independent Guide/selfie camera sorting. No renderer
  or scan is integrated.
- Fish skeletal animation, rod bending and richer ecology remain future work.
