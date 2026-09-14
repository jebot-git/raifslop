# Release size and export policy

Version 0.1.2 downloads were approximately 690 MiB (Linux), 700 MiB (Windows), and 723 MiB each (Quest/Pico). The pre-optimization pack contained 916 MiB of assets. Four native 8192×4096 RGBE panoramas with mipmaps accounted for 683 MiB; eight HDR lighting atlases added 64 MiB. Byte-identical imported shore/cork textures accounted for another 34.94 MiB of duplication. All fish, rod parts (including the reel handle), and four shore models were confirmed in use.

The export plugin now hashes final imported texture bytes, emits identical textures once, and remaps their original resource paths. Comparing imported bytes preserves differences in color space, normal maps, mipmaps, and platform formats. Authoring sources remain intact so GLB reimports and asset-generation tools remain reproducible.

Desktop HDR textures use BC6H with their original resolution and mipmaps. The content-addressed cache includes the Godot version and compression revision. Android retains original lossless RGBE textures: ASTC HDR is optional hardware support and software fallback can double texture memory. No lower-resolution panorama edition is produced. Existing sharpening, seam treatment and lighting remain active.

ZIP and Android DEFLATE compression use level 9. Rewritten APKs are aligned for 16 KiB pages and signed again with the existing key, then verified. Already stored APK entries (including native libraries) remain stored. A trial of Godot's lossless compressed ImageTexture resources was rejected: Lake Pier became 131.1 MiB in an archive versus 119.1 MiB with level-9 compression of the original texture.

Development folders, export settings, editor plugins, unused example scenes/shaders, and all READMEs are excluded. Runtime voice helpers and the VRM importer are retained. Licenses and asset credits remain included. Clean target directories, commit-bound build manifests, checksums, package-content tests, and upload digest verification guard the release.

Engine behavior references: [Godot texture importing](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html), [Vulkan ASTC HDR feature](https://docs.vulkan.org/refpages/latest/refpages/source/VkPhysicalDeviceTextureCompressionASTCHDRFeatures.html).

Trial validation: the desktop asset pack fell from 916.3 to 309.3 MiB (66.2%). Ninety-seven imported texture references resolve to 72 unique payloads. All four panoramas and all fish/shore models loaded from the exported pack. Clamped linear-RGB texture comparisons exceeded 49 dB PSNR across the twelve HDR textures; rendered comparisons check the full HDR pipeline separately.
