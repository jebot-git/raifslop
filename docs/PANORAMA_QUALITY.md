# Default 8K panoramas

All four playable locations ship native 8192 × 4096 HDR panoramas. There is one runtime asset set and no panorama-directory override or 4K variant. Menu previews remain small JPEGs. Download URLs, source MD5 and local SHA256 are recorded in [native_8k.json](locations/native_8k.json). Original source pixels are unchanged.

Godot imports the HDRs without lossy texture compression or size reduction, with mipmaps. `scripts/panorama_material.gd` and `shaders/panorama_sampling.gdshaderinc` apply four-neighbour luminance sharpening at strength 0.5, bounded to ±6% overshoot with dark-noise suppression, vibrance 1.025 and a gentle shadow lift of 0.015. The equirectangular sampler wraps longitude and clamps latitude. Lighting cubemaps and softened water reflections omit sharpening; distant-water blending uses the same enhanced sky sample to preserve the transition.

`tests/panorama_quality.gd` captures original and enhanced 8K views for all four locations under `test-results/panorama-8k/`. `tests/locations.gd` checks every loaded panorama is exactly 8192 × 4096. The former 4K assets are retained only under excluded test results as historical references.

On 14 September 2026, `tests/panorama_live.gd` loaded all four locations through WiVRn with the connected headset and both controllers tracked, and captured both eyes. Every short sample reported 72 FPS on the Intel Arc A770, with sharpening enabled. This is a functional smoke test, not a sustained performance benchmark. No shader or game errors occurred. Godot emitted its existing OpenXR shutdown diagnostics (spatial callback disconnect, interaction-profile RID leaks and session-not-stopping), after the test passed.

The Linux debug package is `builds/Debug-8K/RealAIFishing-debug.x86_64`, launched with the system WiVRn OpenXR runtime and no panorama override.

## Panorama wrap-seam correction

The four player photos from 18:16–18:17 on 14 September reproduced a thin vertical/dashed meridian that also distorted water reflections. `tests/panorama_seam.gd` reproduced it with fishing line geometry cleared. The panorama sampler now passes explicit longitude-wrapped derivatives to `textureGrad`, preventing a 0/1 UV boundary from selecting an unrelated coarse mip. This fixes the sampling discontinuity without modifying or blurring the source photographs.

Before/after renders for all four locations are in `test-results/panorama-8k/*-seam-{before,after}.png`. Measured upper-sky centre-strip deviation from adjacent pixels fell from 3.554 to 0.451 levels for Lakeside, 3.089 to 0.609 for Lake Pier, 1.842 to 0.244 for Gray Pier and 0.555 to 0.166 for Bell Park (8-bit display values). These are local seam measurements, not overall image quality scores. WiVRn also rendered all four corrected locations in stereo successfully.
