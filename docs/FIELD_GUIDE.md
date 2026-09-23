# Handheld Field Guide

The current catalogue has 40 species. Pages include habitat, preferred presentation, eligible methods and named waters. See [roster expansion](ROSTER_EXPANSION.md) for the six new entries and their assets.

An original orange-and-green fish catalogue device sits at the VR player's left hip. Reach to its **lower handle** and squeeze **left grip** within 22 cm to pick it up. Lift and rotate your hand to inspect the screen. The grip is 26.5 cm below the device body's centre, keeping the avatar's hand below the screen and navigation controls. Releasing grip or losing controller tracking returns it to the belt; no device can be dropped into the water.

While holding it, use **left X / Y** or **either joystick** to browse unlocked species. Sticks advance one page per deflection; return them to centre before paging again. The casing's buttons are visual features; navigation uses controller inputs. Fishing timers and stick locomotion pause during inspection. The guide has priority over holding a caught fish, which stays hanging on the rod. Physical headset and hand motion still work.

## Collection and records

Each first catch unlocks its common name, scientific name, basic description, a species-specific profile silhouette, and a **personal best length in centimetres**. Only a strictly longer specimen updates that species' record. Equal and smaller catches leave the entry unchanged. Fish weight remains in the catch journal; the guide's size comparison uses length, not weight.

