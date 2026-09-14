# Prototype validation — 9 September 2026

Godot 4.7.2 stable, Linux, Intel ADL-N / Mesa. Godot MCP and Blender MCP both connected and used to create/import/inspect the project.

- 20 deterministic simulation/reel checks pass: cast bounds, bait locking and affinity, early/missed/timed strikes, correct/incorrect/repeated counters, successful catch and journal entry, over-tension and slack escapes, one full physical crank rotation including angle wrap, distance rejection, re-grab reset, tracking-jump rejection and grip release.
- Headless main-scene smoke run: 30 frames, exit 0, no script/runtime errors.
- Godot MCP runtime keyboard input verified Space cast, Space hook set and Left-arrow counter. Waiting time was advanced for that integration check.
- Accelerated simulation in the running scene landed a European perch; normal runtime state handling instantiated the model and wrote the journal. Saved journal contents were checked. The validation catch was then removed and the session returned to ready.
- Desktop framebuffer inspected, including catch display. `preview.png` is an actual runtime screenshot.
- OpenXR initialized under the installed Monado simulated HMD. The default action map includes grip/aim poses, trigger, grip, face buttons and haptics. No controller devices were provided by the simulated runtime. This verifies initialization only; physical casting/reeling, stereo appearance and headset frame time remain unvalidated.
- Initial Compatibility/OpenGL stereo shaders failed on this GPU (`gl_ViewID_OVR`). Mobile/Vulkan startup cleared those errors. The project defaults to Mobile.
- Perch's redundant UV channels were verified identical and merged in Blender. Textures reduced from 4K to 2K. Blender source saved with packed textures outside Godot's import path.

Known prototype limits are listed in the README. Quest/Pico packages are now built; no Gaussian splat renderer is integrated.

## Locomotion and avatars update

- `tests/avatar_locomotion.gd`: **24 checks passed**, including both real bundled VRMs, the exact 25,000,000-byte boundary, rejection at 25,000,001 bytes before library registration, malformed-file rejection, loading a copied `user://` VRM through the plugin, persistent selection, and preserving the previous avatar after invalid selection.
- Analytic IK checks preserve limb lengths and remain finite for coincident targets. A runtime skeleton check confirms the right hand reaches the desktop rod grip. First-person camera excludes the head-only layer.
- Physics integration checks exercise keyboard movement against the dock front rail, walking onto the shore, head-centered snap turning and paused locomotion in the avatar menu. Stick deadzone and bounded diagonal speed are checked.
- Original fishing suite remains **20/20 passing**: **44 checks total**.
- Desktop VRM selection and full-body preview inspected with Godot MCP. Both Vita and Victoria Rubin were equipped. The desktop grip was repositioned to be reachable without stretching the imported avatar's arms.
- Fresh OpenXR startup with the installed Monado simulated HMD completed without game script errors. The VR avatar panel opened through the controller-button handler, a VRM avatar was present, and locomotion paused. Physical controller ray interaction, grip orientation, comfort and headset frame time remain unvalidated because this runtime provides no controllers.
- Raw avatar sizes are 14,198,800 and 15,321,932 bytes, both below the per-file limit. Godot VRM and MToon dependency are included and the VRM editor plugin is enabled.

## Additional fish — 14 September 2026

- Fishing simulation/reel suite: **78 checks passed**, including bait-pool reachability, all seven species landed from a 24 m cast, catch measurements, species identity, release and journal serialization.
- New main-scene fish integration suite: **36 checks passed**, including every catch model, finite bounds, new-model orientation and reference length, UV-mapped skin textures, model replacement, and actual journal save/load.
- Existing avatar/locomotion suite rerun: **24 checks passed**. Combined headless coverage: **138 checks**, no failures.
- Godot editor import completed successfully. Realistic textured models replace the initial procedural colour-block models. Roach and tench use about 3k triangles; bream uses 18,492 and zander 21,999. GLBs have 1–3 material surfaces and embedded textures; file sizes range from 1.9 to 9.7 MB.
- Blender gallery inspected at `docs/fish_species.png`. Desktop Mobile/Vulkan catch rendering verified using the integration test's `--capture` option, which adds one passing screenshot check. Capture: `docs/zander_catch.png`.
- Roach/tench are authored meshes with generated photographic-style textures; bream/zander use licensed textured assets. There is no skeletal fish animation. Physical headset appearance and performance remain untested.

