# Real AI Fishing 0.1.13

Adds a waterside BBQ minigame with manually flipped food, working grill tongs,
a hinged portable cooler, and beer cans that open and drink in separate actions.
Start or finish from **Menu → BBQ**, or press **B** on desktop.

## BBQ

- Prepare fish burgers and fish species caught at the current location. Local
  catch records unlock repeatable recipes; catches elsewhere do not unlock them.
- Grip food with either controller, turn your wrist, and release onto the grate.
  Each side cooks independently, developing browning, grill marks, and char.
- Grip the tongs and hold the trigger to clamp food. Opposing jaws open vertically,
  close around the food's thickness, and reopen on release. Wrist motion flips
  the food; releasing the trigger puts it down while retaining the tongs.
- Food is eaten only at your mouth or with the holding-hand trigger. Clamped
  food can be eaten at your mouth while keeping the tool.
- Beer cans start hidden inside the cooler. Its lid lifts toward the rear hinge.
  The first trigger opens a can with a tab snap and hiss; bringing the opened
  can to your mouth or pressing the trigger again drinks it.
- Ending BBQ hides the whole activity, docks held tools, and restores the rod.
  Tracking or focus loss releases held items safely. Only one pair of tongs is
  created across repeated cookouts.
- Includes original Blender-authored grill, prep area, cooler, food, cans, tongs,
  and generated opening/sizzle audio. BBQ state is local, not multiplayer-synced.

## Other changes included from main development

- Windows PC VR explicitly uses Vulkan, with OpenXR runtime setup and spectator
  capture troubleshooting documented.
- The rig selector opens with a stick click and stays open until a selection,
  another click, or menu dismissal; holding the stick button is no longer needed.

## Packages and validation

Linux and Windows x86_64 clients, an asset-free Linux dedicated server, and a
signed Quest APK. ZIPs use maximum deflate compression; the APK is recompressed,
aligned, and signed. Downloads include SHA256 checksums and a commit manifest.

The BBQ regression suites cover 157 assertions, including synthetic controller
inputs for both hands, cooking, consumption, tongs animation, lid geometry, and
repeated start/stop cleanup. Release audits check that BBQ assets are included
and development files are excluded; packaged-game checks exercise BBQ startup,
tongs pickup, and exit visibility.

Blender and Godot rendered inspection was completed during development. Physical
headset comfort and performance for the new BBQ activity have not been validated.
Quest 3 acceptance applies to the previous release; Windows execution was not
available on this Linux host. Multiplayer protocol remains **10**. Pico releases
remain retired, and hands-only gameplay controls remain in planning.

[BBQ controls and implementation](BBQ.md) · [Build instructions](RELEASE.md)
