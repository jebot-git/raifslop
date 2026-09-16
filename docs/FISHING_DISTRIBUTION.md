# Casting, fish distribution and lighting verification

Both fishing styles require a back/forward controller swing while holding the
trigger. Casting reads the raw controller-derived rod tip in tracking-origin
space; avatar IK and locomotion cannot suppress or manufacture a swing. The
swing axis is fixed at trigger press, so looking away does not change detection.
Six centimetres of backward tip travel followed by ten centimetres forward
accepts a swing; there is no deadline or narrow release instant. A completed
gesture remains accepted through follow-through spikes or frame hitches.
The rod shows “Release to cast” when ready.
Desktop holds Space for an animated backswing and releases to cast. The visible
water marker and bobber share one projection, bounded to 5–24 metres. Trigger
or Space press locks the target in world space until release; head and rod motion
during the swing do not move it. Aim pitch
changes range; yaw changes direction. Shore and river-channel checks still apply.

Each water has nine fixed sectors in a 3×3 grid: left/centre/right and
near/middle/far. Boundaries are x = -5 / 5 and z = -10.5 / -15.5 metres.
Species start in separate corner quadrants, then fill the other cells before
sharing sectors. Each shoal has its own 25–55 second migration timer and chooses
an adjoining cell without wrapping across grid edges. Their local catch weight is 12.5 times their roaming weight,
before rarity and abundance are applied. Species are selected again at the bite
using the current shoal distribution and, for flies, the drift's actual position.
Faint periodic rings signal sectors holding fish responsive to the equipped bait.

Incidental off-bait fish have a 15% chance when the location has any eligible
off-bait species. Habitat restrictions and the predator takeover rules remain.
Each landed catch leaves 35% of that species' current local abundance; catch
weights use abundance squared. Other species are unaffected. Abundance recovers
linearly over 240 seconds of fishing simulation, including time spent ready or
fighting another fish. Travel and recasting retain each water's stocks; a new
game session starts fresh. These populations belong to the local fishing session.

Ordinary bite delays range from 4–32 seconds. The original four-second minimum
is retained; random variation and low feeding activity increase the delay.
River base delays are 4–14 seconds before drift quality, preserving the existing
finite drift and mending mechanics.

Dives still require stopping the reel and sink the float. Rushes require fast
reeling, create slack while moving toward the angler, and keep the float at the
surface with a directional wake. Existing reaction windows and line limits apply.

## Lighting

The compression audit measured the six total-irradiance and sky atlases through
the previous desktop BC6H cache. Relative RMS error was about 0.4–1.3%, but
Lakeside's sampled maximum increased by about 13%. Lighting atlases now retain
their lossless imported HDR bytes on desktop as well as Android. Desktop 8K
panoramas still use BC6H. Missing mipmaps on four coastal atlases are restored.

`tests/hdr_bake_compression.gd` compares every imported HDR texel and mip level,
and samples both the full bake and the former sky-plus-sun path under full,
partial and absent shadow attenuation. Final error is zero for all six waters.
`tools/audit_release.py` also verifies exact atlas bytes in the exported package.
The dynamic player shadow preference, command-line switches and shader branch
are removed. Soft contact shadows use the actual tagged floor, including beach
slopes and procedural river banks.

## Checks

`tests/fish_population.gd` covers 12,000 catch samples, sector bias, migration,
depletion, recovery, travel and bite timing. `tests/fishing_update.gd` exercises
desktop input, visible casting, aim/landing agreement, dive/rush cues and feeding
ripples; `-- --capture` saves rendered views in `test-results/fishing-update/`.
`tests/tracked_cast.gd` drives synthetic controller poses through the production
input path without requiring a headset.

Existing fight, species, predator, fly, fish-position, feedback, tackle, landing,
environment, scenery and contact-shadow checks pass. Isolated settings tests
verify menu, Escape and window-close save/restart paths. A Linux validation PCK
passes asset-byte auditing and runtime loading of all eight locations. Desktop
Vulkan views were inspected. A connected WiVRn headset then initialized OpenXR,
reported focused head and both-controller tracking in five samples at 70–72 FPS,
and supplied both stereo eye readbacks. The game was left running for manual
playtesting. This verifies live startup/rendering/tracking; complete physical
fishing interaction and Android execution remain unverified.


## Comfortable casting and nine-sector follow-up

