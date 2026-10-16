"""Publish an already tested tag; never replace assets or downgrade latest."""
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
tag = os.environ["GITHUB_REF_NAME"]
pattern = r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
match = re.fullmatch(pattern, tag)
if not match:
    raise SystemExit("Release tags must be vMAJOR.MINOR.PATCH")
version = re.search(r'Version = "([0-9.]+)"', (root / "src/init.luau").read_text())[1]
if tag != "v" + version:
    raise SystemExit("Release tag and library version differ")
asset = root / "dist/Kinoue.lua"
checksum = root / "dist/Kinoue.sha256"
checksum.write_text(hashlib.sha256(asset.read_bytes()).hexdigest() + "  Kinoue.lua\n", encoding="utf-8")
latest = subprocess.run(["gh", "api", "repos/Proxo123/Kinoue-Lib/releases/latest"], capture_output=True, text=True)
if latest.returncode:
    raise SystemExit("Cannot determine the current release; refusing publication")
current = re.fullmatch(pattern, json.loads(latest.stdout)["tag_name"])
if not current:
    raise SystemExit("Current release version is unexpected")
promote = tuple(map(int, match.groups())) > tuple(map(int, current.groups()))
subprocess.run(["gh", "release", "create", tag, str(asset), str(checksum), "--verify-tag", "--title", "Kinoue " + tag, "--notes-from-tag", "--latest=" + str(promote).lower()], cwd=root, check=True)
