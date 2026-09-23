# Lure direction and golf contact follow-up

Reviewed `/home/blux/Downloads/rec1.mp4` (41.40 s) and `rec2.mp4` (72.45 s). Both recordings show golf, not a lure cast. Overview frames cover both clips; denser samples cover repeated address/swing attempts in rec1 at about 12–37 s and rec2 at about 32–54 s, including a 12 fps inspection around 37.7–38.9 s. Extracted frames are in `test-results/recording-review-2/`.

In rec1 the ball stays at address through repeated swings before the view lifts at about 37.5 s. Rec2 shows several swings with the ball remaining at address around 34–53 s, followed by a flight trajectory around 55 s. These support the reported inconsistent-feeling contact. Screen projection alone cannot establish 3D intersection, grip/trigger state, tracking quality, or the precise rejection reason for an individual swing. The runtime log was not capturing per-swing analytics, so these findings are code reproductions rather than a pose replay of the videos.

## Corrected contact behavior

- The full rounded clubhead triangle mesh is the contact surface: face, back, toe, heel, crown and sole. The existing rigid impulse solver already supports body contacts with mass, inertia, friction and surface restitution; these remain physical body impacts rather than being redirected into face strikes.
- The controller pose used for a sweep previously omitted the avatar-palm position subsequently applied to the visible club. Palm correction now happens before the sweep. A later skeleton callback cannot move an armed club away from its sampled render pose. Controller-mounted mode and per-hand attachment offsets remain supported.
- Released grip/trigger previously reset a 150 ms cooldown every frame. Stable unarmed tracking now keeps a previous pose ready, so pressing either input immediately before a chip can register contact. Tracking gaps, discontinuities, locomotion and explicit interaction resets still invalidate samples.
- Moving contact is no longer discarded merely because the ball already partially overlaps the head surface. The mesh supplies the contact point and normal; only a positive closing velocity can produce an impulse. Stationary overlap does not launch the ball.
- A quick reversal could pass the raw contact test but fail the impulse solver because the smoothed velocity still pointed away. Such contacts now use the measured sweep velocity/angular velocity. Normal filtering remains in use when its contact velocity is physically closing.

`tests/golf_head_contact.gd` checks rendered/collision triangle agreement for all eight clubs, six rotated approach directions per club, physical impulses on every side, immediate arming, existing surface contact, stationary overlap, quick reversal, and tracking discontinuities. `tests/golf_attachment.gd` checks that the actual rendered palm-adjusted head matches the collision sample and is not moved afterward by an avatar callback.

## Corrected motion-cast behavior

The previous motion-only heading summed every forward-qualified horizontal displacement, including a fast sideways follow-through after the cast was ready. Heading and range now come from the strongest forward portion of the stroke, using a short movement window; a recovery backswing after completion locks that stroke. Sideways motion with little forward momentum no longer steadily drags the endpoint right or increases its range. No headset direction is added in motion-only mode.

The target validity check now uses a direction-appropriate epsilon for the saved movement window instead of requiring that short window to contain the whole cast's travel. The gesture still requires its normal measured back/forward travel before release. Existing range limits and head-aim target locking remain intact.

`cast_direction` tests left/right follow-through and recovery, while `tracked_cast` exercises real XRControllerTracker input, wrist arcs, diagonal swings, power, release targets, head independence and tracking gaps. No lure-casting sequence was present in these two recordings; the rightward-cast change is verified against reproduced motion paths and needs physical-user confirmation.

Validation: `golf_head_contact`, `golf_attachment`, `golf_controls_feedback`, `golf_vr_input`, `cast_direction`, `tracked_cast`, and `cast_tolerance` passed. The attachment/alignment suite also ran with desktop Vulkan and XR disabled. No VR session was launched for this follow-up.
