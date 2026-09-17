# Real AI Fishing 0.1.11

This release expands fishing styles, species and scenery, and ships PC VR clients
plus a separate Linux dedicated server. Quest builds are withheld pending testing;
Pico builds remain retired, with Pico OS 6 a future goal only.

## Fishing and environments

- Classic/fly, feeder and lure styles share all four tackle tiers. Feeder has four
  bait choices; lure has three, with a joystick radial selector and matching reels.
- The roster grows to 40 species: silver bream, ruffe, ide, asp, leervis, Atlantic
  chub mackerel, huchen and ragged-tooth shark have original textured models.
- Distributions and preferences distinguish methods and waters. Guide entries
  include silhouettes, habitat, preferred bait, available methods and named waters.
- Predator takeover chance is **3% once per eligible retrieval**, shared across
  locally eligible predators. Huchen expand river encounters; ragged-tooth sharks
  join selected coasts. Consumed prey earn no duplicate catch or currency.
- Shoreline repairs, authored dressing, lighting and water coverage improve the
  existing locations. Locomotion stays available with a fish hanging on the hook;
  holding the fish offhand blocks it. Offhand trigger releases a gripped fish.
- Pictograms are optional. A repository HTML manual replaces the tutorial button;
  server leaderboards replace it in the menu and persist only on the server.

## Avatar and camera checks

Compared with FPSloppa upstream `b0fc725467e50e5f07fb335d0ca61f8e94e18f6d`:
its unified rest-pose sizing, fixed physical calibration and neutral hip/ankle
retargeting fixes are already implemented. Tiny/large model scales, standing,
crouching, raised feet, locomotion, recovery and tracking regression tests pass.
Fishing-specific tracking safeguards and hand attachment behavior are retained.

Guide camera tests cover world X/Y/Z translation and combined yaw/pitch/roll,
including near-vertical orientations, for both lenses. The front lens rotates
180 degrees around local up; it never inverts tracked translation or mirrors its
basis. Image-right/up/depth projection checks cover the preview convention.
Desktop FOV now explicitly resets after XR camera use.

## Packages and compatibility

- Linux x86_64 and Windows x86_64: VR and desktop launchers, complete runtime assets.
- Linux dedicated server: separate embedded-script binary with no visual assets,
  avatar bundles, XR or voice codec extensions.
- Quest: **excluded pending device testing**. No current Pico package.
- Multiplayer protocol **10**: update all clients and servers together.
- Existing fish IDs and scientific-name guide records remain stable.

Archives exclude development/source files, retain attribution and use maximum ZIP
compression. Runtime texture deduplication and desktop HDR block compression remain
enabled. Build manifests and SHA256 checksums accompany downloads.

## Validation and limitations

59 regression suites passed, including gameplay, predator probability/fights,
guide/model bounds, avatar scaling/posture and camera axes. The rendered camera
check passed 101 assertions; 20,000 coastal encounter trials yielded 588 takeovers
(2.94%). Dedicated/ad-hoc multiplayer and new-shark server restart persistence
passed. New predators were reviewed in Blender
and rendered using Vulkan/simulated OpenXR. Physical-headset comfort/performance
and Windows execution remain untested; simulated XR teardown can emit known
runtime cleanup diagnostics.

[Predator rules and source assets](PREDATOR_ENCOUNTERS.md) ·
[Expanded roster](ROSTER_EXPANSION.md) · [Location distribution](LOCATION_SPECIES.md) ·
[Manual](MANUAL.html) · [Build instructions](RELEASE.md).

[Validation record](validation/release-0.1.11/checks.json) · [Predator gallery](validation/release-0.1.11/gallery-oblique.png) · [Selfie capture](validation/release-0.1.11/guide_camera_selfie.png).
