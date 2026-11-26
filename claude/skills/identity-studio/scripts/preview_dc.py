#!/usr/bin/env python3
"""Render a claude.ai Design board (.dc.html) locally so it can be screenshotted and measured.

Runs the board's `class Component extends DCLogic` renderVals() in node with the given props,
expands the subset of DC templating the boards use (<sc-if value>, <sc-for list as>, {{path}}),
keeps the page's webfont <link>s (without them text measures narrower and "fits" falsely), and
maps /_blob/<id> assets to local files.

Usage:
  preview_dc.py BOARD.dc.html WIDTH [--props JSON] [--assets MAP.json] [--static] [--main-only]
                [--out OUT.html] [--shot OUT.png] [--height 1400]

  --static     disable animations: (prefers-reduced-motion:no-preference) becomes `not all`
  --main-only  render only <main> (default renders everything between </helmet> and </x-dc>)
  --assets     JSON {"<blob id>": "path/to/local.png"}; relative paths resolve from the JSON's folder
  --shot       screenshot with headless Chrome after a 2.5 s virtual-time budget (entrances done)

Stdlib only; needs `node` and Google Chrome for --shot.
"""
import argparse, json, os, pathlib, re, subprocess, sys, tempfile

CHROME = os.environ.get('CHROME', '/Applications/Google Chrome.app' '/Contents/MacOS/Google Chrome')


def render_vals(src, props):
    m = re.search(r'data-dc-script[^>]*>(.*?)</script>', src, re.S)
    if not m:
        return {}
    prog = ('class DCLogic{constructor(p){this.props=p||{};this.state={}}setState(){}}\n' + m.group(1) +
            '\nconst c=new Component(' + json.dumps(props) + ');const v=c.renderVals?c.renderVals():{};'
            'process.stdout.write(JSON.stringify(v,(k,x)=>typeof x==="function"?null:x));')
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
        f.write(prog)
    try:
        return json.loads(subprocess.check_output(['node', f.name]) or b'{}')
    except FileNotFoundError:
        print('node not found: install Node.js to run renderVals', file=sys.stderr)
        sys.exit(2)
    finally:
        os.unlink(f.name)


def get(ctx, path):
    cur = ctx
    for part in path.split('.'):
        cur = cur.get(part) if isinstance(cur, dict) else None
    return cur


def render(t, ctx):
    while True:
        m = re.search(r'<sc-(if|for)\b([^>]*)>', t)
        if not m:
            break
        tag, attrs = m.group(1), m.group(2)
        depth, i = 1, m.end()
        while depth:
            a = t.find('<sc-' + tag, i)
            b = t.find('</sc-' + tag + '>', i)
            if b == -1:
                sys.exit(f'unclosed <sc-{tag}>')
            if a != -1 and a < b:
                depth += 1
                i = a + 4
            else:
                depth -= 1
                i = b + len('</sc-' + tag + '>')
        inner = t[m.end():b]
        if tag == 'if':
            k = re.search(r'value="\{\{\s*([\w.]+)\s*\}\}"', attrs)
            v = get(ctx, k.group(1)) if k else None
            out = render(inner, ctx) if v and v != 'false' else ''
        else:
            k = re.search(r'list="\{\{\s*([\w.]+)\s*\}\}"', attrs)
            name = re.search(r'as="(\w+)"', attrs).group(1)
            out = ''.join(render(inner, {**ctx, name: it}) for it in (get(ctx, k.group(1)) if k else None) or [])
        t = t[:m.start()] + out + t[i:]
    return re.sub(r'\{\{\s*([\w.]+)\s*\}\}', lambda k: '' if get(ctx, k.group(1)) is None else str(get(ctx, k.group(1))), t)


def build(board, width, props=None, assets=None, static=False, main_only=False):
    src = open(board).read()
    vals = render_vals(src, props or {})
    css = '\n'.join(re.findall(r'<style>(.*?)</style>', src, re.S))
    if static:
        css = re.sub(r'\(\s*prefers-reduced-motion\s*:\s*no-preference\s*\)', 'not all', css)
    links = ''.join(re.findall(r'<link[^>]*>', src))
    if main_only and '<main' in src:
        body = src[src.index('<main'):src.index('</main>') + 7]
    else:
        body = src[src.index('</helmet>') + 9:src.index('</x-dc>')] if '</helmet>' in src else src
    body = render(body, vals)
    html = (f'<!doctype html><html><head><meta charset="utf-8">{links}<style>{css}</style></head>'
            f'<body style="margin:0">{body}</body></html>')
    if assets:  # longest id first so one id never rewrites the prefix of another; CSS url()s too
        base = os.path.dirname(os.path.abspath(assets))
        for k, v in sorted(json.load(open(assets)).items(), key=lambda kv: -len(kv[0])):
            html = html.replace('/_blob/' + k, pathlib.Path(base, v).resolve().as_uri())
    return html


def chrome(args):
    try:
        return subprocess.run([CHROME] + args, capture_output=True, text=True)
    except FileNotFoundError:
        print(f'Chrome not found at {CHROME} (set CHROME=)', file=sys.stderr)
        sys.exit(2)


def shot(html_path, png, width, height, static=False):
    if os.path.exists(png):
        os.unlink(png)
    r = chrome(['--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
                '--virtual-time-budget=2500', f'--screenshot={png}', f'--window-size={max(width, 500)},{height}']
               + (['--force-prefers-reduced-motion'] if static else []) + ['file://' + os.path.abspath(html_path)])
    if r.returncode or not os.path.exists(png):
        sys.exit(f'chrome failed: {r.stderr[-300:]}')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('board'); ap.add_argument('width', type=int)
    ap.add_argument('--props', default='{}'); ap.add_argument('--assets')
    ap.add_argument('--static', action='store_true'); ap.add_argument('--main-only', action='store_true')
    ap.add_argument('--out'); ap.add_argument('--shot'); ap.add_argument('--height', type=int, default=1400)
    a = ap.parse_args()
    out = a.out or os.path.splitext(a.board)[0] + f'.preview-{a.width}.html'
    open(out, 'w').write(build(a.board, a.width, json.loads(a.props), a.assets, a.static, a.main_only))
    if a.shot:
        if a.width < 500:  # headless Chrome clamps the window to 500 px: frame the page at the true width
            frame = out + '.frame.html'
            open(frame, 'w').write(f'<body style="margin:0"><iframe src="{os.path.basename(out)}" '
                                   f'style="border:0;width:{a.width}px;height:{a.height}px"></iframe></body>')
            shot(frame, a.shot, a.width, a.height, a.static)
        else:
            shot(out, a.shot, a.width, a.height, a.static)
    print(out)


if __name__ == '__main__':
    main()
