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

The requested [media package](media/index.html) now contains six in-game vistas,
two equipment beauty shots, a 36-second environment trailer, the original icon
and CC0 title lettering. These are desktop engine captures; confirm visual
parity against the Quest build before submission. See [capture provenance](media/README.md).
All five cover-art sizes below are exported in `media/`, with the full title and
original icon. Official safe-area overlay verification remains pending: Meta’s
template downloads redirected to a Facebook login.

| Output | Target | Brief / state |
| --- | --- | --- |
| `cover-landscape.png` | 2560 × 1440 | Original icon and full-title identity |
| `cover-square.png` | 1440 × 1440 | Same title and composition adapted for square |
| `cover-portrait.png` | 1008 × 1440 | Same identity; preserve safe areas |
| `hero.png` | 3000 × 900 | Centered branding with room for crops |
| `mini-landscape.png` | 1080 × 360 | Same identity, legible at small size |
| `icon.png` | 512 × 512 | Exported in media/; existing icon with opaque teal corners |
| `screenshot-01` through `06` | 2560 × 1440 each | Captured desktop in-game vistas; select five after Quest parity review |
| `trailer.mp4` | 1920 × 1080 | 36 seconds, 30 fps, H.264/AAC; panoramic environment footage |
| `trailer-cover.png` | 2560 × 1440 | Harbour vista matching the trailer environment |

Use 24-bit PNG for the static assets above. These dimensions come from
[Meta’s asset guidelines](https://developers.meta.com/horizon/resources/asset-guidelines/),
checked 2026-09-24; confirm which slots the current Dashboard requires.
Keep the exact game title on branded covers, use Meta’s safe-area templates,
and omit pricing banners and taglines from cover art. The preview’s layout
labels are instructions, not proposed text for exported covers.

The unchanged SVG icon has rounded artwork with transparent outside corners.
Meta’s icon guidance specifies a filled, opaque square. The media export fills
only the transparent outside corners with the existing teal; the artwork is
unchanged. Transparent PNG/SVG logo versions are also included.

The produced trailer follows the requested panoramic brief: title → harbour →
reed lake → woodland stream → alpine river → dawn coast → title. It uses the
actual game world and matching ambient sound, without multiplayer participants.
The earlier action-trailer brief (casts, swings and shared BBQ) remains optional
future capture work. Older `docs/preview.png` has obsolete branding and a removed
desktop interface; it is not used in these assets.

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

## Privacy policy

The [public privacy policy](https://jebot-git.github.io/raifslop/privacy.html)
covers local storage, multiplayer, voice, tracking, avatars, platform checks,
Gmail support, Cloudzy testing-server operations and deletion. It is effective
24 September 2026. The [source](PRIVACY_POLICY.md),
[publication review](PRIVACY_REVIEW.md) and
[operating procedure](PRIVACY_OPERATIONS.md) are maintained here.
Run `python3 docs/quest-store/render_privacy.py` after updating the policy.
Privacy/deletion requests go to jewzuv@gmail.com without charge.
The local listing includes these links; the Meta Dashboard still needs them.

## Pending owner information and acceptance

The owner supplied the publisher and support details on 2026-09-24. The
privacy-policy and deletion URLs are now populated. Content rating, comfort
rating, hardware acceptance and launch date remain unconfirmed.

| Field | Next action |
| --- | --- |
| Public publisher identity | PLdot development team; legal controller is Juzuv Jebot, Serbia |
| Support and privacy URLs | jewzuv@gmail.com and the public policy linked above; enter in Dashboard |
| Data deletion route | Free email requests; follow PRIVACY_OPERATIONS.md and the agreed retention schedule |
| Privacy / data-use answers | Review voice, avatars, network identity and server records against implementation |
| Content rating | Complete applicable questionnaires in the Dashboard |
| Supported headsets / play modes / comfort | Validate the uploaded build on advertised hardware and modes |
| Language support | Confirm English coverage; do not list untested translations |
| Multiplayer disclosures / reporting | Review current youth, communication and user-reporting requirements |
| Media permissions and credits | Check asset rights, participant consent, attribution and requested AI disclosures |

Keep engineering notes and pending-field labels out of the final consumer listing.