## Locations and synthetic tracked controllers — 14 September 2026

- Procured four CC0 Poly Haven HDR panoramas through Blender MCP, retained the 4K originals and prepared 2K HDR derivatives plus 768 × 384 previews. Three are new playable environments; River Alcove is reference only. Provenance, hashes and sizes are in `docs/locations/`.
- Location integration: **52 headless checks passed**, or **57 with desktop captures**, covering the four selectable skies, bounded resolution, persistent selection, light/water presets, unchanged foreground/player position, paused menu, active-cast rejection and catch-location journal round trips. Final desktop views and menu were visually inspected after yaw/brightness adjustments.
- Regression suites rerun: **78 fishing + 36 fish model/journal + 24 avatar/locomotion checks**, all passing.
- WiVRn server was present. Launching with `/usr/share/openxr/1/openxr_wivrn.json` waited for a headset, so the test client was stopped without changing the server. Synthetic validation used the installed **Monado 25.1.0 simulated HMD**, with Mobile/Vulkan on Intel ADL-N graphics.
- `tests/locations_xr.gd`: **46 checks passed**, including initialized native OpenXR, two views with 63 mm eye separation, both synthetic controller grip poses, independent left-hand motion, grip-driven avatar hand curl, rod visibility, all four location changes, nonblank left/right render buffers, B-button menu open/close, ray-target accuracy, trigger-based row selection and travel, and controller disconnect/reconnect pausing/resuming fishing.
- The controller harness registers two test-only `XRControllerTracker` objects with grip/aim/default poses and injects button/float inputs through Godot's tracker API. It does not claim WiVRn controller transport, native hand-joint tracking, or physical device tracking. Production controls are unchanged.
- `tests/xr_capture.gd` reads actual native multiview GPU colour buffers through a test-only compute pass after transparencies. Each eye is 896 × 1007 pixels on this synthetic runtime. Scene-linear EXRs are generated under ignored `test-results/xr/`; PNGs in `docs/locations/xr_*_eye*.png` use a simple clamped linear-to-sRGB conversion, not the final display tonemapper. The desktop viewport's ordinary image readback was black in XR and is not used as visual evidence.
- Stereo images were inspected: [left eye](locations/xr_bell_park_pier_eye0.png), [right eye](locations/xr_bell_park_pier_eye1.png), [in-world menu](locations/xr_menu_eye0.png), [menu texture](locations/xr_menu_texture.png). The rod, avatar hands, dock and UI have eye-dependent offsets; the panorama remains at infinity.
- After successful checks, Godot/Monado emits `XR_ERROR_SESSION_NOT_STOPPING`, an OpenXR spatial-marker signal-disconnect error and two leaked interaction-profile RID warnings during shutdown. These remain an engine/runtime teardown limitation; the test does not report a clean XR shutdown. No physical-headset comfort, wireless streaming, latency, controller calibration or performance claim is made. GPU readback intentionally stalls rendering and must not be used for performance measurements.

Reproduce using an isolated save directory and an available desktop display:

```bash
XR_RUNTIME_JSON=/usr/share/openxr/1/openxr_monado.json \
SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1 \
XDG_DATA_HOME=/tmp/fishing-synthetic-xr \
./run.sh --script res://tests/locations_xr.gd
```

The synthetic input API follows Godot's [XRControllerTracker](https://docs.godotengine.org/en/stable/classes/class_xrcontrollertracker.html) and [XRPositionalTracker](https://docs.godotengine.org/en/stable/classes/class_xrpositionaltracker.html) contracts. Stereo readback uses [RenderSceneBuffersRD](https://docs.godotengine.org/en/stable/classes/class_renderscenebuffersrd.html). Test scripts are opt-in and are not loaded by normal gameplay.

## VR caught-fish inspection and physical casting — 14 September 2026

