# Hip tracking and additional golf courses

With a valid hip tracker, the fishing rod, fishing guide, golf club and course guide use a shared waist frame. Head yaw and leaning do not turn or translate their hip mounts. Bridge torso axes are corrected once on acquisition instead of rebuilding the facing from the head every frame. A waist-only external tracker can establish its neutral orientation without full-body calibration; explicit calibration and recentering still reset its alignment.

The locomotion capsule follows the tracked pelvis rather than the headset. Leaning across a low railing no longer translates the player's entire body into it. Hip movement still collides with the railing, and a separate swept head shape prevents leaning through tall walls. Tracking samples are retained in origin coordinates, preventing repeated physics ticks from applying the same physical step twice. Missing hip tracking restores the existing head-following capsule.

## Courses and sources

The Golf menu now offers four connected 18-hole courses: Spyglass Hill, Pebble Beach, **Cypress Point Club** and **Poppy Hills Golf Course**. Each new course includes mapped routes, three tee choices, greens, bunkers, water, trees, a clubhouse/BBQ area, course guide maps and separate persistent scores. Legacy Dalkey/Alpine records remain supported. Network protocol 16 includes measured user height and prevents incompatible clients from joining these worlds.

The new courses follow the existing Golf Minus authoring workflow: OpenStreetMap geometry, 100 regional Copernicus GLO-90 elevation samples through Open-Meteo, a 2 m height field and 1 m lie raster. `source/course_references` retains the inputs and retrieval metadata; `tools/build_reference_courses.py` reproduces both new courses offline with numpy, Pillow and shapely. `tools/fetch_course_inputs.py` retrieves the public source inputs.

