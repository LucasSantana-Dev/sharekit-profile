#!/usr/bin/env python3
"""Horizontal-scroll gate for Design boards: renders each board inside an iframe of (width - 15) px,
the room left when a classic vertical scrollbar appears, and fails when the page scrolls sideways.

Usage: overflow_check.py BOARD.dc.html [BOARD2.dc.html ...] [--assets MAP.json]
Width comes from each board's "$preview" width, or --width (repeatable). Exit 1 when any board overflows,
2 when node or Chrome is missing.

Elements listed under `out` that live inside a deliberate horizontal scroller (card rows) are fine
as long as sw == cw. A board whose root has a fixed width (width:1440px) is the usual culprit:
make the root width:100% and add overflow-x:clip.
"""
import argparse, json, os, re, shutil, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preview_dc import build, chrome  # noqa: E402

PROBE = """<script>addEventListener('load',()=>setTimeout(()=>{const W=document.documentElement.clientWidth,f=[];
for(const e of document.querySelectorAll('body *')){const r=e.getBoundingClientRect();
if(r.width&&(r.right>W+1||r.left<-1)){let p=e.parentElement,inside=false;
while(p&&p!==document.body){const q=p.getBoundingClientRect();if(q.right>W+1||q.left<-1){inside=true;break}p=p.parentElement}
if(!inside)f.push(((typeof e.className==='string'&&e.className)||e.tagName)+' R'+Math.round(r.right))}}
parent.document.title=JSON.stringify({sw:document.documentElement.scrollWidth,cw:W,out:f.slice(0,6)})},1500))</script>"""


def check(board, width, assets=None):
    d = tempfile.mkdtemp()
    page, frame = os.path.join(d, 'page.html'), os.path.join(d, 'frame.html')
    open(page, 'w').write(build(board, width, {}, assets).replace('</body>', PROBE + '</body>'))
    open(frame, 'w').write(f'<html><head><title>x</title></head><body style="margin:0"><iframe src="page.html" '
                           f'style="border:0;width:{width - 15}px;height:1200px"></iframe></body></html>')
    dom = chrome(['--headless=new', '--disable-gpu', '--allow-file-access-from-files', '--virtual-time-budget=3000',
                  f'--window-size={max(width, 520)},1300', '--dump-dom', 'file://' + frame]).stdout
    shutil.rmtree(d, ignore_errors=True)
    t = re.search(r'<title>(.*?)</title>', dom)
    try:
        r = json.loads(t.group(1)) if t else None
    except ValueError:
        r = None
    return r


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('boards', nargs='+'); ap.add_argument('--assets')
    ap.add_argument('--width', type=int, action='append', help='check at this width (repeatable); default: the board\'s $preview width')
    a = ap.parse_args()
    bad = 0
    for b in a.boards:
        m = re.search(r'"\$preview"\s*:\s*\{\s*"width"\s*:\s*(\d+)', open(b).read())
        for width in a.width or [int(m.group(1)) if m else 1440]:
            r = check(b, width, a.assets)
            if r is None:
                print(f'{os.path.basename(b)} {width}: NO MEASURE (render failed)'); bad += 1; continue
            ok = r['sw'] <= r['cw']
            bad += not ok
            print(f"{os.path.basename(b)} {width}: {'PASS' if ok else 'FAIL'} sw={r['sw']} cw={r['cw']} out={r['out']}")
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
