# Session feedback fixes — 14 September 2026

The Linux debug build is in `builds/Debug-SessionFeedback/`. No server change or new public release was made.

## Fishing

- Tension increases at most 14 percentage points per second. Sustained overload gets a 2.5-second starter-line grace period, increasing with line durability. Haptics start at 60% tension and repeat increasingly quickly toward maximum strain.
- A missed counter restores 18 percentage points of fish stamina (capped at 100%). It does not directly raise or release tension. Three missed counters still lose the fish. Successful input also eases tension gradually instead of clamping it immediately to 85%.
- Ending a counter preserves the fish’s final position and rebases retrieval distance/direction. Later counters start from that position, and repeated runs accumulate.
- Upward counters accept an already raised rod or a 12 cm lift, with hysteresis for small hand movements. Correct input must still be sustained to finish the counter.
- A lost fish automatically resets the rod after 1.2 seconds. Trigger-and-swing casting can rearm immediately; cast/reel/counter state is cleared on loss.
- An uncast rod carries a hanging float and the selected bait. Bait changes show a short text label above the rod. Text uses the photo-excluded UI layer.
- All six baits have distinct 3D silhouettes, materials, and hook details: curved segmented worm, yellow corn kernels, reflective spinner and treble hook, short cream maggots, bread with crust/crumb, feathered fly with hackle and tail.

## Avatar and tracking parity

Compared against local FPSloppa commit `8898d03a33f42e6eec472506fccce6d68dad83d1`. Skinned rest bounds and model-aware hip/ankle offsets were already ported; their normalization is retained. Shared constants now define the 1.70 m cosmetic body and 1.65 m tracked head reference. Models retain authored proportions rather than stretching individual bones to resemble another avatar.

The missing FPSloppa startup height calibration is implemented. It runs once when head tracking/focus are available; crouching and avatar changes do not recalibrate scale. Seated mode applies an offset, and T-pose calibration first recenters the player. Tests cover 1.2, 1.65 and 2.1 m physical heights, tiny/giant model units, planted feet, and lifted ankles. This does not constitute physical headset confirmation of every avatar.

In VR, the rod now attaches to the solved right hand, including on remote avatars. The attachment is captured while skeleton modifiers are applied; controller targets remain independent of the rod. It reverses the IK wrist/grip offset and axes, strips VRM scale, and updates the line and hanging tackle after the solve. Unreachable controllers cannot pull the handle out of the avatar's palm. Holstering overrides the attachment and retrieval restores it immediately. Desktop controls remain the avatar's input. Protocol 2 has no explicit folded flag, so remote folding now requires the belt's exact downward orientation in the hip region rather than any separation from the tracked controller.

## Networking

FPSloppa's worker queue for immutable disk jobs/main-thread completions remains in use. The inspected FPSloppa version does **not** run ENet on a separate thread. The new fishing-specific `threaded_peer.gd` owns ENet on one worker, with bounded packet/event queues. Polling and acknowledgements continue during scene-thread stalls; RPC callbacks and gameplay stay on the main thread. Closing/leaving and scene teardown stop/join workers. Seven channels remain compatible with stock ENet; the subsequent radio addition requires application protocol 3.

FPSloppa's decoded-avatar cache pattern avoids decoding the same remote VRM repeatedly. Local import hashing/copying and PNG compression/writes also run through a disk worker.

## Files

Local imports and downloaded VRMs share `data/vrm/` beside the desktop executable (project `data/vrm/` in editor; app external files on Android). `--asset-root PATH` overrides the data root. Legacy `user://avatars/` and `user://network_avatars/` files are copied without deleting originals, and selected-avatar paths migrate. The VRM browser includes a folder shortcut.

Photos save to the OS Pictures folder under `Real AI Fishing`. Android uses MediaStore to create its own Pictures entries, following [Android shared-media guidance](https://developer.android.com/training/data-storage/shared/media) through the [Godot AndroidRuntime/JNI bridge](https://docs.godotengine.org/en/stable/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html). Android device validation remains outstanding. Desktop tests use `--photos-root PATH` for isolation. User data and docs remain excluded from exported packs.

## Validation

- Regression coverage and latest per-suite results: `test-results/live-analytics/regression-summary.json`.
- New fishing/height tests, all six modeled bait types, legacy storage migration, actual PNG write/readback, existing VRM/IK regressions, menu controls, and six exit/restart persistence cases passed.
- `rod_attachment` exercises all three bundled VRMs with reachable, extended, raised and behind-body controller targets, translated/turned player placement, independent controller motion between solves, optional missing index bones, holstering/retrieval, and remote hand/line attachment.
- Actual dedicated and ad-hoc ENet sessions passed voice decoding, avatar transfer, pose/catch replication, and location filtering.
- Transport tests show packet reception during a 400 ms main-thread stall, preserved reliable order, stock ENet compatibility, correct routing, main-thread callbacks, and joined worker teardown.
- Desktop renders verified the float, bait, popup, six-bait gallery, and 1920×1080 photo save. Images are in `test-results/live-analytics/ready-rod.png` and `bait-types.png`.
- Linux debug export and exported-executable startup succeeded. Forced headless shutdown/integration tests retain resource-in-use warnings; normal rendered quit completed without script errors.
- No coordinated live headset or standalone Android retest was possible after the reported session ended. The earlier voice-focus fix is included in this debug build.

## Radio, pier water and wildlife — 15 September 2026

- FPSloppa shoulder radio: grab with the left hand and hold trigger, or hold B on desktop. Radio reaches all waters; ordinary voice remains local. Its receive filter/clicks, channel-order guards and microphone-mode handling are ported/adapted from the same FPSloppa revision above. The server and clients must all update to protocol 3.
- Lake Pier’s water surface is lowered from -0.35 m to -0.85 m. Cast anchors, landing visibility checks and floats use the current water height. The shader applies restrained animated reflections only to an authored clear-water region in panorama coordinates, preserving photographed jetties, marker posts and shore elsewhere. The other waters retain their existing surface heights.
- Wildlife now varies in silhouette, material, count, wingbeat, altitude and flight path: Lakeside swallows/butterflies; Lake Pier gulls/no insects; Gray Pier swifts/midge swarms; Bell Park terns with dipping flight/dragonflies. MultiMesh batching and the existing lightweight cosmetic animation approach remain.
- `radio`, `water_wildlife`, existing voice/rod/Guide/menu/pier/location regressions, and independent dedicated/ad-hoc radio sessions passed. Rendered pier views are in `test-results/live-analytics/pier-water-fixed-*.png`; per-water wildlife views are `*-wildlife.png`. No live headset microphone or multiplayer user session was used.