- [OpenStreetMap attribution and ODbL](https://www.openstreetmap.org/copyright)
- [Cypress Point mapped boundary](https://www.openstreetmap.org/way/36435651) and [USGA hole tour](https://video.usga.org/videos/2025/08/condoleezza-rice-narrates-every-hole-at-cypress-po-6377527661112.html)
- [Poppy Hills mapped boundary](https://www.openstreetmap.org/relation/11841797), [NCGA course tour](https://poppyhillsgolf.ncga.org/course-tour) and [scorecard](https://poppyhillsgolf.ncga.org/scorecard)
- [Copernicus elevation through Open-Meteo](https://open-meteo.com/en/docs/elevation-api)

These remain mapped terrain adaptations. Green grades, bunker depths, vegetation and clubhouse placement are approximations. Official artwork is not used as game textures. The derived course databases are offered under ODbL; detailed attribution ships in `addons/golfminus/assets/course_data/CREDITS.md`.

[Rendered Cypress Point layout](cypress-connected-course.png) · [Rendered Poppy Hills layout](poppy-connected-course.png)

### Continuous playing lanes

All 72 holes across the four current courses now connect every back, club and forward tee to its green through fairway/fringe/green. `tools/build_course_lanes.py` chooses routes that favour the existing fairways and follow mapped bends, detouring around bunkers and water. Added lanes are normally 20 m wide, narrowing around mapped hazards and small tee pads while preserving a continuous 4 m clear core. Trees whose visible canopy could enter a lane are removed, with an additional 2 m clearance. The course guide and hole framing use the adapted routes. Original mapped paths/outlines and terrain heights remain available unchanged.

The offline pass is deterministic and runs automatically when rebuilding Cypress/Poppy. It also updates Spyglass/Pebble from their archived mapped outlines. Course revisions invalidate cached terrain and guide maps. `tests/golf_course_lanes.gd` samples the actual lie raster along all 216 tee connections and checks canopy clearance and map bounds.

## Validation on 22 September 2026

`hip_tracking` covers low-rail leaning, floor support, hip collision, fast head movement against tall walls, repeated samples, tracking loss and fishing mounts. `tracking_orientation` covers native bridge and external sensor orientation. Golf camera tests cover hip-mounted club/guide stability. Casting, menus, avatar movement, hand tracking, fishing comfort and golf session regressions pass.

The exported game pack passes 45 course/data/record checks across all four mapped courses and six current/legacy record IDs. Local ENet integration passes for the host and two clients. A dedicated-server harness race was corrected to retain the observed waiting-lobby snapshot, since the organiser can start before another client next polls its roster. The exported dedicated server also passes two-client 18-hole rounds, malformed-command rejection, clubhouse BBQ, retirement and ranking persistence after restart. Course rendering was inspected using Vulkan.

Native WiVRn validation loaded both new courses from the exported Linux game pack in the connected Quest Pro, without synthetic tracking injection. All six two-second samples reported focused head, left controller, right controller and hip tracking; hip collision was active. Cypress Point reported 71–72 FPS and Poppy Hills 72 FPS. Both eyes were captured for both courses and inspected. These are short functional samples, not a sustained performance benchmark or a user comfort assessment. Low-collider movement is verified with synthetic physics tests; the live check establishes native tracker delivery and rendering.

Live results and stereo captures: `test-results/hip-golf-live/`. Runtime log: `builds/HipGolf/wivrn-test.log`. Existing OpenXR shutdown cleanup diagnostics appeared after the test passed. The standalone export template does not expose `--script`; test harnesses use the matching Godot version with `--main-pack` against the exported PCK. The standalone Linux executable was also launched in WiVRn.

Build: `builds/HipGolf/RealAIFishing.x86_64` with its adjacent PCK and native libraries. `build-manifest.json` records the base commit, working-tree hashes, artifact hashes and protocol. This is an uncommitted working-tree debug build, including the saved head-aimed casting option from the preceding change.

The initial standalone build was launched as the user service `raifslop-hipgolf.service`; `builds/HipGolf/VR.sh` is its launcher and `builds/HipGolf/run.log` its current runtime log. The final startup reported OpenXR active with approximately 72 frames per second and no script errors.

## Height, casting and menu follow-up

The recording at `~/Downloads/rec.mp4` exposed a missing trigger route in the shared golf settings and a wall pointer using grip instead of runtime aim. Golf settings now route both trigger edges to the shared viewport before other golf controls. The clubhouse board uses the shared aim/fingertip ray, draws a cursor and beam, accepts analog/digital triggers and fingertip touch, and cancels input on focus loss or menu opening.

Controller-only casting uses the controller casting plane to recognize a backswing/reversal, including vertical starting rods and overhand wrist arcs. Only measured forward-stroke travel and speed set its launch heading and distance. Completed gestures survive release-angle changes and follow-through. Head aiming toward/above the horizon now selects the far water target. Open-water and tracking validity checks remain enforced.

Normal XR tracking stays at 1.0 world scale. A stable measured eye height sizes the avatar; later standing can raise a provisional startup measurement, while crouching never shrinks it. **Tracking → Measure standing height — stand straight** records and locks an explicit measurement. Seated play and recentering keep actual headset height and floor position. Remote avatars receive the same measured height (protocol 16). Torso IK and residual torso-root fitting keep the head/neck at authored offsets instead of burying Head in the collar. Native captures in `test-results/height-input-live` record exact bone offsets, headset error, tracking scale and stereo course renders.

Updated debug client and dedicated server: `builds/HeightInputFix/`. The source changes remain uncommitted; `build-manifest.json` records their hashes. The final WiVRn launcher is `builds/HeightInputFix/VR.sh`, with `run.log` beside it.

The final exported-pack regressions pass for tracked casting, golf VR inputs and course data. Native height captures report 1.0 world scale, unchanged Head/Neck offsets and submillimetre eye alignment. Both courses render native stereo with focused head, both controllers and hips at 71–72 FPS over six samples. Tee-number signs were moved beside the tee after stereo inspection found the original eye-height placement obstructed the view. Existing OpenXR teardown cleanup diagnostics remain after the probes exit.

Final launch: `raifslop-height-input.service` is active in the connected WiVRn server, with approximately 72 FPS and no script errors during startup. The final release-pack audit passes (1,388 entries, no reported failures). Automated controller tests verify cast/menu behavior; native hardware probes verify tracking, avatar fitting and stereo rendering.

## Tester feedback follow-up

The next build is `builds/GolfFeedback/`. Motion casting excludes the initial sideways lift from forward travel and power. A regression reproduces a rightward/upward lift followed by a forward cast, and checks that changing gaze does not alter the result.

Golf address-ball placement now leaves at least 85 cm beside the shot line. A successful swing or captured fit remembers the player's horizontal stance offset for later A/X addresses, while keeping tracking-origin orientation. Either sole tracked controller can operate the club, movement/turning, shared menus, wall controls, and tablet. The club changes hand after one second without its previous controller. With one controller, stick up/down moves and left/right turns; hold trigger in Godview to pan. With two controllers the existing controls remain available.

Grab the tablet handle at its hip with either grip. It follows that hand until release. With one controller, trigger opens the camera and then takes a photo, A/X switches selfie, and B/Y returns to the guide. In fitting, either stick adjusts head angle/reach even before automatic capture. Stick-click cycles yaw/pitch/roll; striking-hand trigger captures, A/X accepts, and B/Y cancels. Face adjustment and reversal preserve shaft orientation and head position. Unfitted clubs use their nominal lie compensation; an accepted fit replaces it.

The torso uses a shortest-arc bend instead of a limb hinge to prevent axial flips near straight extension. Near-straight tracked knees blend toward the pelvis-facing bend plane, so millimetre tracker jitter cannot flip the thigh or shin. The avatar still uses measured user height, preserves raw hip position and authored head/neck lengths, and aligns its eyes with the headset.

Headless tests cover these changes, including all three bundled avatar rigs, both sole-controller configurations, both tablet grips, and left-only menu/wall input. The exported PCK passes `tracked_cast`, `golf_controls_feedback`, `golf_vr_input`, `vr_ik`, `avatar_viewpoint`, and `release_pack`; its content audit reports 1,388 entries and no failures. The local ENet golf social regression also passes. Pack logs and the content audit are in `test-results/golf-feedback-pack/`. Updated native WiVRn testing and launching are pending the user's requested prompt; no VR test or playable build should be started until they agree.
