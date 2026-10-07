# Ultimate Boomer Simulator — Privacy Policy

Effective date: **7 October 2026**.

## Who is responsible

**Juzuv Jebot**, an individual based in **Serbia**, operating as **PLdot
development team** (“we”, “us”), provides Ultimate Boomer Simulator. Contact
us about privacy, access or deletion at
**[jewzuv@gmail.com](mailto:jewzuv@gmail.com)**. This policy covers the game, including
fishing, golf, BBQ, multiplayer and related support.

We provide email support and an IP-accessible testing server hosted on a VPS
in Frankfurt, Germany. We are responsible for the information we handle through
those services. The game does not require you to join our testing server.

You can play alone or connect to a player-operated host or dedicated server.
Independent server operators control their own server records and practices.
Ask the operator about those practices before joining. This policy describes
our game software and any services we operate; it does not replace an
independent operator’s privacy notice.

## Information the game uses

**Progress and preferences.** The game stores your catch journal, tackle and
in-game rewards, selected locations and avatar, and gameplay, audio, movement
and tracking settings on your device. Multiplayer preferences include your
chosen display name, the last server address and port, and a randomly generated
player identifier. These let the game remember your choices and progress.
You do not need to give the game your real name or create a separate game account.

**Headset, controller and optional tracking.** The game processes headset and
controller positions and rotations to display the world and respond to your
movements. When supported and enabled, body, hand, finger, eye and face tracking
and expression data animate your avatar. Calibration settings, including measured
height, can be saved locally. During multiplayer, avatar poses, movement and
supported expressions are sent through the host to other players. The game does
not use these signals to identify you biometrically or infer health conditions.
It uses tracking results provided by the VR runtime, rather than recording raw
headset camera images. In-game photography captures the rendered game scene.

**Multiplayer identity and activity.** A host receives your network address,
display name, random player identifier, connection information and gameplay
updates. Updates include your in-game location, equipment, avatar pose, fishing
activity, golf shots and scores, and interactions with shared BBQ items.
These support connections, shared play, synchronization and basic validation.
Your name, avatar, location and relevant activity are visible to other players.
The network address is not a precise physical location supplied by the game.

**Server achievements.** Hosts save a hashed form of your player identifier,
your display name, and fishing achievements and golf results used for rankings.
Records can remain after you leave, including a profile created before you have
caught a fish. Other players can view rankings. Your full local catch journal
is not uploaded to the scoreboard. The identifier is pseudonymous, not anonymous:
it links returning sessions and name changes on a server.

**Voice.** If you allow microphone access and enable voice, the game processes
microphone audio for live chat. New profiles default to voice activation; once
multiplayer and microphone access are active, speech can be transmitted without
holding a talk button. Nearby chat is relayed to players at the same in-game
location, and the handheld radio reaches players across the server. Audio is
compressed and buffered for transmission and playback. The game has no built-in
voice recording or transcription service. Other participants or independently
modified servers may record what they receive.

**Avatars and photographs.** Selecting an imported avatar for multiplayer shares
the model file, including any embedded images and metadata, with the host and
participating clients. They can keep cached copies after the session. Import
only files you are comfortable sharing. The field-guide camera saves pictures
on your device, including avatars and scenery in view. The game does not
automatically upload these pictures. Device gallery, backup or sharing services
you use may process them separately.

### Meta Horizon Platform features and online services

Quest builds use Meta’s Platform SDK for entitlement checks and the following
account and social features. The game collects or processes platform data to
provide these features even when it does not keep a separate copy. A failed
entitlement check can prevent the store build from starting.

**USER_ID — player identity.** The game receives your app-scoped Meta user ID
and a user-proof nonce (an authentication proof) from Meta. It passes the ID and
proof to Epic Online Services (EOS) Connect to authenticate you for online play.
EOS associates that login with an EOS Product User ID used for lobby membership,
network connections and online progress. The game also uses your Meta user ID
to check the current account before submitting Meta scores and achievements.
These identifiers are pseudonymous, not anonymous.

