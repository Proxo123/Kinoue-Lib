"""Run with: python tools/test.py --luau PATH_TO_LUAU --compiler PATH_TO_LUAU_COMPILE"""
import argparse
import subprocess
from pathlib import Path
import build

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
parser.add_argument("--compiler", default="luau-compile")
args = parser.parse_args()
build.main()
subprocess.run([args.compiler, "--null", "dist/BoogaUI.lua", "dist/BoogaDemo.lua"], cwd=ROOT, check=True)
subprocess.run([args.luau, "tests/model.luau"], cwd=ROOT, check=True)
mock = (ROOT / "tests/RobloxMock.luau").read_text(encoding="utf-8")
bundle = (ROOT / "dist/BoogaUI.lua").read_text(encoding="utf-8")
demo = (ROOT / "examples/Booga.client.luau").read_text(encoding="utf-8").split("\n", 1)[1]
checks = (ROOT / "tests/integration.luau").read_text(encoding="utf-8")
harness = "local Mock = (function()\n" + mock + "\nend)()\nlocal factory = function()\n" + bundle + "\nend\nsetfenv(factory, Mock.Environment)\nlocal Library = factory()\nlocal demo = function(Library)\n" + demo + "\nend\nsetfenv(demo, Mock.Environment)\nlocal window = demo(Library)\n" + checks
cache = ROOT / ".cache"
cache.mkdir(exist_ok=True)
(cache / "integration.luau").write_text(harness, encoding="utf-8")
subprocess.run([args.luau, ".cache/integration.luau"], cwd=ROOT, check=True)
