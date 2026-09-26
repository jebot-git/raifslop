# Basic optical hand interactions

Put the controllers down and let the runtime switch to optical hands. Open your
hands briefly after tracking starts or returns, then:

- Hold thumb and middle fingertip together for 0.65 seconds to open/close the
  menu. Release before doing it again. This works with either hand.
- Point the right hand and pinch thumb/index to select. Golf uses the preferred
  striking hand; a sole left hand can also navigate. Release to activate buttons.
  The menu footer's up/down buttons and pinch dragging scroll pages.
- Hold a right index pinch, sweep the rod back and forward, then release to cast.
  Both the existing motion-cast and head-aim preference remain available.
- Pinch or curl the left hand near the reel and turn the handle. For fly fishing,
  pinch the line and pull to strip. Opening the hand releases the grip.
- Curl the striking hand to arm the golf club, then swing through the ball.
  Opening the hand disarms it. Hands use the natural club attachment; saved
  controller attachment/fit settings are restored when a controller is picked up.

There are no hand gestures for movement, turning, teleporting or addressing the
ball. Move physically within the playspace or use controllers for locomotion.
Existing menu actions such as changing waters/courses remain available.

The Quest export requests high-frequency hand tracking for casting and club
motion. Controller support remains optional alongside optical hands.

Optical joints feed private per-hand XR action trackers; the runtime's original
controller trackers and their inputs are untouched. Controller-inferred joints
never activate gestures. Unknown joint sources are accepted only when there is
no tracked controller or the runtime identifies a hand interaction profile.
The native wrist uses the same humanoid-to-grip mapping as the avatar; the menu
ray prefers a runtime hand aim pose and otherwise uses wrist orientation so
pinching does not redirect it along a curled fingertip.

Pinches have distance hysteresis and a short press debounce. Tracking loss,
focus loss, source changes, implausible pose jumps and frame gaps cancel pending
casts, UI presses and golf swing history. Reacquisition requires an open hand;
missing tracking is never interpreted as a deliberate cast release. Native
joint tracking flags supply the physical swing's confidence.

Validation:

```sh
godot --headless --xr-mode off --path . --script tests/hand_actions.gd -- --xr-test
```

This fixture drives real menu input, completes a fly cast, enables physical
reeling, swings a hand-driven club into a ball, and checks cancellation and
controller handoff. On Quest, additionally verify both handedness settings,
optical/controller switching, an ordinary pinch click versus a held menu
pinch, rod and club orientation, a backswing near the tracking boundary, reeling
and fly stripping. Synthetic tests cannot validate optical accuracy or comfort.

Godot's [hand-tracking documentation](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_hand_tracking.html)
describes the source flags and differences between runtime hand action profiles.
