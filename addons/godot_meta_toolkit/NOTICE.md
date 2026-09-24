Godot Meta Toolkit 1.0.3-stable, upstream commit
7fc223fa4b9a1b43552a53bf287a720c4719ea76.

Source and binary release:
https://github.com/godot-sdk-integrations/godot-meta-toolkit/releases/tag/1.0.3-stable

The toolkit source is MIT licensed; see LICENSE.txt and THIRD_PARTY_NOTICES.txt.
Copyright © Meta Platform Technologies, LLC and its affiliates. All rights reserved.

The release AAR also includes Meta's Platform SDK loader. Meta SDK terms apply
to that component: https://developers.meta.com/horizon/licenses/oculussdk/ .
Upstream reports Platform SDK v77. The game uses initialization and entitlement
only; it does not enable purchases, friends, telemetry APIs or platform identity
collection. No app secret or account credential is embedded.

The upstream binary files and extension descriptor are unmodified. Public
release archive and installed-file SHA256 values are in PROVENANCE.json.
Desktop exports exclude this add-on; desktop libraries are retained for editor
support. The export option meta_toolkit/enable_meta_toolkit stays disabled:
its upstream convenience overrides target API 32. The toolkit's AAR export
hook works independently, while this project preserves target API 34.
