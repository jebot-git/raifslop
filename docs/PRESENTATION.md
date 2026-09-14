# SharkPerson, ambience and Field station menus

Implemented 14 September 2026.

## Default avatar

New profiles equip Polygonal Mind's **SharkPerson** from the CC0 100Avatars R2 collection on [Open Source Avatars](https://www.opensourceavatars.com/en/gallery?avatar=sharkperson). Saved selections remain selected. All three bundled avatars remain available and are recognized by multiplayer peers. The 1.74 MB model has a humanoid skeleton, finger bones, five vowel expressions and left/right blink bindings.

The original VRM had a trailing empty duplicate `Blink_L` entry that replaced its working declaration during Godot import. `tools/prepare_shark.py` removes that duplicate without changing binary geometry, textures or expression weights. It rebuilds the bundled asset from `source/avatars/sharkperson_original.vrm.gz`. [Metadata and hashes](sharkperson_source.json) and [license notice](../assets/avatars/sharkperson.LICENSE.txt) preserve provenance.

## Location sound

Four 128-second stereo Ogg Vorbis loops combine CC0 water and bird recordings with authored wind. The cove has birds over gentle water; Lake Pier emphasizes water; Gray Pier emphasizes nearby birds with softer, filtered water; Bell Park's moored boat adds stronger wind and lapping. Source recordings are curated ambience, not recordings of the panorama locations.

Runtime beds fade across two seconds when travelling. Stopped streams are released. An occasional timber sound is spatially positioned near the pier or boat, with varied timing and pitch. Sound preferences persist in `user://sound.cfg`; voice chat has separate controls. Dedicated servers do not instantiate ambience.

Rebuild with `python3 tools/build_ambience.py` (Python standard library and ffmpeg). Source FLAC excerpts, exact download URLs, authors and CC0 notices are in [source/audio](../source/audio/CREDITS.md). Four-second overlapping sections create loops; filtering, conservative mixing and limiting avoid clipped peaks. The shipped Ogg files total about 7.5 MB. Measured bed peaks range from −14.8 to −10.2 dBFS; average levels range from −32.4 to −28.4 dBFS before the runtime volume control. [Output manifest](ambience_assets.json).

## Menu

Open with desktop **V** or VR **right B**. The **Avatar**, **Waters**, **Together**, **Tracking** and **Sound** tabs share a pine-green panel, cream text, brass selection and serif heading. A persistent Return to the water button closes the panel. Long pages scroll; FPSloppa-derived drag scrolling and selectors operate inside the VR SubViewport. Focusing multiplayer text inputs in VR opens an in-panel keyboard with deferred key delivery, Shift, Space, Delete and Done. Desktop retains physical keyboard input. Importing a local VRM still uses the existing OS file dialog.

See [reuse details](FPSLOPPA_REUSE.md). Screenshots: [Avatar](menu_avatar.png), [Waters](menu_waters.png), [Together](menu_together.png), [Tracking](menu_tracking.png), [Sound](menu_sound.png), [VR panel](menu_avatar_xr.png).

## Validation

- **31 passed**, `tests/shark_ambience_menu.gd`: new-profile default, rig expressions, tabs, selectors, keyboard, all four loops, crossfades, mute and saved volume.
- `tests/presentation.gd`: desktop tab/layout screenshots and native Monado simulated OpenXR tab selection, panel bounds, controller-ray focus and keyboard input.
- Existing avatar tracking/calibration: **26 passed**. Avatar/locomotion: **26 passed** against all three bundled models.
- `tools/test_multiplayer.py`: dedicated, ad-hoc and late-join integration passed with the new default avatar.
- `tools/test_multiplayer_xr.py`: **13 passed**, native synthetic stereo/controller/body/face session plus a separate desktop client, including actual eye texture readback and replicated tracking.

These tests use synthetic OpenXR input, not physical headset/controller measurements. The native runtime retains its previously observed session-shutdown/spatial-signal/four-profile RID diagnostics. Headless scene tests can also report ObjectDB/resource cleanup warnings at process exit; assertions complete successfully.
