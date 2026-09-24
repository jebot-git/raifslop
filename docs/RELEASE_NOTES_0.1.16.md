# Ultimate Boomer Simulator 0.1.16

- Corrected the initial golf club attachment for both hands. The controller can
  be held along the handle instead of sideways; fitting still changes the handle
  without rotating the head. Explicit manual head corrections are preserved.
- Existing profiles with the known incorrect default head orientation migrate
  automatically. If you fitted while holding the controller sideways, recapture
  the fit using your natural grip. Reset selected hand attachment restores the
  new defaults.
- Fixed persistent slow ball rolling on fairway and rough slopes. Ball stopping
  and downhill reversal now use consistent surface resistance. The captured
  failing shot rests in approximately 7.29 seconds rather than continuing past
  204 seconds. Steeper slopes still permit downhill reversal.
- Fixed Quest expansion mounting so verified OBB textures replace stale APK
  index entries. This addresses the resource-loading defect reproduced in Meta
  ALPHA build 18. The GitHub sideload APK includes its assets directly.
- PC launchers save engine logs beside the launcher (`Client-VR.log` or
  `Client-Server.log`); the dedicated server writes `Server.log` there. Extract
  packages into a writable folder. These logs contain the latest launch.

Linux and Windows x86_64 clients, the Linux dedicated server, a signed Quest
sideload APK, notices, SHA256 checksums and a source-commit manifest are supplied.
Packages retain texture deduplication, desktop HDR compression, native panorama
resolution and maximum archive/APK compression. Development artifacts and raw
test captures are excluded.

## Validation and limitations

The 19-suite golf audit passed, including controller input, collision sweeps,
fitting, terrain, energy checks and recorded-shot replays at 72, 90 and 120 Hz.
Additional hosted checks cover initial attachment and stowing for both hands.
Tests detect both defects when the old behavior is restored. See
[the fix and regression report](QUEST19_GAMEPLAY_FIXES.md).

The final grip/rolling fixes have not yet had a hands-on headset pass. The
earlier diagnostic Quest build reached fishing and golf, but Android killed it
for low memory when backgrounded. Windows VR runtime and WAN behavior have not
been retested for this release. Publishing does not update a live server.
Multiplayer protocol remains 16; use matching client/server versions.

**Quest signing:** this GitHub APK uses the existing local sideload certificate
(`539a4d25…`). Meta ALPHA uses a different certificate (`15f60496…`), so this APK
cannot update that installation. It is not a Meta Store release or the separate
`UBS Startup Test 19` app. The original Meta signing key remains unavailable here.
