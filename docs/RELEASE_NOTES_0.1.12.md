# Real AI Fishing 0.1.12

Quest standalone releases return after physical Quest 3 testing and user approval
of performance. This release also fixes fishing presentation and lure attraction,
aligns the VR avatar with the player's viewpoint, and adds adjustable selfie framing.

## Fishing and presentation

- Feeder bait is packed inside the cage; the external bait and dangling hook display
  are removed for feeder rigs, including remote anglers.
- Left/right rod twitches and slow retrieval increase lure attraction. Attraction
  falls while the lure is stationary, and twitches move it sideways.
- Waters selection uses the Fish Guide's location names.
- Visible swimming fish face their movement direction.
- Leervis fins use continuous traced outlines to remove the jagged, folded fin edges.

## VR and cameras

- Avatar eyes align with the headset viewpoint; shoulders and arm IK share that
  frame through room-scale movement, crouching and head rotation.
- With the selfie camera active, right-stick up/down extends/retracts the capture
  point by up to 3 metres. Collision limits prevent the camera passing through scenery.
- PC VR includes the third-person spectator view from the latest main branch;
  feeding indicators remain confined to the player's view.
- Android avatar storage now resolves correctly through Godot's Java bridge.

## Packages and validation

- Linux and Windows x86_64 clients, Linux dedicated server, and signed Quest APK.
- Physical Quest 3 standalone testing passed; the user accepted performance.
  Short native headset samples typically reached 72 FPS after loading.
- WiVRn headset testing confirmed comfortable selfie adjustment and stable shoulders.
- 20 targeted regression suites passed, covering fishing, avatar IK, guide/camera,
  tracking, assets, Android path integration and the spectator camera.
- Hand-tracking controls remain a plan. The feasibility probe and overlay are removed
  from the release; existing tracked avatar fingers remain available.
- Multiplayer protocol remains **10**. Pico is not a release target; other Quest
  models and Windows execution have not been tested in this validation session.

Packages retain attribution, deduplicate runtime textures, and use maximum ZIP/APK
compression with signing and integrity checks. SHA256SUMS and a build manifest
accompany the downloads.

[Validation record](validation/release-0.1.12/checks.json) ·
[Build instructions](RELEASE.md) · [Hand-control plan](HAND_TRACKING_CONTROLS.md)
