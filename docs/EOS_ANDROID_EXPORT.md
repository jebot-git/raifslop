# Experimental EOS Quest export

Version 0.1.18-eos.1 (Android code 22) packages the EOS lobby transport for ALPHA testing.
Install the pinned SDK with `python3 tools/eos/setup_lab.py --game --platform android`.
With the existing store signing environment configured, run:

```
python3 tools/build_release.py --target Quest --store-release --eos-config builds/eos/eos.cfg
python3 tools/store_release.py quest
```

The private configuration must use Meta identity and the entitled application ID.
Only the required EOS client settings and public Meta ID/destination are embedded;
never put a Meta upload app secret in this configuration. EOS client credentials
in an application are extractable and require appropriately limited EOS policies.
The source configuration and generated Android project remain ignored by Git.

The generated activity loads EOSSDK and calls EOSSDK.init before Godot starts,
on the activity thread. The AAR registers its own lifecycle callbacks. Gradle
includes the pinned AAR, its AndroidX dependencies and the core-library
desugaring required by the AAR metadata; the AAR supplies its login
activity and the generated resource supplies its login scheme. This follows the
[EOSG Android initialization instructions](https://3ddelano.github.io/epic-online-services-godot/docs/topics/initialization).

The build checks embedded configuration, Java classes, native dependencies and
16 KiB ARM64 ELF alignment, then performs existing signature/expansion checks.
This is a testing release: entitled Quest login, friends/invites, Quest/PC
crossplay and hardware performance still need on-device validation. The native
sender-binding and eight-player WAN acceptance gates documented in
[transport notes](EOS_GAMEPLAY_TRANSPORT.md) remain open.