- `tests/catch_xr.gd`: **43 checks passed** with the native Monado synthetic stereo HMD and two Godot synthetic controller trackers. This uses the same opt-in GPU eye-buffer capture harness and has the same runtime shutdown errors described above.
- Physical input tests drive tracked grip transforms and trigger press/release signals through the production code. Stationary release does not cast; forward controller translation and an angular rod swing both cast. With the rod turned sideways, the cast target follows the headset's center-view heading. Player-origin translation alone does not generate power. Cast distances remain bounded.
- Gaze means **the center of the headset viewpoint**, projected onto the horizontal plane. No eye-tracking extension, gaze tracker or eye pose is queried. Swing speed determines range; view heading determines direction. Near-vertical views fall back to the tracking origin's forward heading.
- Catch checks cover head-up hanging with the mouth anchored 28 cm below the tip, retained fishing line and hidden bobber, left grip holding the string 8 cm above the mouth with the line routed through the hand, vertical head-up orientation in the hand despite controller tilt, vertical-axis rotation from either stick, suppressed stick locomotion, return to the rod on grip release or left-controller disconnection, and Right A release restoring movement controls.
- Native stereo captures: [hanging catch](locations/catch_hanging_eye0.png), [left-hand inspection](locations/catch_in_hand_eye0.png), [right-eye inspection](locations/catch_in_hand_eye1.png). Scene-linear masters are regenerated under ignored `test-results/xr/`; old raw captures were removed during release cleanup. These use the documented test capture conversion, not final display tonemapping.
- Regression checks: **78 fishing + 36 fish-model/journal + 24 avatar/locomotion**, all passed. `git diff --check` passed. Physical headset ergonomics, tracking noise and real casting calibration remain unvalidated.

Run with an isolated save directory:

```bash
XR_RUNTIME_JSON=/usr/share/openxr/1/openxr_monado.json \
SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1 \
XDG_DATA_HOME=/tmp/fishing-catch-xr \
./run.sh --script res://tests/catch_xr.gd
```

## Handheld illustrated Field Guide — 14 September 2026

- `tests/fish_guide.gd`: **22 headless checks passed**, or **24 with desktop captures**. Coverage includes first discovery, name/description/size, equal and smaller catches preserving records, larger catches changing only length, malformed/fictional records, all seven species and silhouettes, actual landing integration, disk save/load, desktop open/close and page wrapping.
- `tests/fish_guide_xr.gd`: **28 native synthetic XR checks passed**. Verified the lower handle's reach and grab point, preventing remote grabs, tracked handheld pose, hand clearance below screen/controls, paused fishing, button/stick browsing without snap turns, release-to-belt, resumed fishing, re-grabbing, priority over caught-fish inspection and safe docking after controller disconnection.
- Final native left/right captures show the species silhouette and lower handle with the avatar hand clear of the controls: [left eye](locations/field_guide_eye0.png), [right eye](locations/field_guide_eye1.png). [Screen detail](field_guide_screen.png) and [desktop device](field_guide_desktop.png) were also inspected.
- Regression checks rerun: **36 fish-model/journal + 24 avatar/locomotion + 52 location checks**, and **43 native XR catch/physical-casting checks**, all passed. `git diff --check` passed.
- The rapid headless guide test also reports two audio-object cleanup warnings after passing (the landing tone’s AudioStreamWAV/AudioStreamPlaybackWAV in the verbose run). The native runs retain the previously documented OpenXR runtime teardown errors. Synthetic controller tests do not establish physical-headset ergonomics or WiVRn transport performance. See [Field Guide controls, record semantics and reference sources](FIELD_GUIDE.md).

## Shore-connected location foregrounds — 14 September 2026

Replaced the shared foreground with four Blender-authored, textured location models and separate collision layouts. Added continuous mainland behind the cove and boardwalk, a harbour apron adjoining the quay, and a shore-connected landing stage securing the boat's mooring lines. Inspected all four desktop overviews in [foreground documentation](FOREGROUNDS.md). The water shader now uses unequal travelling ripple directions to reduce the previous checkerboard pattern.

- `tests/foregrounds.gd`: **29 headless / 33 desktop-render checks passed**. Walks each water edge, checks collision stops movement, arrival floors, distinct scene replacement, safe shore-to-boat travel, preserved head height/orientation, tapered bow floor and location-specific fall recovery.
- `tests/locations.gd`: **52 checks passed** with foreground replacement/safe-arrival expectations.
- `tests/avatar_locomotion.gd`: **24 checks passed**, including movement across the cove and perimeter collision.
- `tests/locations_xr.gd`: **46 checks passed** in native Monado OpenXR with simulated HMD and two injected tracked controllers. Captured real left/right eye buffers for all four updated locations and exercised tracked-ray menu travel.
- Godot editor import completed; `git diff --check` passed.

