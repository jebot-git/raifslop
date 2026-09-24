# Quest internal upload — 2026-09-24

- AppID: `3428825797290213` (Ultimate Boomer Simulator).
- Meta build ID: `3428857920620334`.
- Target channel: `ALPHA` (`1609626467560907`); audience: `TEENS_AND_ADULTS`, confirmed by owner.
- Package: `org.jebot.raifslop.quest`; version `0.1.15`, version code `18`.
- Source: `6d6a66aefc94eb805dcf3834298d12034fa5c45f` (integrated candidate).
- Meta Platform CLI: `208.0.0`, official Linux download.
- Upload succeeded. A separate channel query confirmed ALPHA version `18` /
  `0.1.15`; postprocessing is still running at the time of this entry.
- [Meta build tests](https://developer.oculus.com/manage/applications/3428825797290213/builds/3428857920620334/test-results/).

Both artifacts passed their staged SHA256SUMS checks before upload:

| Artifact | SHA256 |
| --- | --- |
| UltimateBoomerSimulator.apk | `63907c4147a4202bbd9aef2f93697cd7dd3cdef57bb2de7914ad4745524ee8f3` |
| main.18.org.jebot.raifslop.quest.obb | `c401ce0c9579682ff1b8de8b7dff387533f06d3a738c34312530e5b8af3789d4` |

The CLI validated the build and reported a Quest 1 deprecation warning. It
uploaded the APK and matching expansion file, with postprocessing waiting
enabled. This is an internal test upload, not a public release or hardware
acceptance result. Install through the ALPHA channel using an assigned tester
account and run [entitlement acceptance](QUEST_ENTITLEMENT.md), expansion,
lifecycle and performance tests on Quest.

The CLI's documented JSON configuration loader rejected even an empty JSON
object. The owner explicitly approved command-line authentication after being
informed of local process-list exposure. No credentials are recorded here;
captured output was redacted and local logs restricted to owner access.
