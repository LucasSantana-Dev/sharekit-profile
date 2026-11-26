"""Cut the magenta background (#FF00FF) out of a generated sprite and crop to content.

usage: python3 chroma_cut.py <input.png> [...]   -> writes <input>-cutout.png next to it

Removes only the background: a breadth-first flood fill from the image border walks outward
over "magenta enough" pixels (high red and blue, low green) and, only at the edge of that
already-removed region, over the dirtier fringe an image model tends to leave around a sprite.
An interior color that merely resembles magenta (an orchid or pink used inside the sprite
itself) is never touched, because nothing connects it to the border.
"""
import os
import sys
from collections import deque

from PIL import Image


def _is_core_magenta(r, g, b):
    return r > 170 and b > 170 and g < 110 and abs(r - b) < 70


def _is_fringe(r, g, b):
    # magenta blended into a dark outline (R and B well above G, not light purple); only ever
    # tested on a pixel adjacent to one already removed as background
    return r - g > 55 and b - g > 55 and abs(r - b) < 60 and g < 90


def _cutout_path(path):
    base, ext = os.path.splitext(path)
    return f"{base}-cutout{ext}"


def cut(path):
    dest = _cutout_path(path)
    if os.path.abspath(dest) == os.path.abspath(path):
        sys.exit(f"refusing to overwrite the source file: {path}")

    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    removed = [[False] * w for _ in range(h)]
    queue = deque()

    def seed(x, y):
        if removed[y][x]:
            return
        r, g, b, _ = px[x, y]
        if _is_core_magenta(r, g, b):
            removed[y][x] = True
            queue.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not removed[ny][nx]:
                r, g, b, _ = px[nx, ny]
                if _is_core_magenta(r, g, b) or _is_fringe(r, g, b):
                    removed[ny][nx] = True
                    queue.append((nx, ny))

    for y in range(h):
        for x in range(w):
            if removed[y][x]:
                px[x, y] = (0, 0, 0, 0)

    box = im.getbbox()
    if box:
        im = im.crop(box)
    im.save(dest)
    return dest, im.size


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: python3 chroma_cut.py <input.png> [...]")
    for p in sys.argv[1:]:
        print(*cut(p))
