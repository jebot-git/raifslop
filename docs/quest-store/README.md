# Quest listing skeleton

Open [index.html](index.html) in a browser for the local page preview. This is a
reviewable draft for **Ultimate Boomer Simulator**, AppID `3428825797290213`;
it has not been entered in Meta’s Dashboard or published. The connected tools
used for the internal build upload do not provide a listing editor.

Edit [listing.json](listing.json), then run `python3 docs/quest-store/render.py`
from the repository root. The renderer checks text lengths and keywords before
updating the preview; it works offline and does not contact Meta. The JSON is
our handoff format, not a documented Meta import schema. Rendered text is escaped.
The preview is a content layout, not a pixel-exact reconstruction of Meta’s UI.

## Ready to transfer

- Name, English short/long descriptions, and five proposed keywords are in JSON
  and the preview’s copy-ready section.
- Pricing: Free. No real-money IAP, paid DLC or subscriptions.
- Audience: Teens and adults, confirmed by the owner. This is not an IARC or
  regional content rating.
- Category proposal: Games. Genre proposals: Simulation and Sports; select the
  closest currently available Dashboard labels.
- Existing icon referenced directly from `assets/icon.svg`; no icon changes.
- Five capture briefs cover fishing, fly waters, golf, BBQ and multiplayer.
- ALPHA version 18 / 0.1.15: see [upload receipt](../QUEST_INTERNAL_UPLOAD.md).

The copy describes implemented features from [fly expansion](../FLY_EXPANSION.md),
[golf integration](../GOLF_INTEGRATION.md), [cosmetics](../GOLF_TACKLE_STYLING.md),
[BBQ](../BBQ.md), and [multiplayer](../MULTIPLAYER.md). It avoids course trademarks,
precise content counts, unverified performance claims and matchmaking promises.
Final Quest capture and hardware acceptance remain pending.

## Media production slots

Create final files only after reviewing current Quest footage. Place approved
outputs in a future `media/` subdirectory; do not upload the preview or its
placeholder panels as store art.

| Output | Target | Brief / state |
| --- | --- | --- |
| `cover-landscape.png` | 2560 × 1440 | One consistent fishing/golf/BBQ visual identity |
| `cover-square.png` | 1440 × 1440 | Same title and composition adapted for square |
| `cover-portrait.png` | 1008 × 1440 | Same identity; preserve safe areas |
| `hero.png` | 3000 × 900 | Centered branding with room for crops |
| `mini-landscape.png` | 1080 × 360 | Same identity, legible at small size |
| `icon.png` | 512 × 512 | Existing artwork only; export and review pending |
| `screenshot-01` through `05.png` | 2560 × 1440 each | Fresh in-headset gameplay, following the five briefs |
| `trailer.mp4` | 16:9, 1080p–2K | MP4/H.264/AAC; genuine gameplay |
| `trailer-cover.png` | 2560 × 1440 | Representative gameplay frame |

Use 24-bit PNG for the static assets above. These dimensions come from
[Meta’s asset guidelines](https://developers.meta.com/horizon/resources/asset-guidelines/),
checked 2026-09-24; confirm which slots the current Dashboard requires.
Keep the exact game title on branded covers, use Meta’s safe-area templates,
and omit pricing banners and taglines from cover art. The preview’s layout
labels are instructions, not proposed text for exported covers.

The unchanged SVG icon has rounded artwork with transparent outside corners.
Meta’s icon guidance specifies a filled, opaque square. Review the existing
release icon’s raster treatment before export; keep the user’s original design
and do not silently redesign it. This is an unresolved asset check.

Trailer outline: fishing cast/fight → river fly cast → golf swing/putt → shared
BBQ → title. Show controller interaction clearly. No synthetic footage posed
as gameplay. Obtain consent from any visible multiplayer participants and hide
user identifiers. Older `docs/preview.png` has obsolete branding and a removed
desktop interface; older BBQ/course overview captures are not final store media.

## Dashboard handoff

1. Open the existing app in the [Meta Developer Dashboard](https://developers.meta.com/horizon/manage/).
   Use AppID `3428825797290213`; do not create another app or upload another binary.
2. Open its draft app submission and App Metadata. Copy the English title,
   descriptions and keywords from JSON or the preview. Save as a draft.
3. Select Free and the confirmed intended audience. Confirm category/genre and
   language selections. Attach approved media when available.
4. Complete the pending fields below and perform channel-install acceptance.
   Review both desktop and headset listing previews for cropping and accuracy.
5. Submit only after the listing and hardware launch gates in
   [STORE_LAUNCH_PLAN.md](../STORE_LAUNCH_PLAN.md) are complete. This skeleton does
   not submit the app or change its production channel.

[Meta’s metadata reference](https://developers.meta.com/horizon/resources/publish-app-metadata/)
lists limits of 40/500/1500 characters for name/short/long descriptions. Its
[localization reference](https://developers.meta.com/horizon/design/localization/)
still lists 1000 for the full description; this draft conservatively stays below
1000. The renderer also checks at most five single-token keywords of at most
50 characters each. Dashboard limits remain authoritative.

## Pending owner information and acceptance

The owner confirmed on 2026-09-24 that publisher name, support contact and
privacy-policy URL are not ready. They remain `null`, displayed as Pending.
No contact, URL, content rating, comfort rating or launch date is invented.

| Field | Next action |
| --- | --- |
| Public publisher identity | Supply the approved public name |
| Support and privacy URLs | Publish real pages and verify they load without login |
| Data deletion route | Match the actual data retention/deletion process |
| Privacy / data-use answers | Review voice, avatars, network identity and server records against implementation |
| Content rating | Complete applicable questionnaires in the Dashboard |
| Supported headsets / play modes / comfort | Validate the uploaded build on advertised hardware and modes |
| Language support | Confirm English coverage; do not list untested translations |
| Multiplayer disclosures / reporting | Review current youth, communication and user-reporting requirements |
| Media permissions and credits | Check asset rights, participant consent, attribution and requested AI disclosures |

No legal policy has been fabricated to fill these gaps. Keep engineering notes
and pending-field labels out of the final consumer listing.
