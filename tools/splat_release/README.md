# Offline hybrid splat testing release

This builds the two-area environment viewer independently of the main game. Sources are based on `tools/splat_experiment/locations.gd`; `base.gd` supplies only the camera, walking, panorama and capture helpers required by those areas. Preparation replaces the experiment inheritance and redirects every report write to this app's `user://captures` directory. `release.gd` provides independent preferences, standalone-XR startup and export smoke checks.

`data/` retains only the final cleaned splats, generated panoramas, Simons HDR lighting and placement metadata. The original 500k exports, cloud credentials, downloaded world documents and developer screenshots are not packaged. `vendor/gdgs` is the tested MIT renderer snapshot; see its LICENSE and `vendor/PROVENANCE.json`. Authored foregrounds, textures, action map and movement code are copied from the repository through an explicit allowlist. Neither game code, multiplayer, voice nor MCP enters the staged project.

```bash
python3 tools/splat_release/build.py --prepare-only
# Commit source before final builds (use --development for pre-commit iteration).
python3 tools/splat_release/build.py
python3 tools/splat_release/validate.py
python3 tools/splat_release/package.py
# After pushing branch and v0.1.0-splat.1 tag:
python3 tools/splat_release/publish.py
```

Builds and logs stay under `builds/splat-testing`; standard game artifacts stay under their existing directories. Android signing reuses the locally configured release key, with distinct package IDs `org.jebot.raifslop.splattesting.quest` and `.pico`. Credentials are read only inside the build process and never written to source, manifests or command arguments.

The publisher creates a draft, uploads and verifies all asset hashes, then publishes as a prerelease with `make_latest=false`. Final packaging requires four exports from the same clean commit and exported Linux validation. `audit.py` verifies actual PCK/APK entries and Android permissions; `validate.py` uses an isolated test data root and checks saved selection across restart.

The root game project, its save directory and its stable release remain independent. Headset visual/performance tests are deferred; see the release notes for tested scope.