Records are reconstructed from the existing `user://journal.json`, so valid historical catches populate the device automatically. No second competing save file is introduced. Missing scientific names can be matched through a known common name. Unknown species, missing/non-numeric/non-positive lengths and invalid records are ignored. An empty journal can browse all species as unnamed question marks, with a question mark in place of each silhouette. Habitat (Lake, Sea or River) and preferred game bait remain visible. Catching a species reveals its identity in the same catalogue page; undiscovered pages do not count as found. [Current screens and behavior](FISHING_COMFORT.md#guide-discovery-pages). New captures update the device when the game saves the landed catch.

## Graphics and implementation

`scripts/fish_guide.gd` builds the low-poly casing, lower handle, raised screen and decorative navigation buttons. A 640 × 840 SubViewport supplies the display; `fish_guide_screen.gd` lays out the collection. `fish_guide_icons.gd` contains original vector silhouettes for every current species with different body proportions and fin profiles. They are simplified identifying graphics, not anatomical diagrams or scans. All display content is local; no service or asset download is needed during gameplay.

The waist position follows headset position and the tracking origin's facing direction, with a lower height limit for crouching. This is an estimated belt position, not body tracking. The hold transform follows the actual left controller. Reach and screen readability were checked with synthetic controllers; physical headset/controller ergonomics still need validation.

## Species references

Descriptions and identifying silhouettes were authored using the species' basic traits:

- [European perch](https://www.wildlifetrusts.org/wildlife-explorer/freshwater-fish/perch): stripes, spiny back fins and red lower fins.
- [Common carp](https://www.wildlifetrusts.org/wildlife-explorer/freshwater-fish/common-carp): sturdy body, mouth barbels and omnivorous feeding.
- [Northern pike](https://www.wildlifetrusts.org/wildlife-explorer/freshwater-fish/pike): elongated body, broad snout, teeth and ambush hunting.
- [Common roach](https://www.wildlifetrusts.org/wildlife-explorer/freshwater-fish/roach): silver body with red eyes and fins.
- [Tench](https://www.wildlifetrusts.org/wildlife-explorer/freshwater-fish/tench): olive colouring, red eyes and rounded fins.
- [Common bream](https://www.fisheriesireland.ie/fish-species/bream-abramis-brama): flattened deep body, long anal fin and bottom feeding.
- [Zander](https://canalrivertrust.org.uk/things-to-do/fishing/caring-for-our-fish/invasive-and-non-native-fish/zander): double dorsal fin, pale belly and canine teeth.

No reference photographs, external icon sets or existing game branding were copied into the device.

## Verification

Use isolated saves for these tests:

```bash
XDG_DATA_HOME=/tmp/guide-tests godot --path . --xr-mode off --headless --script res://tests/fish_guide.gd -- --xr-test
XDG_DATA_HOME=/tmp/guide-captures godot --path . --xr-mode off --script res://tests/fish_guide.gd -- --xr-test --capture
XR_RUNTIME_JSON=/usr/share/openxr/1/openxr_monado.json SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1 XDG_DATA_HOME=/tmp/guide-xr ./run.sh --script res://tests/fish_guide_xr.gd
```

Captures: [device screen](field_guide_screen.png), [desktop device](field_guide_desktop.png), [VR left eye](locations/field_guide_eye0.png), [VR right eye](locations/field_guide_eye1.png). Synthetic captures use test records to demonstrate the collection. See [validation](VALIDATION.md) for counts and known OpenXR teardown errors.

## Field camera and selfie mode

The guide now includes a live camera preview and saves **1920 × 1080 PNG photos** without the HUD, menus, guide device or multiplayer name labels. Photos use a separate mono camera in the VR player and spectator mirror; the player's normal interface stays intact. Rods, fish, avatars and scenery remain in the photograph.

| Action while holding the guide | VR |
|---|---|
| Switch collection / camera | Left trigger |
| Take photo | Right trigger |
| Toggle selfie camera | Right A |
| Extend / retract selfie camera | Right stick up / down |
| Aim forward camera | Move and rotate left hand |
| Close / dock | Release left grip |

Forward mode follows the guide’s rear lens. VR selfie mode starts at the guide’s front lens and includes the full avatar. Push the right stick up to extend the capture point away from the group, or down to bring it closer. The extension follows the guide’s aiming direction, moves at up to 1 metre per second, and stops at 3 metres beyond the lens. A small spherical sweep keeps the extended lens clear of solid scenery. Releasing the stick holds the framing; a dead zone prevents drift. Adjustment pauses during tracking loss, menu use and photo capture.

Camera controls do not cast, release catches or change bait. Collection navigation remains available after leaving camera mode.

Files are saved locally in your operating system’s Pictures folder, inside `Real AI Fishing` (for example `~/Pictures/Real AI Fishing` on Linux). Android saves new photos to the Pictures collection through MediaStore. `--photos-root PATH` overrides the destination for capture tests. Each filename includes a timestamp and unique suffix. The guide confirms successful saves and reports failures. Photos are never uploaded or sent to other players. Forward/selfie choice lasts for the current session.

Preview rendering is limited to 640 × 360 at approximately 10 Hz while the camera is held. It stops when docked or in collection mode. Full resolution renders only for the shutter; repeated shutter input is ignored while saving. UI exclusion uses a dedicated render layer, so photography does not toggle shared world visibility or put the guide's preview inside itself.

Camera validation: 14 headless control/layer checks, 18 real Vulkan capture checks, 27 historical guide checks, and 36 native Monado guide/camera checks passed. Native tests use two synthetic tracked controllers and actual stereo rendering, not a physical headset. The existing OpenXR shutdown/spatial-disconnect/profile-RID warnings remain. Captures: [forward photo](guide_camera_forward.png), [selfie](guide_camera_selfie.png), [native VR selfie](guide_camera_selfie_xr.png), [guide camera display](guide_camera_screen.png).


## Rod feedback and recovery

Each bait has its own 3D shape: curved earthworm, corn kernels, spinner blade and hook, pale maggots, bread with crust, or feathered wet fly. An uncast rod carries the float and selected bait. Changing bait briefly shows its name above the rod.

Tension warnings start at 60% and become more frequent toward red. Tension rises by at most 14 percentage points per second; overload must persist for 2.5 seconds with the starter line before it snaps. A failed counter restores 18 percentage points of fish stamina, without an immediate tension change. Three failed counters still release the fish. Holding an already raised rod can counter a fish swimming away.

After a lost fish the tackle resets after 1.2 seconds, or immediately when starting a new trigger-and-swing cast.

On initial VR tracking, the player is calibrated to the same 1.65 m head-height reference used by FPSloppa. All VRMs use the shared 1.70 m body normalization; crouching or changing avatar does not resize the rig. Seated mode uses a vertical offset instead. Recenter while standing if startup calibration was taken in another posture.

When a counter ends, the fish keeps the position it reached. Reeling follows that new position toward the angler, and later escape movements build on it.

### Selfie reach validation — 17 September 2026

- `tests/selfie_extension.gd`: 25 checks pass for extension/retraction, the 3 m
  limit, rotated guide poses, dead zone, wall clearance, starting inside scenery,
  immediate retraction from an obstruction, tracking/focus loss and rear-camera
  isolation.
- `tests/guide_camera.gd`: 97 camera controls, projection and layer checks pass.
  `tests/fish_guide.gd`: 55 collection and guide interaction checks pass.
- Connected WiVRn testing used the physical headset and controllers. Right-stick
  input extended and retracted the camera, reached the 3 m limit, and saved a
  1920 × 1080 selfie using the right trigger. The photo was visually inspected.
  The tester confirmed that framing and avatar shoulder alignment both work well.
- `tests/live_wivrn.gd -- --selfie` preselects selfie mode for a two-minute live
  test, logs real input/reach/photo state, and captures both native eyes. The
  diagnostic now follows avatar changes instead of retaining old solver readings.
