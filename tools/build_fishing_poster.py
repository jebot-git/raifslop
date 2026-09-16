"""Build the Korean fishing-plan poster with outlined Hangul (no runtime font).
Requires fonttools; defaults to the locally installed OFL Noto Sans CJK Bold.
"""
from pathlib import Path
import argparse
import re
from fontTools.ttLib import TTCollection
from fontTools.pens.svgPathPen import SVGPathPen

ROOT=Path(__file__).resolve().parents[1]
COPY=[('인민의 호수부두 · 수산국',39,46,840),
      ('낚시계획 만세!',78,144,980),
      ('5개년 어획목표를 초과달성하자!',44,613,1000)]

def build(font_path):
    collection=TTCollection(str(font_path))
    font=next(f for f in collection.fonts if any(n.nameID==1 and n.toUnicode()=='Noto Sans CJK KR' for n in f['name'].names))
    glyphs=font.getGlyphSet();cmap=font.getBestCmap();units=font['head'].unitsPerEm
    parts=['<g id="korean-propaganda-lettering" fill="#f4e8c9" stroke="#f4e8c9" stroke-width="12" stroke-linejoin="miter">']
    for text,size,baseline,width in COPY:
        names=[cmap[ord(c)] for c in text]
        advances=[font['hmtx'][name][0]+35 for name in names]
        scale_y=size/units;scale_x=width/sum(advances)
        parts.append(f'<g aria-label="{text}" transform="translate({(1120-width)/2},{baseline}) scale({scale_x},-{scale_y})">')
        at=0
        for name,advance in zip(names,advances):
            pen=SVGPathPen(glyphs);glyphs[name].draw(pen)
            parts.append(f'<path transform="translate({at},0)" d="{pen.getCommands()}"/>');at+=advance
        parts.append('</g>')
    parts.append('</g>')
    source=(ROOT/'source/posters/fishing_plan_base.svg').read_text()
    source=re.sub(r'<g text-anchor="middle".*?</g>','\n'.join(parts),source,flags=re.S)
    source=source.replace('<rect ', '<title>인민의 낚시계획</title>\n<desc>Original fishing-plan parody; Korean lettering outlined from Noto Sans CJK KR Bold.</desc>\n<rect ',1)
    target=ROOT/'assets/environment/shore_details/fishing_plan_poster.svg'
    target.write_text(source)
    print(target)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--font',type=Path,default=Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'))
    build(parser.parse_args().font)
