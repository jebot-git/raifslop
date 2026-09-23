# Golf club attachment calibration

Golf Controls now includes **Club attachment calibration**. In the integrated fishing client, open the shared **Controls** tab while on a golf course and scroll to **Club attachment calibration**. Standalone golf exposes it under its own **Controls** tab.

1. Select the left or right hand to edit. This does not change your swing handedness.
2. Enable **Controller-mounted club / physical attachment** when your controller is fixed to a golf attachment. The club then follows the calibrated controller rather than snapping to the avatar palm.
3. Adjust **Grip position** in centimetres: X right, Y up, Z backward, relative to that controller's calibrated local axes. Each axis supports −100 to +100 cm, in 0.5 cm steps.
4. Adjust **Shaft rotation** and **Clubface correction** in degrees, with separate pitch/X, yaw/Y and roll/Z settings. Large −/+ buttons work with VR pointer clicks; numeric fields also allow desktop entry.
5. The cyan VR preview shows the selected hand's grip/shaft/head alignment while the controls are open. It has no collision and cannot hit the ball. Turn it off with **Show cyan attachment preview in VR** if it obscures the view.
6. Use the existing **Fit club** address-pose calibration for the current swing hand to set angle and reach from a steady address pose. Its sampling includes the configured grip offset. Automatic fitting moves the whole club and adjusts reach; it preserves the head’s existing angle relative to the shaft, including manual clubface corrections. The full head mesh is kept above the local terrain. Accept/cancel/undo retain their existing behavior.

Changes save immediately in `user://golf_controls.cfg`. Position, shaft rotation, clubface correction and controller-mounted mode are independent for each hand. **Reset selected hand attachment** resets only that hand, including restoring the normal clubface lie-angle correction and avatar-palm mode. If an older automatic fit left an unwanted face correction, reset the selected hand before fitting again. The existing club reach multiplier remains shared between hands and now saves immediately too.

Golf attachment adjustments do not modify the shared controller calibration used by fishing. In avatar-palm mode, positional offsets are applied relative to the palm instead of being discarded. The support hand follows the calibrated club grip. Physical contact uses the same adjusted clubhead pose as its visual representation.

Verification: `tests/golf_attachment.gd` covers units, per-hand isolation, live transforms, controller/palm attachment modes, support hand, address-fit sampling/cancellation, collision-free preview, persistence, invalid values and resets. Existing golf control and VR pointer regressions cover the shared interaction paths. Physical headset testing requires a separate approved VR launch.
