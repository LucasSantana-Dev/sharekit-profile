from pathlib import Path
from playwright.sync_api import sync_playwright
import json

ROUTES = [
    {"path": "/", "name": "home"},
    {"path": "/pricing", "name": "pricing"},
]
BASE_URL = 'http://127.0.0.1:3000'
ARTIFACT_DIR = Path('/tmp/webapp-testing-bundle')
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    report = {"routes": []}

    for route in ROUTES:
        page = browser.new_page(viewport={"width": 1440, "height": 960})
        console_errors = []
        page_errors = []
        page.on('console', lambda msg, errors=console_errors: errors.append(msg.text()) if msg.type == 'error' else None)
        page.on('pageerror', lambda err, errors=page_errors: errors.append(str(err)))
        page.goto(f"{BASE_URL}{route['path']}", wait_until='networkidle')
        screenshot_path = ARTIFACT_DIR / f"{route['name']}.png"
        page.screenshot(path=str(screenshot_path), full_page=True)
        report['routes'].append({
            'path': route['path'],
            'screenshot': str(screenshot_path),
            'console_errors': console_errors,
            'page_errors': page_errors,
        })
        page.close()

    browser.close()

(Path(ARTIFACT_DIR) / 'report.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
