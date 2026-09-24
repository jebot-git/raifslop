# Ultimate Boomer Simulator 0.1.15

The integrated fishing, golf and BBQ game is now **Ultimate Boomer Simulator**. The icon, Android package identity and existing save locations are preserved.

- Golf courses gain improved terrain textures, blended terrain edges and water shading. Ball guidance follows playable lanes instead of aiming straight through out-of-lane terrain.
- Golf contact handling starts with 2 mm of tracking tolerance, with updated swing/contact and attachment controls. Tackle selection applies matching cosmetic finishes to drivers, irons and putters without changing club performance.
- Cedar Creek and Glacier Run add two fly-fishing waters, with cutthroat trout and Arctic char, new ambience, cardboard trees and matching rock materials.
- Waters are grouped into Lakes, Rivers and Coasts. Shared menus support drag and joystick scrolling; scrollbars indicate position without capturing input.
- Texture mipmaps were audited, including imported models and avatars. Mobile rendering remains the default for Quest; Forward+ has not been validated on standalone hardware.
- Includes editor integration updates and reproducible asset-generation sources, excluded from runtime packages.

## Validation and limits

Dedicated-server loopback tests passed golf competition, 18-hole turn flow, all four tackle palettes across three club families, BBQ ownership, malformed-command rejection and restart persistence (153 golf checks). Fishing multiplayer passed replication, avatar transfer, late joins, fixture-based Opus voice, location filtering and leaderboard persistence. See [network validation](NETWORK_VALIDATION_2026-09-24.md), [fly expansion](FLY_EXPANSION.md), [club styling](GOLF_TACKLE_STYLING.md) and [tracking tolerance](GOLF_TRACKING_TOLERANCE.md).

Some unreliable pose packets exceed ENet's MTU. Loopback passed; Wi-Fi loss tolerance needs hardware testing. This release has not been validated on a physical Quest, a Windows VR runtime or a WAN connection. Scripted golf completion verifies networking rather than real swing physics. Pico remains unsupported. Controller input remains the supported gameplay path.

Clients and servers must be updated together (protocol 16). Publishing this release does not update a running dedicated server. The game remains free to acquire, without real-money purchases.
