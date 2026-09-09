# Prototype validation — 9 September 2026

Godot 4.7.2 stable, Linux, Intel ADL-N / Mesa. Godot MCP and Blender MCP both connected and used to create/import/inspect the project.

- 20 deterministic simulation/reel checks pass: cast bounds, bait locking and affinity, early/missed/timed strikes, correct/incorrect/repeated counters, successful catch and journal entry, over-tension and slack escapes, one full physical crank rotation including angle wrap, distance rejection, re-grab reset, tracking-jump rejection and grip release.
- Headless main-scene smoke run: 30 frames, exit 0, no script/runtime errors.
- Godot MCP runtime keyboard input verified Space cast, Space hook set and Left-arrow counter. Waiting time was advanced for that integration check.
- Accelerated simulation in the running scene landed a European perch; normal runtime state handling instantiated the model and wrote the journal. Saved journal contents were checked. The validation catch was then removed and the session returned to ready.
- Desktop framebuffer inspected, including catch display. `preview.png` is an actual runtime screenshot.
- OpenXR initialized under the installed Monado simulated HMD. The default action map includes grip/aim poses, trigger, grip, face buttons and haptics. No controller devices were provided by the simulated runtime. This verifies initialization only; physical casting/reeling, stereo appearance and headset frame time remain unvalidated.
- Initial Compatibility/OpenGL stereo shaders failed on this GPU (`gl_ViewID_OVR`). Mobile/Vulkan startup cleared those errors. The project defaults to Mobile.
- Perch's redundant UV channels were verified identical and merged in Blender. Textures reduced from 4K to 2K. Blender source saved with packed textures outside Godot's import path.

Known prototype limits are listed in the README. No standalone Android package or Gaussian splat renderer was built.

## Locomotion and avatars update

- `tests/avatar_locomotion.gd`: **24 checks passed**, including both real bundled VRMs, the exact 25,000,000-byte boundary, rejection at 25,000,001 bytes before library registration, malformed-file rejection, loading a copied `user://` VRM through the plugin, persistent selection, and preserving the previous avatar after invalid selection.
- Analytic IK checks preserve limb lengths and remain finite for coincident targets. A runtime skeleton check confirms the right hand reaches the desktop rod grip. First-person camera excludes the head-only layer.
- Physics integration checks exercise keyboard movement against the dock front rail, walking onto the shore, head-centered snap turning and paused locomotion in the avatar menu. Stick deadzone and bounded diagonal speed are checked.
- Original fishing suite remains **20/20 passing**: **44 checks total**.
- Desktop VRM selection and full-body preview inspected with Godot MCP. Both Vita and Victoria Rubin were equipped. The desktop grip was repositioned to be reachable without stretching the imported avatar's arms.
- Fresh OpenXR startup with the installed Monado simulated HMD completed without game script errors. The VR avatar panel opened through the controller-button handler, a VRM avatar was present, and locomotion paused. Physical controller ray interaction, grip orientation, comfort and headset frame time remain unvalidated because this runtime provides no controllers.
- Raw avatar sizes are 14,198,800 and 15,321,932 bytes, both below the per-file limit. Godot VRM and MToon dependency are included and the VRM editor plugin is enabled.
