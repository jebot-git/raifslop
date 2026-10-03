# 0.1.19-rc.2

This release candidate tidies the shared field station and improves minigolf movement and lobby recovery.

- Five main menu sections: Activities, Player, Together, Settings and Progress. Minigolf rounds, scorecards, putter fitting, controller alignment and voice controls have separate subsections. Navigation and persistent actions fit the VR panel.
- Minigolf retains grip-to-lock movement for a steady putt. Release grip and center the sticks to move again. Two-controller play uses left-stick movement and right-stick turning; a single controller still handles both.
- Leaving an online lobby automatically clears local membership and drains pending connection work. A new host or join request replaces an older attempt after cleanup, including delayed lobby and Meta presence callbacks.
- Small fixed tee signs show hole numbers, names and pars across all 216 holes. Existing course lightmaps are retained. Bundled Noto Sans and Noto Serif provide consistent interface and sign typography.

Validation includes minigolf rules, terrain, fitting, locomotion, save restoration, course lightmaps and signs; menu layout, pointer controls and scrolling; and offline EOS lifecycle tests covering immediate rehost/rejoin and cancelled callbacks. Menus and tee signage were rendered and visually inspected. This does not establish physical-headset performance or live Meta/EOS acceptance.

Android version code 27. The Quest APK and its matching `main.27.org.jebot.raifslop.quest.obb` must be installed together. GitHub distributes the OBB in a lossless ZIP; extract it before sideloading. PC clients and the dedicated server retain protocol 21. This is a prerelease and does not replace the stable GitHub latest release.
