"""Render the privacy policy as a standalone page using only the standard library.

Run after finalising PRIVACY_POLICY.md. Only the Markdown constructs used in
that document are supported; HTML is escaped and unfinished drafts are rejected.
"""

from pathlib import Path
import html
import re


ROOT = Path(__file__).resolve().parent


def inline(text):
    tokens = re.split(r'(\[[^\]]+\]\((?:https://|mailto:)[^\s)]+\)|\*\*[^*]+\*\*)', text)
    output = []
    for token in tokens:
        link = re.fullmatch(r'\[([^\]]+)\]\(((?:https://|mailto:)[^\s)]+)\)', token)
        if link:
            output.append(f'<a href="{html.escape(link[2], quote=True)}">{html.escape(link[1])}</a>')
        elif token.startswith('**') and token.endswith('**'):
            output.append(f'<strong>{inline(token[2:-2])}</strong>')
        else:
            output.append(html.escape(token))
    return ''.join(output)


def render():
    source = (ROOT / 'PRIVACY_POLICY.md').read_text(encoding='utf-8')
    if 'Draft for publisher review' in source or re.search(r'\[[A-Z][A-Z /_,—-]+\]', source):
        raise ValueError('Complete the policy before generating the public page')
    sections = []
    for block in source.strip().split('\n\n'):
        block = ' '.join(block.splitlines())
        if block.startswith('# '):
            sections.append(f'<h1>{inline(block[2:])}</h1>')
        elif block.startswith('## '):
            title = block[3:]
            anchor = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
            sections.append(f'<h2 id="{anchor}">{inline(title)}</h2>')
        else:
            sections.append(f'<p>{inline(block)}</p>')
    page = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Ultimate Boomer Simulator privacy policy and data deletion contact.">
<title>Privacy Policy — Ultimate Boomer Simulator</title>
<style>
:root { color-scheme: light dark; }
body { max-width: 780px; margin: 0 auto; padding: 28px 22px 64px;
  font: 17px/1.65 system-ui, sans-serif; overflow-wrap: anywhere; }
h1 { font-size: 2rem; line-height: 1.2; }
h2 { font-size: 1.4rem; line-height: 1.3; margin-top: 2.2rem; }
a { text-underline-offset: 3px; }
a:focus-visible { outline: 3px solid currentColor; outline-offset: 4px; }
nav { border-block: 1px solid #888; padding: 12px 0; }
footer { border-top: 1px solid #888; margin-top: 36px; padding-top: 16px; }
</style>
</head>
<body>
<nav aria-label="Policy shortcuts"><a href="#your-choices-and-deletion-requests">Request data deletion</a> · <a href="mailto:jewzuv@gmail.com">Contact privacy support</a></nav>
<main>
''' + '\n'.join(sections) + '''
</main>
<footer>Ultimate Boomer Simulator · PLdot development team</footer>
</body>
</html>
'''
    destination = ROOT / 'privacy.html'
    destination.write_text(page, encoding='utf-8')
    print(f'Rendered {destination.name}')


if __name__ == '__main__':
    render()