The first foreground test used too short a forward walk to settle at the end of Gray Pier; extending it to 330 physics frames reached the barrier and passed. Runtime collision did not require changing.

Native XR teardown still emits `XR_ERROR_SESSION_NOT_STOPPING`, a spatial-signal disconnect error and two leaked interaction-profile RIDs after the passing checks, as in earlier runs. No physical-headset comfort or performance claim is made. Distant panorama parallax and the geometric-to-photographic terrain transition remain approximations. Land beyond perimeter barriers is decorative; the boat dock provides a visual mooring connection without an implemented boarding mechanic.

## Ten species per location and six baits — 14 September 2026

Added rudd, crucian carp, European chub, rainbow trout and brown trout: twelve real species across four distinct ten-species rosters. Maggots, bread and wet flies expand bait selection to six. Casting filters by both location and bait. Existing scientific identities and the first seven catalogue indices remain stable. All twelve Field Guide entries have descriptions and silhouettes.

- Fishing simulation: **118 checks passed**, including all twelve fight profiles.
- Fish model/journal integration: **71 checks passed** on final GLBs, including textured skin, scale, replacement and persistence.
- Field Guide: **27 checks passed**, including twelve-species unlock and page wrap.
- Location roster and bait input: **77 headless / 79 desktop-capture checks passed**. Sampled 160 casts for each of 24 location/bait combinations; all ten local fish were reached at every location, with no out-of-roster selections. Tested keys 1–6, mouse tiles, VR input-handler cycling and cast-time bait locking.
- Native Monado synthetic OpenXR: **49 checks passed**, including six tracked-controller bait-cycle checks plus casting and caught-fish inspection. Known runtime shutdown errors remain: XR_ERROR_SESSION_NOT_STOPPING, a spatial-signal disconnect error and two interaction-profile RIDs leaked at exit. No physical-headset testing was performed.
- Inspected [final fish gallery](additional_fish.png) and [six-bait HUD](baits_six.png). Fixed missing immediate HUD redraw when changing bait. Godot import and `git diff --check` passed.

Each new fish is a joined mesh with five material surfaces, 4,416–4,598 triangles and less than 1 MB of GLB data. Original UV skin textures are 1024 × 512. [Asset counts and hashes](additional_fish_assets.json), [rosters, bait compatibility and biological references](LOCATION_SPECIES.md).

## Multiplayer and FPSloppa reuse (2026-09-14)

`python3 tools/test_multiplayer.py` passes dedicated-server and ad-hoc sessions using separate ENet processes and isolated saves. Coverage includes current-state synchronization for late joiners, custom VRM upload/server verification/download/remote loading, casts, catches and lengths, hand inspection, release, locomotion/head poses, per-location visibility and voice, per-player mute, actual Opus decoding and unchanged local Fish Guide records. `tests/network_guards.gd` passes 14 checks covering wire validation, sequence ordering, voice membership/replay/flood limits and invalid connection parameters. Existing fishing simulation (118) and Field Guide (27) checks pass with multiplayer installed. All 12 native TwoVoIP binaries match FPSloppa's included SHA-256 manifest.

`python3 tools/test_multiplayer_xr.py` passes 10 assertions using a native Monado simulated HMD and two injected tracked controllers, plus a separate Vulkan desktop client. It verifies both controller poses across the network, full remote VRM loading, vertically hanging caught fish and actual two-eye render readback. [Left eye](multiplayer_eye0.png), [right eye](multiplayer_eye1.png), [desktop observer](multiplayer_desktop.png). Synthetic poses position players for the captures; these do not establish physical-headset comfort or collision realism.

No real microphone was opened: the voice test uses FPSloppa's deterministic Opus tone fixture. Native capture, Internet/NAT conditions, standalone Android packaging and physical Quest/WiVRn client operation remain untested. Gaze aiming remains center-of-view; no eye tracking is introduced.

Known teardown diagnostics: the native Monado/Godot run still reports `XR_ERROR_SESSION_NOT_STOPPING`, the existing spatial-signal disconnect diagnostic and two OpenXR interaction-profile RIDs after passing. Some synthetic voice observers report two unnamed ObjectDB instances at process exit, despite explicit player/stream cleanup. The receiver leak is unresolved; it did not prevent decoding, muting, disconnection or test completion.

## FPSloppa avatar tracking extension (2026-09-14)

