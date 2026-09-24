"""Build the public landing page from the store preview and original media."""
from pathlib import Path
import re
import shutil
import sys

repo = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]) if len(sys.argv) > 1 else repo / 'builds/landing'
out.mkdir(parents=True, exist_ok=True)
page = (repo / 'docs/quest-store/index.html').read_text()
page = page.replace('Quest listing draft — Ultimate Boomer Simulator', 'Ultimate Boomer Simulator | PLdot')
page = page.replace('<style>', '''<meta name="description" content="Fish, golf and grill in Ultimate Boomer Simulator. Explore the environments, watch the trailer and follow development by PLdot.">
<link rel="canonical" href="https://jebot-git.github.io/">
<link rel="icon" type="image/png" href="media/icon.png">
<meta property="og:title" content="Ultimate Boomer Simulator">
<meta property="og:description" content="Fishing, golf and waterside BBQs in VR. Follow development by PLdot.">
<meta property="og:type" content="website">
<meta property="og:url" content="https://jebot-git.github.io/">
<meta property="og:image" content="https://jebot-git.github.io/media/cover-landscape.png">
<style>''', 1)
page = page.replace('</style>', '''@font-face{font-family:Almonte;src:url('media/fonts/Almonte.otf');font-display:swap}h1,h2{font-family:Almonte,system-ui,sans-serif;font-weight:400}h1{font-size:42px}h2{font-size:36px}nav{display:flex;gap:20px;flex-wrap:wrap}.button{display:block;padding:12px 18px;border:1px solid var(--mint);border-radius:8px;text-align:center;text-decoration:none}.hero{min-height:400px}.hero img{max-height:340px;object-fit:contain;object-position:left}.skip{position:absolute;left:-9999px}.skip:focus{left:16px;top:16px;background:var(--bg);padding:16px;z-index:2}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto}}
</style>''')
page = re.sub(r'<header>.*?</header>', '''<body><a class="skip" href="#main">Skip to content</a><header><span class="label">PLdot development team</span><nav aria-label="Main navigation"><a href="#environments">Trailer &amp; scenes</a><a href="https://github.com/jebot-git/raifslop">Repository</a><a href="https://jebot-git.github.io/raifslop/privacy.html">Privacy policy</a></nav></header>''', page, flags=re.S)
page = page.replace('<main>', '<main id="main">', 1).replace('../../assets/icon.svg','media/logo-mark.svg')
page = re.sub(r'<aside class="aside">.*?</aside>', '''<aside class="aside"><div class="price">In development for Meta Quest</div><p>Cast a line, play a round, and make time for the view.</p><a class="button" href="https://github.com/jebot-git/raifslop">Follow the project on GitHub</a><p>Free to play, with no real-money purchases. A public Quest Store release date has not been announced.</p><p><a href="mailto:jewzuv@gmail.com">Contact PLdot</a> · <a href="https://jebot-git.github.io/raifslop/privacy.html">Privacy &amp; data requests</a></p></aside>''', page, flags=re.S)
page = page.replace('<section><h2>Find your spot</h2>', '<section id="environments"><h2>Find your spot</h2>')
page = page.replace('</video><div class="gallery">', '</video><p class="subtle">A quiet tour of the game’s waterside environments. Captured in the desktop game engine; Quest visuals may differ.</p><div class="gallery">')
page = page.replace('<p><a href="media/index.html">Review and download all media</a></p>', '<p class="subtle">Equipment showcases use the game’s models with staged lighting and blurred backgrounds.</p>')
page = re.sub(r'<section><details.*?</section>', '', page, flags=re.S)
page = re.sub(r'<footer>.*?</footer>', '''<footer>Ultimate Boomer Simulator · PLdot development team<br><a href="https://github.com/jebot-git/raifslop">Game repository</a> · <a href="https://jebot-git.github.io/raifslop/privacy.html">Privacy policy</a> · <a href="mailto:jewzuv@gmail.com">Support</a></footer>''',page,flags=re.S)
page = page.replace('</html>', '</body></html>')
(out/'index.html').write_text(page)
(out/'.nojekyll').touch()
files = sorted(set(re.findall(r'(?:src|href|poster)="(media/[^"#]+)"', page) + re.findall(r"url\(['\"]?(media/[^)'\"]+)",page) + ['media/cover-landscape.png']))
for name in files:
    target = out/name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(repo/'docs/quest-store'/name,target)
for name in ['License.txt','License.pdf','README.md','.gitattributes']:
    shutil.copy2(repo/'docs/quest-store/media/fonts'/name,out/'media/fonts'/name)
(out/'README.md').write_text('''# Ultimate Boomer Simulator landing page

Published at https://jebot-git.github.io/ using GitHub Pages.

Source: https://github.com/jebot-git/raifslop/tree/stores/docs/landing
Build with `python3 docs/landing/build.py <output-directory>` after rendering
`docs/quest-store/render.py`. Reuses the existing game icon and store media.
CC0 font provenance and the original author licence are in `media/fonts/`.
Desktop game-engine captures; equipment shots are editorial staging.
Privacy policy: https://jebot-git.github.io/raifslop/privacy.html
''')
print(f'Built {out}: {len(files)} media dependencies')
