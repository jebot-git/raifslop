# Meta Avatars feasibility

Investigated 14 September 2026. Recommendation: retain VRM as the default and consider Meta Avatars as an optional Quest-first provider after a bounded native-integration prototype. Windows PC VR is a plausible second target. Native Linux should retain VRM. No avatar runtime or account configuration was changed during this investigation.

## Current SDK status

Meta marks **40.0.1 as the final release**, at End-of-Feature status. It says backend services remain operational and developers may still submit apps; there are no planned SDK releases or additional APIs. This makes a new custom engine integration a maintenance commitment. [Official SDK download/status](https://developers.meta.com/horizon/downloads/package/meta-avatars-sdk/).

The current supported integration documentation and package target Unity. The older native “Oculus Avatar SDK” documentation explicitly discourages new development and should not be mistaken for a current Godot integration. [Current overview](https://developers.meta.com/horizon/documentation/unity/meta-avatars-overview/), [legacy native SDK](https://developers.meta.com/horizon/documentation/native/pc/as-avatars-sdk-intro/).

## Platform assessment

| Target | Assessment for this Godot game |
|---|---|
| Quest standalone / Android ARM64 | Plausible custom adapter; matching native binaries exist. Requires Quest export setup, Meta identity/service access and device testing. |
| Windows PC VR with Meta platform identity | Plausible custom adapter; Win64 binaries exist. Separate PC App ID and authenticated PC test required. Quest streaming through Link does not itself prove avatar authentication works. |
| Windows SteamVR / other headsets | Meta documents federated cross-play. Requires separate federation/authentication integration; do not assume arbitrary Steam users can import their personal Meta avatar through an ordinary login. |
| Native Linux / Monado / WiVRn | No Linux desktop avatar binaries in the inspected package. Keep VRM. A Quest streaming a Linux game does not make the host process Android. |
| Non-VR PC mode | The proposed adapter could accept simulated pose inputs, but authenticated desktop-only use remains unvalidated. Keep the current VRM path initially. |

Quest and PC releases require separate App IDs; grouping them supports consistent avatars across platforms. Avatar access requires Data Use Checkup entries for User ID, User Profile and Avatars. [Meta app configuration](https://developers.meta.com/horizon/documentation/unity/meta-avatars-app-config/).

Meta's cross-play guide documents federation for SteamVR and Windows Mixed Reality, including federated user tokens. This is a service integration path, not an included Godot renderer or proof of Linux support. Any app-secret operations should live on a backend, not inside distributed game binaries. [Official cross-play guide](https://developers.meta.com/horizon/documentation/unity/meta-avatars-cross-play/).

## Package and Godot evidence

Downloaded the official `com.meta.xr.sdk.avatars` 40.0.1 tarball into `/tmp` for inspection, without installing it into the game. Its SHA-1 matches registry metadata: `402f13fd74d54abe32d79cc1e6b611eeafcbbd7c`. [Official package registry](https://npm.developer.oculus.com/com.meta.xr.sdk.avatars).

Observed `libovravatar2`, `libovrbody`, `libovrgpuskinning`, `libovrplugintracking` and `libxrtracking` libraries under Android32, Android64 and Win64. No Linux desktop binaries or C/C++ header files were present. Supplied C# CAPI declarations expose initialization, asset/resource callbacks, geometry/image access and updates, but use Unity types. This supports the inference that a bridge is technically plausible; it is not a demonstrated standalone native API integration.

Inspected [Godot Meta Toolkit](https://github.com/godot-sdk-integrations/godot-meta-toolkit) at revision `88c73dc43de879e55226e6e2cabc0047df9533fb`. Its tree contains `MetaPlatformSDK_AvatarEditorOptions.xml` and `MetaPlatformSDK_AvatarEditorResult.xml`, but no avatar-renderer implementation was found. It can contribute platform authentication and entitlement services; those services are distinct from loading and rendering an avatar. [Toolkit platform setup](https://godot-sdk-integrations.github.io/godot-meta-toolkit/manual/platform_sdk/getting_started.html).

## Proposed integration in this project

The game uses Godot 4.7's Mobile renderer and GDScript. `avatar_rig.gd` assumes VRM bone names, installs its own IK solver, and manages first-person visibility. Meta avatars should therefore have a separate provider rather than being passed through the VRM importer.

A proposed C++ GDExtension would bridge the native SDK's lifecycle, resource callbacks, mesh/material conversion, skinning and tracking input. Its Android and Windows builds would need separate validation. The Unity rendering/animation layer would need Godot equivalents; DLL availability alone does not settle those requirements. Confirm the permitted external-engine integration surface before committing to this work.

Expose provider selection through the existing avatar menu, retaining the selected VRM as fallback during loading, offline play, authentication failure or unavailable platform support. Normalize both providers around the existing `update_targets` inputs. Preserve first-person head hiding, rod-hand alignment, string-held fish inspection and the Field Guide's lower-handle clearance. Continue using headset-center casting aim with **no eye-tracking dependency**.

## Licensing and prototype exit criteria

The package includes the Meta Platform Technologies SDK License Agreement, dated 25 October 2022. It permits SDK-based application development subject to its conditions, limits broader platform use to documented permissions, and includes redistribution/notice and modification restrictions. Treat avatar content as SDK-managed content, not an asset source for exporting permanent VRMs or GLBs. The legacy Avatar SDK 1.0 license is not the license included in this package. [Current license](https://developers.meta.com/horizon/licenses/).

A useful first prototype would demonstrate one SDK avatar in a separate Godot Quest scene: correct stereo rendering, head/hands, material appearance, first-person masking, clean shutdown and graceful fallback. Then test an authenticated user's avatar with approved app access, followed by rod/guide interaction and measured GPU/CPU cost. Only after that should Windows identity and Steam federation be added. No Meta avatar was rendered or authenticated in this investigation; prior synthetic XR tests validate the game's XR plumbing, not this SDK.