- Reused controller/native finger tests: **18 passed**. Dedicated Vive-role/native/SlimeVR orientation and calf-to-foot tests: **12 passed**.
- Fishing avatar tracking and calibration: **26 passed**, including retained VRM expression bindings, independent finger bones, eye/eyelid animation, mouth decay, tracked feet, procedural gait, native face/jaw sampling, missing/focus-lost trackers, T-pose latching, standing/seated recentering, rejection of recenter during casting or lost head tracking, and invariant viewpoint-centered cast aim. Turned hips/chest/feet are checked against their expected world orientation to prevent applying avatar yaw twice.
- Protocol guards: **18 passed**, adding malformed body, finger, face and viseme rejection. The separate-process dedicated/ad-hoc/late-join integration runner passes with body joints, independent curls, face weights and acoustic visemes included.
- Native Monado simulated HMD + injected body/face/controllers + separate desktop client: **13 passed**, including actual two-eye readback and replicated full-body/face/finger state. Captures remain `multiplayer_eye0.png`, `multiplayer_eye1.png`, and `multiplayer_desktop.png`.
- Existing native casting/catch/inspection regression: **49 passed**. Existing avatar/locomotion **24 passed** and fishing simulation **118 passed**.

The native run retains Godot/Monado shutdown diagnostics (`XR_ERROR_SESSION_NOT_STOPPING`, spatial-signal disconnect, interaction-profile RIDs; four profiles with the added actions). Physical trackers, optical face/eye accuracy, Quest/Pico permission dialogs, standalone exports and physical-headset comfort have not been validated. Tests use synthetic tracker data, never eye tracking for cast aim. See [tracking controls and runtime requirements](AVATAR_TRACKING.md).

## CC0 SharkPerson, ambience and menu refresh (2026-09-14)

New profiles default to bundled CC0 SharkPerson; saved choices are preserved. Reproducible metadata-only repair removes an empty duplicate left blink, with original VRM compressed under source/avatars. Four CC0-derived 128-second ambience beds plus authored wind/timber detail, two-second location crossfades and persisted Sound controls. Field station menu adds five tabs, FPSloppa-derived in-panel selectors/drag scrolling, and a deferred-input VR keyboard. See [presentation notes](PRESENTATION.md) for assets, rebuilding and screenshots.

Desktop presentation: 10 checks passed. Native Monado presentation: 12 checks passed, including tracked-ray tab changes and typing. Avatar tracking/calibration: 26 passed. Avatar/locomotion: 26 passed with all three bundled models. Feature and network results are recorded in the presentation notes. Synthetic runtime teardown diagnostics remain; physical headset fit/audio comfort is untested.

## Fishing feedback (14 September 2026)

Added authored CC0 cast/reel/fight/landing sounds, directional surface wakes tied to counter direction, and tension-dependent line color/sag. Splash attack/high frequencies and levels were reduced following user feedback. Existing tension balance retained; Real VR Fishing comparison distinguishes official guidance from community reports. Tests: feedback23, simulation118, synthetic OpenXR casting49; desktop wake screenshot verified. See [details](FISHING_FEEDBACK.md).

## Subdued baked scenery, avatar lighting and blob shadows (2026-09-14)

All four locations have UV2 Cycles sky/total-light EXR atlases and AO PNGs, including baked static sun shadows; normal/roughness detail and highlights are restrained. Original collision manifest preserved. Reconnected Blender MCP and reused clean FPSloppa MToon bounded-light response. Soft contact blobs are the default for local/remote moving avatars; Dynamic remains available under Avatar → Moving shadows, persisted in graphics.cfg.

Validation: lighting50, blob policy19, foreground collision29, avatar tracking26. Four-avatar ABBA desktop and native Monado stereo benchmarks show substantially lower GPU rendering cost with blobs; exact results and limitations are in [lighting notes](ENVIRONMENT_LIGHTING.md). Source bake script, per-location lighting .blend files, asset hash manifest, full measurements and screenshots are included.

Final lighting integration: native Monado + desktop multiplayer13 and existing menu/ambience31 passed. The rendered blob on/off test changes 5,747 sampled floor pixels. Desktop GPU time falls 42–48%; synthetic stereo 39–43% for the four-avatar comparison. Dynamic shadows remain selectable; static scenery sun shadows stay baked.

## Recorded fishing foley (2026-09-14)

