# Ultimate Boomer Simulator 0.1.17

- Golf fitting remembers your chosen controller pose. The shaft follows the
  straight line from your grip to the hosel at the address point behind the ball,
  while the head retains its intended loft. Grip calibration survives rejoining;
  recapturing does not accumulate rotation. Manual attachment controls remain
  available. Refit once to replace an older incorrect calibration.
- In one-hand golf, the held controller's stick moves forward/back and turns,
  including when the other controller is laid down but still tracked. Grip with
  an empty hand equips the club away from the hip; nearby guide pickup takes
  priority. Either hand and both analog/digital grip can retrieve the hip club.
- Fixed resumed multiplayer solo-course activation and club pickup paths.
- Restored water ambience after returning from golf. Each water retains its
  own soundscape; woodland and links golf courses use separate golf beds.
- Cedar Creek's logs now use the established textured driftwood and sit against
  the bank rather than floating.
- Startup and Quest loading screens use the full store logo.

Linux and Windows x86_64 clients, a Linux dedicated server, a signed Quest
sideload APK, notices, SHA256 checksums and a source-commit manifest are supplied.
Obsolete generated binaries were removed locally. Packages exclude development
files and test captures, deduplicate textures, retain native panorama resolution,
and use desktop HDR compression and maximum ZIP/APK compression. PC launcher
logs remain beside their launchers.

## Validation and limitations

The tester confirmed the corrected fitting in the connected Quest Pro through
WiVRn: “Fit is correct now.” Automated coverage includes 96 address geometry
cases across clubs, hands, slopes and directions; orientation persistence,
recapture, controller input, guide priority, local multiplayer solo pickup,
ambience restoration and Cedar bank contact. The integration golf audit also
covers collision, ball physics, terrain and course lanes.

Windows VR and the newly exported standalone Quest package have not had a
hands-on pass for this release. The WiVRn result is PC VR validation. Multiplayer
protocol remains 16; use matching clients and server. Publishing does not update
a running server.

**Quest signing:** the GitHub APK uses the existing local sideload certificate
(`539a4d25…`), which differs from Meta ALPHA (`15f60496…`). It cannot update that
ALPHA installation. This release does not publish to Meta or Steam.