**USER_PROFILE — supporting platform identity.** The game requests the logged-in
Meta user object for account identification and verification. User Profile access
supports Meta achievements, leaderboards, destinations and social entry points.
This permission can make a Horizon username and profile-photo information
available through Meta’s platform services; the current game integration reads
the user ID from the returned object and does not extract or store the Meta
username or profile photo in a separate game profile database. Profile labels
shown in Meta’s native invitation interface are handled by Meta. Display names
shown in EOS rankings are supplied separately by EOS.

**FRIENDS — finding people to invite.** Selecting “Invite Meta friends” in an
online lobby opens Meta’s native invitation panel. Friend relationships and
profile labels are used in that Meta-managed interface to show eligible people
and let you choose whom to invite. The game does not retrieve the full friends
list into its own interface or copy a friends database to our server or EOS.

**INVITES — joining a shared session.** The game supplies Meta with the current
activity destination, lobby/session identifier, joinable status and a join
reference. Meta handles recipient selection and delivery of invitations you
initiate. The game processes incoming invitation join intents to resolve the
shared EOS lobby so friends can fish, play minigolf or use the BBQ together.
It does not automatically send invitations or use them for marketing.

**DEEP_LINKING — opening the intended lobby.** The game reads destination names,
deep-link messages and lobby/session identifiers from Meta launch details and
join/leave intents. It validates supported destinations and uses the join
reference to connect to the intended EOS lobby. These are game destinations,
not your physical location or browsing history. The game publishes this session
routing information through Meta Group Presence and clears that presence when
leaving the online session.

**EOS networking and online progress.** Epic Games provides EOS authentication,
lobbies, peer-to-peer connectivity, statistics, leaderboards and achievements.
EOS processes player identifiers, authentication information, lobby membership
and connection information to provide these services. Multiplayer gameplay,
avatar and voice traffic is exchanged through the configured multiplayer
transport, which can use EOS connections or relays. Fishing statistics, minigolf
results and achievement unlocks are sent to EOS; the game also submits supported
scores and achievements to Meta. Other players can view leaderboard display
names, ranks and scores. Local account-scoped records hold pending and confirmed
score and achievement updates so synchronization can be retried. The Meta-to-EOS
login does not require you to create or sign into a separate Epic Games account.

**Diagnostics and support.** The game and its engine can write local diagnostic
logs with technical errors and runtime information. If you send us a support
request, screenshot, log or recording, we process your contact information and
what you submit to investigate and respond. Review attachments before sending
them, and do not send passwords or the private multiplayer identifier. Device
platforms and server hosting providers may maintain their own operational logs.
Our testing server keeps basic functional logs for troubleshooting.

## Purposes, advertising and recipients

We use the information described above to run the features you choose, remember
progress, verify platform access, maintain multiplayer records and address
technical or safety problems. The current game includes no advertising SDK,
advertising tracking, payment collection or external AI chat service. Its fish
behavior runs locally; it does not send your conversations to a generative AI
service. We do not sell personal information, share it for advertising, or use
it for targeted advertising. We do not operate an analytics or automatic
crash-reporting service for the game. Meta's separate platform processing is
described in its own policy.

Recipients depend on the feature: the host and other players receive multiplayer
information; Meta processes platform identity, social, session-routing and
progress information; Epic processes the EOS information described above; and
support or hosting providers may process information for services we operate. We may disclose
information we hold when required by applicable law. We do not automatically
receive every independent server’s records or every player’s local files.

