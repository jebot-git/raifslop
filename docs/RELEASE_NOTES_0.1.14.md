# Real AI Fishing 0.1.14

Restores shared multiplayer BBQ, improves seated tracking and casting, and fixes
fishing feedback and scenery defects reported by players.

## Tracking and fishing

- Preserve tracking origin and scale during calibration, with head alignment that
  respects full-body tracking and seated poses.
- Improve sidearm and seated casts, low-frame-rate motion handling, and casting
  when the offhand loses tracking.
- Match guide button contact to the rendered avatar fingertip, addressing the
  reported Windows Virtual Desktop offset.
- Highlight fishing styles while rotating the thumbstick; commit on return to
  neutral. Stick clicks still open and close the radial menu without holding.
- Move lure tackle laterally with rod twitches and show a directional ripple that
  follows each twitch, including immediate left/right reversals.
- Keep the bobber shaking and hopping when a fish reaches the shore boundary
  while still fighting.
- Add two to four light feeder nibbles before a stronger bite, with distinct
  pulses and vibrations. Striking or reeling during nibbles fails the cast;
  the actual bite allows 3.5 seconds to hook the fish.

## Shared BBQ and art

- Restore one shared BBQ per location, with synchronized cooking, two sets of
  tongs, serving, food and drinks on dedicated and player-hosted sessions.
- Use the new grill, cooler and utensil assets, with a supported arrival area
  and return to the original fishing position.
- Keep the guide and camera available while cooking. Return held props on guide
  use, travel, tracking loss or focus loss.
- Replace floating BBQ instructions with contextual guiding icons that respect
  the icon preference and stay out of camera photos.
- Rebuild the fish burger, sausage, corn and mushroom in Blender with baked
  color, normal and roughness detail; retain cooking and grill-mark effects.
- Repair fish eye artifacts and rear-back holes, and correct the striped texture
  distortion introduced by the initial back repairs.
- Remove the Lake Pier corner railing overlap, ground Secluded Beach rocks,
  and suppress distant underwater mask-edge lines.

## Packages and validation

Linux and Windows x86_64 clients, a separate asset-free Linux dedicated server,
and a signed Quest APK. Archives use maximum deflate compression; the APK is
recompressed, aligned and signed. Checksums and a commit manifest are included.

Validation covers automated gameplay, synthetic VR inputs, fish mesh/UV checks,
and real local dedicated/player-hosted multiplayer connections. Food and scenery
were visually reviewed in Blender and Godot during development. Release checks
also verify packaged resources, Linux startup and Android signing/alignment.

Multiplayer uses **protocol 11**: update clients and dedicated servers together.
Publishing this release does not update an existing live server. Windows Virtual
Desktop and physical-headset behavior for these changes have not been tested on
this Linux host; earlier Quest 3 acceptance does not validate this build. Pico
remains retired and hands-only gameplay remains in planning.

[BBQ controls](BBQ.md) · [Build instructions](RELEASE.md)
