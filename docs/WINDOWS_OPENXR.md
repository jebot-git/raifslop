# Windows OpenXR support and capture troubleshooting

Ultimate Boomer Simulator uses Godot's native **OpenXR** interface on Windows. There is no
game-side Oculus/LibOVR or OpenVR backend to switch away from. The same Windows
executable uses the active OpenXR runtime, including Virtual Desktop's VDXR or
SteamVR OpenXR. Runtime selection happens before graphics initialization; restart
the game after changing it. Buying or launching through Steam does not by itself
select SteamVR as the OpenXR runtime.

The project explicitly selects Mobile/Vulkan on Windows and loads the saved
`openxr_action_map.tres`. The VR launcher requests `--xr-mode on
--rendering-driver vulkan`; the desktop and server launchers disable XR. Godot's
[XR guidance](https://godotengine.org/article/godot-xr-update-mar-2026/)
recommends Vulkan for Mobile/Forward+ XR on Windows. The engine used by 0.1.12
already defaults to Vulkan for this project: making it explicit is hardening.

## Select and verify a runtime

- **VDXR:** connect the headset through Virtual Desktop, select VirtualDesktopXR
  (VDXR) as the OpenXR runtime in Virtual Desktop Streamer settings, then run
  `VR.cmd`. The Virtual Desktop performance overlay should report `VDXR`.
  See the [VDXR setup and verification guide](https://github.com/mbucchia/VirtualDesktop-OpenXR/wiki).
- **SteamVR OpenXR:** start SteamVR with the headset connected, open its Settings
  > OpenXR and select **Set SteamVR as OpenXR Runtime**, then run `VR.cmd`.
  When using Virtual Desktop as the headset transport, select SteamVR in the
  Streamer's OpenXR runtime setting too. See the
  [Godot Windows PCVR guide](https://www.khronos.org/assets/uploads/developers/presentations/Godot_guide_to_OpenXR_for_Windows_PCVR.pdf).

For an existing release, this command requests the same API and renderer:

```bat
UltimateBoomerSimulator.exe --xr-mode on --rendering-driver vulkan --verbose --log-file "%TEMP%\UltimateBoomerSimulator-OpenXR.log"
```

Keep the EXE, PCK and supplied DLLs together. No OpenComposite or replacement
OpenVR DLL is needed. If a developer launcher sets `XR_RUNTIME_JSON`, that
process-level runtime override can supersede the runtime selected in the UI;
check it when the log reports an unexpected runtime.

Godot logs `OpenXR: Running on OpenXR runtime: ...` during engine startup. New
builds also emit `XR_STARTUP` with the application API, initialization status,
actual renderer/driver and runtime-provided `XRRuntimeName`, `XRRuntimeVersion`
and `OpenXRSystemName`. The normal log is at
`%APPDATA%\Godot\app_userdata\Real AI Fishing\logs\godot.log`. A successful
instance alone does not prove the headset is rendering: verify the final
`Ultimate Boomer Simulator ready | OpenXR` line and the in-headset view. If initialization
fails, the VR-only client exits with `VR_REQUIRED`; inspect the earlier loader,
graphics or session error and restart after correcting the runtime/headset setup.

## Resolved external report

The user confirmed that the reported Virtual Desktop/VDXR error was caused by
an external blocker and should be disregarded. It is not evidence of a game
OpenXR compatibility defect. The earlier capture-detection hypothesis is no
longer an active investigation; no further reporter logs are needed for it.
The controller binding fixes and runtime diagnostics above are independent of
that report.

## Spectator capture

If VR works but capture fails, try capturing the game's desktop spectator window,
or test SteamVR OpenXR if that is the capture tool's supported path. Capturing
the desktop window records the mono spectator camera, not a headset eye image.
Switching runtime does not guarantee that an external capture tool supports
Godot's Vulkan submission path.

## Controller coverage and verification limits

The saved map includes Touch (used by Quest/VDXR), Pico, generic controller,
Index, eye gaze, hand interaction and Vive tracker roles. Index previously had
only touch-sensor bindings; it now explicitly includes both hands' aim/grip
poses, trigger, squeeze, sticks, A/B buttons and haptics. Vive **tracker** roles
are not Vive wand bindings. Other controller types rely on runtime mapping of
the supplied profiles and need their own acceptance testing. Optional tracking
extensions are not prerequisites for controller gameplay.

`tests/openxr_support.gd` checks the saved and exported controller bindings and
OpenXR configuration. Run it with XR disabled on a development host, or against
an exported Windows PCK using `--main-pack` and an absolute script path.
These checks do **not** establish Windows runtime or capture compatibility.

Before claiming tested Windows support, run both VDXR and SteamVR on Windows and
record the runtime/version, GPU/driver and headset/controllers. Verify stereo
rendering, head and hand poses, movement/turning, casting/reeling, menu and tackle
controls, haptics, spectator capture and restart after a runtime switch. On this
Linux development host, physical Windows runtime acceptance remains untested.

Validation for this change: the source and a fresh Windows export pass
`openxr_support.gd`; the previous Index map fails its missing-input checks.
The existing `hand_tracking.gd`, `tracking_orientation.gd` and desktop
`spectator_camera.gd` tests also pass. Windows EXE/PCK/DLL export completed;
the editor emitted sandbox-denied IPC socket messages, with no export failure.
The PCK check ran under Linux Godot and verifies packaged resources/configuration,
not execution of the Windows EXE or a Windows OpenXR session.