Replaced synthesized cast, splash and landing effects with recorded fly-rod motion, a small river plop and small-trout splashes. Soft filtering/fades, −23 to −26 dBFS asset peaks, −8 dB close-range gain caps, and varied fight clips reduce sharpness and repetition. Removed the electronic landing-success tone. Reel sound is unchanged. Source recordings, CC0/CC BY 4.0 attribution and reproducible processing are retained in source/audio/fishing and tools/build_fishing_audio.py.

Validation: all 26 fishing-feedback checks passed, including distinct float-entry audio, gain caps, splash variation, event timing and existing tension/wake behavior. Godot retained its exit cleanup warning (four ObjectDB instances and one resource); no test or script errors. Perceptual comfort on physical headset speakers remains unverified.

## Shekel rewards, rod shop and species stamina (2026-09-14)

Added local persistent shekel payouts based on rarity and relative catch size, four purchasable/equippable rod tiers, and a shared desktop/VR Tackle page. Stronger lines tolerate overload longer and reduce extra escape load; better rods deal more fatigue. Species-specific endurance, rarity-weighted selection, stamina-dependent escape tension, and successful counters that stop runs and postpone escape cues are implemented. Old journals remain intact with no retroactive rewards. Profile saves use temporary replacement and purchases roll back on save failure.

Validation: tackle63, simulation118, feedback26, menu/ambience33 passed in isolated profiles. Full fights land all 12 species with starter and top-tier rods; upgrades shorten each fight. Shared menu width and purchase/equip controls verified headlessly; physical XR interaction not rerun. Existing Godot cleanup diagnostics remain. See TACKLE_AND_REWARDS.md for balancing and persistence details.

## Fish Guide camera and selfie extension (2026-09-14)

Added a live camera page to the handheld guide. Desktop: G opens guide, C switches camera, Space takes photo, F toggles selfie. VR while held: left trigger switches camera, right trigger takes photo, right A toggles selfie. Mono 1920×1080 PNGs save to user://photos with unique filenames and visible save/error status. The guide, world status/menu panels, pointer and remote player name labels use a UI-only layer excluded from photos; main view visibility stays intact. Selfie lens extends 1.5 m with scenery collision checks and includes the full local avatar. Preview is 640×360 at 10 Hz while held; dock/collection disables its rendering.

Validation: camera controls14, real Vulkan captures18, existing desktop guide27, native Monado two-controller guide/camera36 passed. Reviewed forward/selfie photos and camera display. Existing native shutdown diagnostics remain; physical headset interaction untested. Implementation and controls: docs/FIELD_GUIDE.md; captures docs/guide_camera*.png.

## Eighteen species / fourteen per location (2026-09-14)

Added real grayling, barbel, dace, bleak, gudgeon and brook trout at stable indices12–17. Existing rosters each gain four species and retain every prior member. All six baits remain valid; selection stays rarity-weighted. Each addition has a distinct textured Blender model, guide description/silhouette, size/weight, power, rarity and endurance, using existing rewards and rod progression. Blender MCP built packed source scenes; biological references and CC0 original-asset credits retained in docs/LOCATION_SPECIES.md and docs/expanded_fish_assets.json.

Validation: simulation166, tackle81, models113, rosters77, guide33, network guards27 passed; gallery/roster rendered run79 passed. Starter and top-tier rods land all18 species, with upgrades shortening every fight. Visually reviewed docs/expanded_fish.png. Existing cleanup warnings remain; physical XR appearance not retested.

## Clean source release validation (14 September 2026)

After removing the old Godot cache and importing the cleaned project, all eighteen headless suites passed: simulation, avatar/locomotion, fish models, tackle, Field Guide, Guide camera, network guards, locations, species rosters, foreground collision, environment lighting, avatar tracking, hand tracking, orientation, blob shadows, fishing feedback, rod/environment and menu/ambience. The avatar camera assertion was updated to allow the intentional Guide UI layer while still requiring world/body visibility and excluding the head-only layer.

Separate-process dedicated/ad-hoc multiplayer and native Monado stereo multiplayer passed. The real Vulkan rod/environment test passed 40 checks, and rod/stereo captures were reviewed. Native hardware tracking, Windows runtime and physical Quest/Pico acceptance remain untested. Existing exit cleanup and OpenXR teardown diagnostics persist; no failing assertions or script errors remained. Raw logs are local under ignored `test-results/cleanup-*`.
