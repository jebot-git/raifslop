# Golf clubs matching tackle styles

Golf clubs automatically inherit the equipped Willow, Reed, Heron or Kingfisher tackle palette. This applies when entering golf, switching clubs or hands, stowing equipment, and changing tackle while golf is active. The tackle menu explains that golf performance stays the same.

| Equipped tackle | Existing identity | Club treatment |
|---|---|---|
| Willow | Olive blank, muted green trim, natural cork | Olive shaft/crown accents, muted green ferrules, cork-toned grip detail |
| Reed | Navy blank, silver trim, dark synthetic grip | Navy shaft accents, brushed silver collars, dark rubber grip |
| Heron | Burgundy blank, brass trim, natural cork | Burgundy crown/badges, brass collars and signature, warm grip accents |
| Kingfisher | Teal blank, turquoise trim, dark synthetic grip | Teal crown/badges, turquoise collars, dark rubber grip with teal detail |

All eight clubs are supported. Steel striking surfaces and face grooves retain their finish, and alignment marks retain contrast. Cork tiers use warm butt-cap detail while retaining the existing textured rubber grips and their traction geometry. The standalone golf scene keeps its original neutral finish when no fishing profile is attached.

## Implementation

`assets/equipment/tackle_styles.json` is the shared source of linear RGB palettes. The rod-authoring helper `tools/rod_styles.py` reads it, and existing held/folded rods still match it. Export presets explicitly include the JSON.

`club_style.gd` applies palette uniforms to local physical heads and per-instance material overrides to shafts, grips, collars, and imported remote club surfaces. Linear authoring colours are converted for Godot's sRGB StandardMaterial colour properties. Imported materials are never modified globally. A cached tier check skips unchanged styles; existing overrides are reused on subsequent changes.

The local golf host refreshes the equipped style while active, and `set_club` applies it to replacements. Recolouring does not recreate the club or reset the swing. Multiplayer uses the existing validated `rod_tier` snapshot field and also handles tier changes without a club switch. Remote players retain their existing imported head geometry and receive the same palette through its material surfaces.

Club mesh, length, loft, fitted transforms, contact sampling, mass, restitution, spin and the 2 mm tracking tolerance are unchanged. Fishing upgrade multipliers do not enter golf physics.

## Verification

- `tools/test_rod_styles.py`: 128 checks across the 32 existing held/folded rod assets.
- `tests/golf_cosmetic_style.gd`: 232 checks across four styles and eight clubs. Covers palette colour space, local/remote shaft matching, independent player materials, allocation-free repeated application, neutral fallback, unchanged mesh/transforms and contact queries.
- `tests/golf_attachment.gd`: expanded integration coverage for all tier/club selections, actual multiplayer snapshots, tier-only changes during fitting, stowed equipment and handedness.
- Existing physical-club (33/33), fit-invariant and tracking-tolerance regression suites pass; the expanded attachment/multiplayer integration suite also passes.
- Mobile/Vulkan GPU gallery: [club palettes](golf_tackle_styling/club_palettes.png).

Styling introduces no new meshes, texture assets or draw passes. Actual sustained Quest GPU performance has not been measured for this change.
