#!/usr/bin/env python3
"""
Skill Packager - Creates a distributable .skill file of a skill folder

Usage:
    python utils/package_skill.py <path/to/skill-folder> [output-directory]

Example:
    python utils/package_skill.py skills/public/my-skill
    python utils/package_skill.py skills/public/my-skill ./dist
"""

import sys
import re
import json
import zipfile
from pathlib import Path
from quick_validate import validate_skill

# Plugin-provided MCP servers (installer enables the plugin, not a command).
PLUGIN_MCPS = {"claude-mem", "serena", "github", "playwright", "supabase"}


def _declared_mcps(skill_md: Path):
    """Parse `mcp_servers:` from SKILL.md frontmatter (no yaml dep)."""
    try:
        text = skill_md.read_text(encoding="utf-8")
    except OSError:
        return []
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        return []
    fm = m.group(1)
    flow = re.search(r"^mcp_servers:\s*\[(.*?)\]", fm, re.M)
    if flow:
        return [s.strip().strip("'\"") for s in flow.group(1).split(",") if s.strip()]
    block = re.search(r"^mcp_servers:\s*\n((?:\s*-\s*.+\n?)+)", fm, re.M)
    if block:
        return [re.sub(r"^\s*-\s*", "", ln).strip().strip("'\"")
                for ln in block.group(1).splitlines() if ln.strip()]
    return []


def generate_mcp_json(skill_path: Path):
    """Emit a PORTABLE mcp.json from the skill's `mcp_servers:` manifest (compozy
    reusable-agent shape; see standards/skill-mcp-manifest.md) so an installed skill
    declares its MCP dependencies. Portable = server names + plugin/required markers,
    NOT this machine's local config (no absolute paths leak into the bundle). The
    installer fills in real configs. Returns the count, or 0 if nothing declared."""
    decl = _declared_mcps(skill_path / "SKILL.md")
    if not decl:
        return 0
    servers = {}
    for n in decl:
        if n in PLUGIN_MCPS:
            servers[n] = {"plugin": n, "_note": "enable this plugin to provide the MCP"}
        else:
            servers[n] = {"_required": True, "_note": f"configure the '{n}' MCP server on install"}
    (skill_path / "mcp.json").write_text(json.dumps({"mcpServers": servers}, indent=2) + "\n")
    return len(servers)


def package_skill(skill_path, output_dir=None):
    """
    Package a skill folder into a .skill file.

    Args:
        skill_path: Path to the skill folder
        output_dir: Optional output directory for the .skill file (defaults to current directory)

    Returns:
        Path to the created .skill file, or None if error
    """
    skill_path = Path(skill_path).resolve()

    # Validate skill folder exists
    if not skill_path.exists():
        print(f"❌ Error: Skill folder not found: {skill_path}")
        return None

    if not skill_path.is_dir():
        print(f"❌ Error: Path is not a directory: {skill_path}")
        return None

    # Validate SKILL.md exists
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        print(f"❌ Error: SKILL.md not found in {skill_path}")
        return None

    # Run validation before packaging
    print("🔍 Validating skill...")
    valid, message = validate_skill(skill_path)
    if not valid:
        print(f"❌ Validation failed: {message}")
        print("   Please fix the validation errors before packaging.")
        return None
    print(f"✅ {message}\n")

    # Generate a portable mcp.json from the skill's mcp_servers manifest (compozy
    # port) so the distributed .skill declares its MCP dependencies. Skills with no
    # mcp_servers field are unaffected.
    n_mcp = generate_mcp_json(skill_path)
    if n_mcp:
        print(f"📋 Generated mcp.json — {n_mcp} MCP server(s) declared\n")

    # Determine output location
    skill_name = skill_path.name
    if output_dir:
        output_path = Path(output_dir).resolve()
        output_path.mkdir(parents=True, exist_ok=True)
    else:
        output_path = Path.cwd()

    skill_filename = output_path / f"{skill_name}.skill"

    # Create the .skill file (zip format)
    try:
        with zipfile.ZipFile(skill_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # Walk through the skill directory
            for file_path in skill_path.rglob('*'):
                if file_path.is_file():
                    # Calculate the relative path within the zip
                    arcname = file_path.relative_to(skill_path.parent)
                    zipf.write(file_path, arcname)
                    print(f"  Added: {arcname}")

        print(f"\n✅ Successfully packaged skill to: {skill_filename}")
        return skill_filename

    except Exception as e:
        print(f"❌ Error creating .skill file: {e}")
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python utils/package_skill.py <path/to/skill-folder> [output-directory]")
        print("\nExample:")
        print("  python utils/package_skill.py skills/public/my-skill")
        print("  python utils/package_skill.py skills/public/my-skill ./dist")
        sys.exit(1)

    skill_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None

    print(f"📦 Packaging skill: {skill_path}")
    if output_dir:
        print(f"   Output directory: {output_dir}")
    print()

    result = package_skill(skill_path, output_dir)

    if result:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
