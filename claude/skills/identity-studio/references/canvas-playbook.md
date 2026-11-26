# Canvas playbook (claude.ai Design artifacts)

Practice that kept a long-running canvas fast and correct across 80+ versions. Each item cost a round
when it was missing.

## Boards

- One generator script per board family (write the .dc.html from Python), so every change is
  reproducible. Back up a board before patching it; every string replacement asserts it matched
  exactly once.
- Board root is `width:100%` with `overflow-x:clip`, never a fixed `width:1440px` (it scrolls
  15 px sideways once a vertical scrollbar appears).
- Keep the board's `$preview` height and its `h` in `canvas.json` in sync when content grows.
- Content never depends on an IntersectionObserver or entrance animation to appear: the canvas
  showed a whole page empty because of one.
- Data that is not real (positions, points, posts) is marked as an example on the board.

## Publishing

- Publish with the artifact `url`, `root` = the local canvas folder, `file_path` = the main
  board, `files` = the other changed boards plus `canvas.json`. A path may appear only once.
- When the viewer context shows a higher `edits`/rev than your last publish, someone else saved:
  read the artifact's files again before publishing.

## Images and assets

- The Design type blocks images from other domains. Every outside image (avatars, official art)
  becomes an uploaded asset: `asset: true` with up to 25 `file_paths`; reference the returned
  `/_blob/<id>` verbatim. In the shipped code, avatars stay live links to the public API.
- Origins that refuse scripted fetches (for example, a game avatar service that answers
  463 to curl; the same steps work for any such origin): in the built-in
  browser, on that origin, draw every image onto one canvas, put a visible link with the data
  URL, front the tab and click it for real. Only the first scripted download per page goes
  through. Crop the sheet locally (Pillow), upload, then hand the owner the command to move the
  file out of Downloads. Every download needs the owner's explicit ok, each time.
- Never transcribe base64 by hand; it corrupts silently.
- Before using a person's avatar, confirm the account (for example, the profile motto and groups):
  a nick given from memory can match an unrelated account.

## Previews and checks (scripts in this folder)

- `scripts/preview_dc.py BOARD 1440 --props '{...}' --assets map.json --shot out.png` renders a
  board locally with its webfonts; `--static` disables motion to check the still state; widths
  under 500 px are framed in an iframe because headless Chrome clamps the window.
- `scripts/overflow_check.py BOARD ...` fails any board that scrolls sideways with a classic
  scrollbar (exit 1).
- Report what was checked locally and what was not seen on the canvas itself (the canvas needs a
  login the agent never uses).
