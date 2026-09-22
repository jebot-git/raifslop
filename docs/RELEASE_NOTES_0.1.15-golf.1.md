# Fishing + Golf integration prototype

First integrated desktop prototype from `integration/golf-fishing`, protocol 13.

- Fishing, golf and clubhouse BBQ share the menu, avatar, session, team radio and persistent player records.
- Play connected Spyglass Hill and Pebble Beach course reconstructions, with course maps, physical club heads, fitting, radial club selection and club stowing.
- Toggle Godview with left-stick click. Automatic tee club selection and putter switching remain enabled.
- Golf leaderboards appear on golfing courses. Turns have audible/visual notifications; an absent player forfeits the hole after five minutes. Players can retire or visit clubhouse BBQ.
- Dedicated server includes numerical course data and validates golf commands, turns, scorecards and persisted rankings. Ball flight remains owner-client simulated.
- Golf textures use the same desktop compression/deduplication path as Fishing; course and equipment credits are included.

## Downloads

Extract the complete Linux or Windows ZIP. Run `Desktop.sh` / `Desktop.cmd` for desktop mode, or `VR.sh` / `VR.cmd` for PC VR. Launchers enable verbose logs at `user://logs/prototype.log` in Godot's application data directory. The separate Server Linux ZIP includes `Server.sh`; its default UDP port is 24567. Clients and server must both use protocol 13.

`SHA256SUMS` and `build-manifest.json` identify the exact source commit and artifact hashes. Quest standalone is not included in this desktop prototype.

## Validation and limitations

The exported Linux dedicated server is tested with two golf clients through 18-hole rounds, clubhouse BBQ, malformed-command rejection, retirement and rankings after restart; fishing persistence is also checked. Merged-scene checks cover menu, equipment, avatar/radio continuity and activity transitions. Linux desktop startup is tested locally. Windows is exported but has not been runtime-tested on Windows; no physical headset validation is claimed. Course geometry is a prototype reconstruction, not a surveyed replica. Forced engine shutdown can report a retained streaming-audio resource; normal menu shutdown drains the audio mixer first.
