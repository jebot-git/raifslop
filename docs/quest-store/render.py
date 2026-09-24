"""Render the local review preview; no network requests or Dashboard mutations."""
from pathlib import Path
import html
import json

root = Path(__file__).resolve().parent
d = json.loads((root / 'listing.json').read_text())
for key, limit in [('name', 40), ('short_description', 500), ('long_description', 1000)]:
    if not 0 < len(d[key]) <= limit:
        raise ValueError(f'{key}: exceeds {limit} characters or is empty')
if len(d['keywords']) > 5 or any(not k or len(k) > 50 or any(c.isspace() for c in k) for k in d['keywords']):
    raise ValueError('Use at most five keywords, each 1–50 characters without whitespace')
esc = html.escape
def media_cards(items):
    return ''.join(f'<article class="capture"><a href="{esc(c["path"], quote=True)}"><img loading="lazy" src="{esc(c["path"], quote=True)}" alt="{esc(c["name"], quote=True)}"></a><h3>{esc(c["name"])}</h3></article>' for c in items)

cards = media_cards(d['media']['screenshots'])
equipment = media_cards(d['media']['equipment'])
paragraphs = ''.join(f'<p>{esc(s)}</p>' for s in d['long_description'].split('\n\n'))
pending = ''.join(f'<tr><th scope="row">{esc(label)}</th><td>{esc(str(d[key])) if d[key] is not None else "Pending"}</td></tr>' for key, label in [('publisher_name','Publisher'),('support_url_or_email','Support'),('privacy_policy_url','Privacy policy'),('deletion_request_url','Data deletion'),('content_rating','Content rating'),('comfort_rating','Comfort'),('supported_devices','Supported headsets'),('play_modes','Play modes')])
page = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Quest listing draft — Ultimate Boomer Simulator</title>
<style>
:root{color-scheme:dark;--bg:#101b19;--panel:#1a2a26;--line:#3b5148;--muted:#b2c1b7;--paper:#f1e9d4;--mint:#b7d9b6}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--paper);font:16px/1.6 system-ui,sans-serif}a{color:var(--mint)}a:focus-visible,summary:focus-visible{outline:3px solid #efd393;outline-offset:5px}main,header,footer{max-width:1180px;margin:auto;padding:24px}header{display:flex;justify-content:space-between;gap:16px;align-items:center;border-bottom:1px solid var(--line)}.label,small{font-size:11px;letter-spacing:2px;text-transform:uppercase}.label{color:var(--mint)}.draft{border:1px solid #9b885a;color:#efdaa5;padding:5px 12px;border-radius:30px;font-size:12px}.hero{min-height:310px;display:flex;flex-direction:column;justify-content:center;padding:40px;background:linear-gradient(125deg,#354d40,#1b3432);border:1px dashed #799078;border-radius:14px}.hero h2{font:clamp(32px,5vw,60px)/1.1 Georgia,serif;max-width:650px;margin:20px 0}.hero p{max-width:640px;color:var(--muted)}.layout{display:grid;grid-template-columns:minmax(0,2fr) minmax(250px,1fr);gap:44px;margin-top:38px}.identity{display:flex;gap:20px;align-items:center}.identity img{width:76px;height:76px}h1{font:34px/1.15 Georgia,serif;margin:0 0 8px}h2{font:28px Georgia,serif}h3{font-size:21px;margin:8px 0}p{margin:12px 0 20px}.subtle{color:var(--muted)}.tags{display:flex;flex-wrap:wrap;gap:8px;margin:22px 0}.tags span{border:1px solid var(--line);border-radius:24px;padding:4px 12px;font-size:13px}.price{background:var(--mint);color:#14241d;border-radius:10px;padding:15px;text-align:center;font-weight:650}.aside{background:var(--panel);border:1px solid var(--line);padding:24px;border-radius:14px;align-self:start}.aside p{font-size:14px}.gallery{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:24px}.capture{min-height:245px;background:var(--panel);border:1px dashed var(--line);border-radius:12px;padding:22px}.capture p{font-size:14px;color:var(--muted)}.capture small{font-size:9px;letter-spacing:1px}.number{font:28px Georgia,serif;color:var(--mint)}section{margin:44px 0}details{border:1px solid var(--line);border-radius:12px;padding:20px}summary{cursor:pointer;font-weight:600}table{width:100%;border-collapse:collapse;margin:20px 0}th,td{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:12px 8px}th{width:45%;font-weight:500}.copy{white-space:pre-wrap;font:inherit;background:#0e1715;padding:18px;border-radius:8px}footer{color:var(--muted);font-size:13px;border-top:1px solid var(--line)}@media(max-width:750px){.layout,.gallery{grid-template-columns:1fr}.hero{padding:24px;min-height:240px}.identity{align-items:flex-start}h1{font-size:28px}header{flex-wrap:wrap}main{padding:18px}}
.hero{background:linear-gradient(90deg,#0b242be0,#14272866),url("media/screenshot-05-blouberg_sunrise_2.png") center/cover;border:1px solid var(--line)}.hero img{width:min(680px,100%);height:auto}.capture{padding:0;min-height:0;overflow:hidden;border:1px solid var(--line)}.capture img{width:100%;aspect-ratio:16/9;object-fit:cover;display:block}.capture h3{font-size:17px;padding:8px 16px 16px}video{width:100%;border-radius:12px;background:#112d2f}.equipment{grid-template-columns:repeat(2,1fr)}@media(max-width:750px){.equipment{grid-template-columns:1fr}}
</style>
<header><span class="label">Ultimate Boomer Simulator / Quest</span><span class="draft">LOCAL LISTING DRAFT</span></header>
<main><div class="hero"><img src="media/logo.png" alt="Ultimate Boomer Simulator — fish and hook logo"></div>
<div class="layout"><div><div class="identity"><img src="../../assets/icon.svg" alt="Existing fish and hook game icon"><div><h1>__NAME__</h1><span class="subtle">Fishing · Golf · Waterside BBQ</span></div></div><p>__SHORT__</p><div class="tags"><span>Single player</span><span>Hosted multiplayer</span><span>Tracked controllers</span></div><section><h2>About this game</h2>__LONG__</section></div>
<aside class="aside"><div class="price">Free · No real-money purchases</div><p class="subtle">Preview only. This page does not install the game.</p><hr><h3>Internal testing</h3><p>ALPHA · Build 18<br>Audience setting: ages 13+<br>Content rating: pending</p><p><a href="../QUEST_INTERNAL_UPLOAD.md">Build and upload record</a></p><p class="subtle">Public availability, supported devices and comfort classification are not yet confirmed.</p></aside></div>
<section><h2>Find your spot</h2><video controls preload="metadata" poster="media/trailer-cover.png"><source src="media/trailer.mp4" type="video/mp4">Your browser cannot play this video. <a href="media/trailer.mp4">Download the trailer</a>.</video><div class="gallery">__CARDS__</div></section><section><h2>Your weekend kit</h2><div class="gallery equipment">__EQUIPMENT__</div><p><a href="media/index.html">Review and download all media</a></p></section>
<section><details open><summary>Submission fields still to complete</summary><table>__PENDING__</table><p>Proposed category: Games. Proposed genres: Simulation, Sports. Confirm the Dashboard’s current options and test supported play modes before selecting them.</p><p>English listing draft. Multiplayer uses a reachable player host or dedicated server; it does not provide automatic matchmaking.</p><p><a href="README.md">Dashboard handoff and asset specifications</a> · <a href="listing.json">Listing source JSON</a></p></details></section>
<section><details><summary>Copy-ready listing text</summary><h3>Short description</h3><div class="copy">__SHORT__</div><h3>Long description</h3><div class="copy">__RAWTEXT__</div><p>Keywords: __KEYWORDS__</p></details></section>
</main><footer>Local content review preview, not an official Meta storefront. Existing game icon retained. No ratings, reviews or release date have been invented.</footer></html>
'''
for key, val in {'__NAME__':esc(d['name']), '__SHORT__':esc(d['short_description']), '__LONG__':paragraphs, '__CARDS__':cards, '__EQUIPMENT__':equipment, '__PENDING__':pending, '__RAWTEXT__':esc(d['long_description']), '__KEYWORDS__':esc(', '.join(d['keywords']))}.items():
    page = page.replace(key, val)
(root / 'index.html').write_text(page)
print('Rendered index.html. Characters:', {k:len(d[k]) for k in ['name','short_description','long_description']})
