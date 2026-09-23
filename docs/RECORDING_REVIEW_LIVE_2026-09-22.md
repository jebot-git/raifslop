# Live VR recording review — 22 September 2026

Reviewed the three `builds/Rec3FixesVR/capture/game-*.mkv` segments, the corresponding client log, and captured round/controls saves. The video covers about 5½ minutes beginning at 22:52:34 CEST. It is the desktop third-person mirror, not a headset recording. Overview frames are in `test-results/live-review/`.

## Findings and changes

### Casting

The full client log records **29 controller-aimed attempts: 20 launches and 9 rejections**. Rejections have no accepted swing vector and report the incomplete back/forward gesture. Some successive attempts have nearly opposite gate axes. The video shows the final fishing attempts before entering the clubhouse at roughly 27 seconds; the log also includes attempts before recording began.

A reproducible source defect switches from the controller's casting plane back to the rod's horizontal projection when an overhand backswing passes about 131 degrees. That reverses the gate, potentially measuring the preparation as the forward stroke or rejecting the real forward stroke. The plane reference now remains forward when the raised shaft points behind the player. Actual launch heading and distance still come from controller motion, independently of the headset.

Trigger release now consumes the latest tracked pose before deciding whether the gesture completed. Previously, a release callback could precede the process callback that would have measured the final forward movement. Discontinuity and focus/tracking checks remain in effect.

These are reproduced failure mechanisms, not a reconstruction of all nine rejected swings: the old capture does not include the raw controller poses needed to attribute every failure. New cast-result entries include monotonic timestamps and gesture state. Optional `--vr-test-capture` records up to 360 recent controller samples per attempt and enables existing golf swing/shot telemetry for the next authorized test.

### First tee and retirement

The first golf scene in the video, around 32 seconds, starts in rough. Save snapshots show the same old round ID `0fdc7507e433a72b`, on **hole 3**, with scores `[10, 9]` and an existing stroke. Its initial ball position is `(-771.62494, 9.240077, 58.048004)`. Later saves continue that round through eight strokes before advancing to hole 4. This was a restored lie, not a newly placed first-hole ball.

- **Retire from course** discards both in-memory and on-disk progress for that course. The next join starts at hole 1, zero strokes, on its selected tee. This also works when retiring from a suspended round while back at fishing. Network retirement clears local progress after server acceptance.
- **Start new solo round** explicitly starts from the first tee. When already enrolled in an online solo round, the button instead says **Return to solo round**.
- Leaving for fishing or visiting the clubhouse continues to preserve progress; **Return to round** resumes it.

### Teleport to ball

Previously, address position was a world-space offset and VR yaw was never adjusted. Returning to a ball on a different approach therefore preserved the old compass orientation rather than the stance relative to the shot.

Address now derives direction from the current ball to the pin, including restored lies. Saved stance and facing are stored relative to the shot direction, then rotated into the new approach. The tracking origin rotates around the headset; tracked head pose and physical height remain intact. A fresh stance has the existing club-dependent spacing and faces the ball. Repeated teleports are stable, with no accumulated rotation or positional offset. Looking straight down uses the headset right axis to recover a stable yaw.

### Club fitting

The previous fitter explicitly counter-rotated the head independently of the shaft to impose a terrain-relative face orientation. Captured controls saves confirm that accepting successive fits changed head rotation. That behavior conflicted with keeping the club rigid.

Automatic fitting now changes attachment rotation and reach while preserving the head-to-shaft angle, including explicit manual corrections. Terrain clearance still checks the entire visible head mesh. Acceptance no longer requires a nearly level world-space face angle, which would reject valid rigid-club configurations. Manual face controls, cancel, accept and undo remain available.

Existing saved face corrections are retained. If an older fit left an unwanted correction, use **Controls → Club attachment calibration → Reset selected hand attachment**, then fit again. Reset restores the club's normal lie correction; the new fitter preserves it.

## Validation

Focused suites pass: `cast_direction`, `cast_tolerance`, `tracked_cast`, `lure_fishing`, `golf_physics_review`, `golf_controls_feedback`, `golf_attachment`, `golf_head_contact`, `golf_vr_input`, and `golf_social`. Coverage includes behind-head overhand starts in both aim modes; release-before-process ordering; all eight club heads on flat/sloping ground; preserving explicit head corrections; both handedness settings and four approach directions; repeated teleports; new-round tee placement; retirement versus suspension; controller/palm attachment consistency; and full-head collision.

The dedicated three-process network regression also passes for server and both clients (`tools/test_golf_network.py --godot /usr/bin/godot`; logs in `test-results/host-golf-network/`).

Logs: `test-results/vr-fixes/`. Headless tests use synthetic tracked controllers and isolated saves. Local multiplayer checks require localhost access. Physical VR confirmation remains pending; no new VR session was launched for this review.
