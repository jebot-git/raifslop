# Real AI Fishing 0.1.2

This release fixes VR menu interaction and removes documentation and screenshots from the downloadable packages. Asset credits and third-party license notices remain included. Documentation is available in the repository.

- Import .vrm stays visible in the Avatar menu and opens a folder browser inside the headset. Browse Home, Downloads or a typed path, then select a VRM and Open. The browser blocks clicks into the menu behind it.
- The keyboard stays inside the VR panel, including its bottom row and Done button. It shows the text being edited and supports Shift, spaces, slash, underscore, caret movement and Backspace.
- The laser still starts at the fingertip, while controller aim remains independent of trigger-driven finger curl. Light smoothing stabilizes the cursor, and presses use the displayed position.
- Drag scrolling starts on empty page background. Button presses, text input and keyboard interaction no longer drag the underlying page.

Linux and Windows archives include desktop, VR and dedicated-server launchers. Quest and Pico APKs reuse the 0.1.1 signing key and can update that version in place. Updating from 0.1.0 still requires uninstalling the older APK because its signing key is unavailable; preserve accessible saves first.

Validation includes automated VR menu/VRM import checks, the regression suite and connected WiVRn interaction tests. Windows and standalone Quest/Pico execution still require platform acceptance testing.
