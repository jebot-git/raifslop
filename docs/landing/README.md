# Public landing page

Live site: https://jebot-git.github.io/
Publication repository: https://github.com/jebot-git/jebot-git.github.io

`build.py` adapts the store listing preview for a public page, copies its selected
media, adds repository/privacy/support links, and omits submission instructions
and internal testing details. It does not imply the game is released on Quest.
No analytics, external scripts, third-party fonts, cookies or forms are added.
Video uses controls and does not autoplay. Images below the hero load lazily.

```sh
python3 docs/quest-store/render.py
python3 docs/landing/build.py builds/landing
```

Publish the output in the landing repository's `main` branch. GitHub Pages uses
that branch's root. The existing policy remains hosted by the game repository
at https://jebot-git.github.io/raifslop/privacy.html.