**Epic Online Services.** EOS is operated by Epic Games. Its handling of game
service data is governed by the applicable EOS service terms and data-protection
arrangements. Epic describes its separate processing and privacy-request
channels in the [Epic Games Privacy Policy](https://legal.epicgames.com/epicgames/privacy-policy).
See also the [EOS privacy and trust statement](https://onlineservices.epicgames.com/services/terms/trust-statement)
and [EOS service agreements](https://onlineservices.epicgames.com/services/terms/agreements).
These notices do not replace our responsibility for game data we control.

**Support email.** We use Google's Gmail to receive and respond to support and
privacy requests, and access those messages from Serbia. Google processes
messages, attachments and service information on its infrastructure, which can
be outside your country, including in the United States. See
[Google's Privacy Policy](https://policies.google.com/privacy) and its
[data transfer frameworks](https://policies.google.com/privacy/frameworks).

**Testing-server hosting.** Our provider is **Cloudzy**; the game server
is located in Frankfurt, Germany. We administer it from Serbia. The provider
may process infrastructure and operational information to supply and protect
the VPS service. See [Cloudzy's Privacy Policy](https://cloudzy.com/privacy-policy/).

**This policy website.** GitHub Pages hosts this page. GitHub logs visitors'
IP addresses for security and processes website information under the
[GitHub General Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
This page has no analytics scripts, advertising, forms or embedded third-party
media. Contacting us by email is separate from visiting the page.

Processing in Serbia and by providers elsewhere may involve countries with
different data-protection laws from your own. The linked provider notices
describe their separate processing and any transfer arrangements they publish.
You can contact us for information about
the arrangements applicable to your data. Independent servers you choose and
other players may also be located in other countries.

## How long information remains

Local saves and settings remain until removed or replaced. Imported and downloaded
avatar files can remain in persistent storage. The built-in avatar cache has a
size limit, but no automatic time-based expiry. Server scoreboard records also
have no built-in time-based expiry; an operator must remove them. Disconnecting,
changing your display name or reinstalling does not remove server records.

Live voice and pose information is buffered to run the session rather than
recorded as a voice or motion history by the game. Saved height/calibration
settings, avatar files, results, photos and any separately captured recordings
are different and can persist. Exported photographs and backups can remain after
uninstallation.

**Online service records.** EOS service data is retained by Epic under the
applicable EOS service terms, policies and data-protection arrangements. We do
not set a single fixed expiry for Epic-retained service records. Online scores,
achievements and account associations can remain after you leave a session or
uninstall the game; our testing-server retention periods below do not apply to
EOS or Meta records. The game does not implement a time-based expiry for its
online progress records. You can request removal of game achievements and
leaderboard records we can administer through the EOS dashboard, as explained
below. Meta-retained platform records are subject to Meta’s practices and
available deletion mechanisms. Local synchronization records remain until
removed or replaced with the game’s saved data.

**Our support email.** We delete support messages and attachments within
90 days after resolving the request, or sooner following a valid deletion
request. This includes copies we download to investigate the request.

**Our testing server.** We delete player records, including fishing and golf
results, and cached player avatars at the end of each test and no later than
30 days after collection. We delete basic functional server logs within seven
days. These are our operating commitments; the game does not automatically
enforce these periods for independent hosts.

**Backups and exceptions.** Any backups we maintain expire within 30 days.
Deleted information remaining in such backups is not used for ordinary
operations, and deletions are reapplied before restored data is put back into
use. Provider-controlled system backups and operational records are subject to
the provider's own retention practices. We may retain particular information
where necessary to meet a legal obligation or establish, exercise or defend a
legal claim, only for as long as that need continues. We explain any such
exception when responding to a deletion request unless the law prevents it.

## Your choices and deletion requests

You can play without joining multiplayer. To stop sending microphone audio,
choose Listen only or revoke microphone permission in your device’s app settings.
Push to talk provides more control over transmission. Muting another player or
using Mute all controls what you hear; it does not necessarily stop your own
microphone transmission. Optional tracking can be disabled in the game or through
available device permissions; basic headset and controller tracking is needed
to play.

To remove local progress and preferences, close the game and use your device’s
app-data controls where available, or remove the game’s saved-data folder on PC.
Remove exported pictures separately from Pictures/Ultimate Boomer Simulator or
your chosen photo folder, and remove imported/downloaded avatar files and any
backups separately. Clearing the multiplayer identity creates a new identity;
it does not erase the old one on servers and may make it harder to locate.

**Anyone, in any country or region, may request deletion of data we control by contacting
[jewzuv@gmail.com](mailto:jewzuv@gmail.com) with the subject “Ultimate Boomer Simulator —
Data deletion”. We do not charge a fee for deletion.** Include the display name,
server name/address or online service (EOS/Meta), approximate dates and, for
online records, your Meta username or other non-secret account identifier
needed to locate the record. Do not include a password or your private
player token. We may request proportionate information to verify the request.
Contact an independent host directly for its records. We can help identify
which information is ours, but cannot promise to erase copies controlled by
other players, independent hosts or platform providers.

**What we can delete directly.** Through the developer email above, we handle
requests for our testing-server records, our support correspondence and game
data available to us through the EOS dashboard, including achievements and
leaderboard records. After proportionate verification, we remove the relevant
records using the controls available to us and explain the result. We cannot
directly erase Epic’s internal service logs, backups or account-linking records
that are not exposed through those controls, or delete your Meta/Epic account.
A dashboard limitation does not remove any responsibility we have under
applicable law: where a request concerns game data we control but cannot erase
directly, we will seek the relevant provider’s assistance and explain what
remains outstanding.

**Requests concerning Epic or Meta.** For data only Epic can handle, contact
[privacy@support.epicgames.com](mailto:privacy@support.epicgames.com) using the
privacy-request instructions in the
[Epic Games Privacy Policy](https://legal.epicgames.com/epicgames/privacy-policy).
Identify Ultimate Boomer Simulator and EOS in your request; our Meta-to-EOS
login can be used without a separate Epic Games account. For Meta-controlled
platform records, use the privacy tools and contact routes in
[Meta’s Privacy Policy](https://www.meta.com/legal/privacy-policy/).
We can help distinguish those records from the game records we can administer.
Deletion of Epic- or Meta-controlled data is handled under their applicable
policies and legal obligations; we cannot promise their completion date or
erasure of every provider-controlled copy.

**Local data and later synchronization.** Removing online records does not
remove local progress, pending synchronization data, backups or copies kept
by independent hosts. Close the game while a deletion request is being handled.
Before returning to online play, remove local saved progress and synchronization
records using the app-data controls described above, and do not restore an old
backup if you do not want those records uploaded again. Further online play
can create new service records.

We respond to deletion requests within 30 days, or sooner where required by
law. Our response confirms what we deleted, any backup expiry still pending,
or the specific reason we cannot fulfil all or part of a request. If we cannot
identify your record safely, we explain what additional information is needed.
An independent host's copies and other players' cached files are outside our
control; this does not prevent you from requesting deletion of our own copies.

Depending on applicable law, you may also request access, correction, a copy
or portability of information, restriction of processing, or deletion. **You
may object to processing based on legitimate interests.** Where processing
relies on consent, you may withdraw consent without affecting earlier lawful
processing. You may complain to your local data-protection authority, including
Serbia's [Commissioner for Information of Public Importance and Personal Data Protection](https://poverenik.rs/kontakt/?script=lat).
We respond within applicable legal deadlines and explain any lawful limitation
on a request.

## Legal grounds and security

Where applicable data-protection law requires a legal basis, we rely on our
legitimate interests in providing the game and the features you use: remembering
progress and settings, responding to tracked movement, enabling optional avatar
animation and live voice communication, authenticating online players, handling
user-initiated invitations and lobby joins, and running shared play, online
achievements and rankings. We also rely on legitimate interests in diagnosing functional problems,
protecting our services and responding to support messages. We limit processing
to those purposes and balance these interests against your rights, including
your ability to avoid multiplayer, control optional features and request deletion
or object to processing.

We rely on compliance with legal obligations when processing is necessary to
answer statutory data-rights requests or meet another applicable legal duty.
If we seek your consent for a new use, we will explain that use and how to
withdraw consent before it begins.

The current direct multiplayer connection does not provide end-to-end encryption
or an application-level encrypted transport. Hosts process voice and gameplay
updates to relay them. Use servers you trust and avoid sharing sensitive
information in chat or avatar files. No storage or transmission method can be
guaranteed completely secure.

## Age and policy changes

The game is intended for people aged 13 and over, subject to platform rules and
applicable local age requirements. It is not directed to children under 13 and
does not include an independent age-verification system. If you believe a child
under 13 has provided information to a service we control, contact our privacy
address so we can investigate and address it.

We will update this policy when the game or our data practices change, revise
the effective date and provide any notice required by law. Material changes
will be explained before new uses begin where required.

For Meta’s separate practices, see its [privacy policy](https://www.meta.com/legal/privacy-policy/).
