# Real AI Fishing 0.1.1

This update improves VR interaction, avatar tracking and fishing feedback, with native 8K scenery at all four waters.

- Refreshed FPSloppa-derived IK and tracking, including VRM pose initialization, finger and wrist alignment, raised-foot estimates and T-pose calibration.
- Physical right-index presses turn Fish Guide pages. The guide shows location, earnings and equipped bait; its grip, hip placement and camera lens placement are corrected.
- Fold and stash the rod at the right hip to free the hand. Holding the guide keeps the rod equipped until explicitly stashed. Reel animation follows physical winding direction.
- Fish counters require sustained correct input. Repeated failed counters or prolonged slack/excess tension let fish escape. Bites, fights and rising tension produce rumble; fight resistance remains hidden.
- Catches match their reported length, including the corrected perch orientation. Holding a catch in the left hand displays its name, length and weight above the fish.
- Removed the floating VR status/tracking window and automatic tutorial popup. Tutorial and Quit are menu buttons. Fish here stays visible without scrolling, and successful travel closes the menu.
- Benches and boat seats no longer block movement. Fish land before the foreground hides the bobber. VR menu rays originate at the fingertip.
- Native 8K panoramas use bounded sharpening, colour enhancement and corrected wrap-seam sampling. Water shares the panorama treatment. Each environment has quieter recorded ambience.
- Settings are flushed on exit; tracking recovery clears stale warning state without a VR popup.

Linux and Windows archives include desktop, VR and dedicated-server launchers. Quest and Pico packages are ARM64 sideload APKs. Keep the included asset credits and third-party notices when redistributing.

Android upgrade notice: the previous release signing key was unavailable. Version 0.1.1 uses a new signing identity, so Quest/Pico users must uninstall the older APK before installing this one. Uninstalling can erase app-local saves; preserve accessible save data before removing the old installation. Future updates can reuse the new key.

Validation includes the 24-suite regression set, fresh-process settings persistence, multiplayer integration and connected WiVRn stereo catch/menu checks. Windows and standalone headset execution require platform acceptance testing; WiVRn PC VR checks do not establish standalone performance.