Live WiVRn diagnostics recorded 31 rejected attempts in the previous build;
29 had valid water targets, and multiple attempts recorded completed strokes
before failing at release. The discontinuity guard could reset completed
strokes during follow-through. Casting now retains its accepted state until
release, ignores discontinuous samples, uses distance instead of fast velocity
thresholds, and fixes the gesture axis at trigger-down. A five-second pause is
accepted, and there is no narrow release deadline. The first full physical
swing after the update launched successfully in the connected headset.

`tests/cast_tolerance.gd` covers slow through fast swings at 30/72/90/120 FPS,
long pauses, retained acceptance, and rejection of hand noise. Tracked input,
fly fishing, desktop feedback, 12,000 population samples, all nine grid cells,
independent migration, all location rosters and the full fishing simulation
pass. Live attempt data is saved in
`test-results/fishing-update/live-cast-analysis.json`.

## Headset refinements

Feeding-ring radii are 20% smaller; fight wakes keep their existing size. Baked
foreground lighting now uses 0.8 times the source irradiance (about -0.32 EV),
and Sunrise Beach sand no longer has a 1.6 times tint boost. These are deliberate
presentation adjustments, not changes to HDR compression or the original EXRs.
An isolated Vulkan probe confirmed the original and pre-adjustment shader were
identical, with no extra direct light. After the adjustment its display sample
changed from 0.4824 to 0.4353, independently of directional-light energy.

Startup waits for a quarter-second of focused head tracking, recenters to the
location spawn, and settles world-scale updates before enabling movement. Later
movement is preserved. Left grip or trigger acquires the nearby visible reel;
the avatar hand snaps to the crank while raw relative controller motion drives
winding. Releasing the input, losing tracking or opening another interaction
releases the hand. The snapped pose also replicates to other players.

Casting keeps the relaxed distance thresholds and no time limit. The backstroke
must raise the rod near shoulder/head height; strongly sideways travel is
ignored. A backward-pointing release, low swing or deliberate reverse sweep
after readiness is rejected. The Guide cannot be grabbed during BITE or FIGHT,
through either hip grip or the desktop G key; a fresh grip is needed afterward.

Additional checks: `cast_direction.gd`, `tracked_cast.gd`, `avatar_tracking.gd`,
and `vr_interactions.gd` exercise direction rejection, both reel inputs, hand
snap/release, no automatic winding, startup recentering and the hooked-fish Guide
lock.

The refined build was relaunched in the connected WiVRn headset at 71–72 FPS.
Live input completed a 0.46-second casting gesture, progressed through a bite
and hook set, and engaged/released the reel during the fight with the Guide
docked. Samples are in `test-results/fishing-update/live-refinements.json`.

Lake Pier's small cleat now extends to deck level instead of leaving a 6 cm
air gap. The runtime repair retains UVs and the original HDR atlases; fresh
foreground builds author the grounded base directly. `tests/pier_cleat.gd`
checks the isolated geometry change and can render before/after close-ups.
Presence rings have their own animation clock, so holding the Guide with a
cast line no longer freezes ambient water activity. Active fishing sounds and
haptics still pause. `tests/fishing_update.gd` covers that interaction.

Fly follow-up: the smaller fly reel supports grip/trigger grabbing, winding
and hand snapping independently of loose-line stripping. Additional full
back/forward strokes extend the aim marker two metres along the captured
direction, bounded to valid water; the first stroke and normal fishing retain
the locked point. See `docs/FLY_FISHING.md` for strict fly-reel tension rules.
The baked-light multiplier is now 0.86: 7.5% brighter than the 0.8 adjustment,
with original HDR data retained. `tests/fly_controls.gd` and
`tests/fly_reel_penalty.gd` cover both river control paths and the strain rules.

Landing now traces the current retrieval path to tagged bank/deck geometry,
at water level and below raised decks. It no longer uses where scenery hides
the float as the catch boundary. The threshold refreshes as the fish drifts or
changes direction. Tired fish require active final retrieval at that boundary;
`tests/shore_retrieval.gd` covers stale thresholds, exhausted mid-water fish and
actual shoreline retrieval at all eight waters.

The runtime now moves blocked grid centres into reachable open water for each location, using the full local regular-fish clearance. Feeding effects and bite selection share the same location-specific sector mapping. See [aiming and water checks](FISHING_COMFORT.md#aim-restoration-and-secluded-cove-water-check).
