# Golf fitting and controller input fixes

Fitting captures a comfortable controller pose and solves club length. A per-hand controller-relative rotation places the club at address with its authored loft; the shaft angle and length then follow the straight line from the actual grip to the hosel at the address point behind the ball. The head retains its calibrated address orientation while the handle connects to it. Subsequent controller motion rotates both together. The offset is previewed before accepting, persists across rejoining, and is restored by cancel/undo. Repeated capture does not accumulate rotation. Manual shaft and face corrections remain under Controls; resetting a selected hand also clears its captured grip offset. The controller's positional offset and shaft thickness are unchanged.

This supersedes the earlier length-only fitting behavior following the explicit request to calibrate the player's chosen controller pose.

When the other controller is absent or idle on a surface, the held controller's stick controls forward/back movement and turning. This also works while the club is stowed. Swing-armed movement locking remains in effect.

Either hand can retrieve the hip club using analog squeeze or digital grip. An explicit pickup changes the selected club hand. In one-hand mode, an empty-hand grip can also equip the club away from the hip. Nearby guide pickup takes priority; a hand holding the guide, radio or a BBQ object cannot use this shortcut. Stowing still requires a fresh grip near the club hip mount.

## Verification

Headless controller fixtures passed for both hands, missing and still-tracked idle controllers, guide priority, occupied guide hand, held-grip debounce, two-controller proximity gating, snap/smooth turning, fitting, and manual attachment persistence. The real local ENet server/client fixture passes first solo join, retained solo membership, analog/digital pickup and nonpreferred-hand pickup. The digital and nonpreferred-hand cases failed before the equipment fix.

Suites: `golf_address_line.gd`, `golf_fit_orientation.gd`, `golf_controls_feedback.gd`, `golf_attachment.gd`, `golf_vr_input.gd`, `golf_solo_join.gd`, `golf_fit_invariants.gd`, `golf_fitting_analytics.gd`, `quest19_golf_regressions.gd`, `golf_physics_review.gd`, `golf_physics.gd`, and `golf_social.gd`.

Evidence is in `test-results/length-only-fit/`; current reruns use `controls.log`, `attachment.log`, `vr-input.log`, `solo-server.log`, and `solo-client.log`. Earlier failing fixtures and before-fix logs remain for comparison. Test shutdown reports retained ObjectDB instances (and a retained resource in the multiplayer fixture); functional assertions pass. The live WiVRn pass confirmed correct head orientation but exposed head placement ahead of the ball. The follow-up address solver passes 96 club/hand/slope/direction cases and the controller, attachment, recapture and reload fixtures (`address-line.log`, `orientation-address.log`, `golf_controls_feedback-address.log`, `golf_attachment-address.log`). On 24 September 2026 the updated session (`builds/AddressPlacementVRTest-2026-09-24/`) ran through WiVRn on the connected Quest Pro; the tester confirmed: “Fit is correct now.” This validates the corrected fitting in PC VR, not a standalone Quest build.
