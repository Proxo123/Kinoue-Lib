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
subprocess.run([args.compiler, "--null", "dist/BoogaUI.lua", "dist/BoogaDemo.lua", "examples/Example.lua", "examples/ESP.lua"], cwd=ROOT, check=True)
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
example = (ROOT / "examples/Example.lua").read_text(encoding="utf-8").split("\n", 1)[1]
example_checks = (ROOT / "tests/example.luau").read_text(encoding="utf-8")
example_harness = "local Mock = (function()\n" + mock + "\nend)()\nlocal factory = function()\n" + bundle + "\nend\nsetfenv(factory, Mock.Environment)\nlocal UI = factory()\nlocal example = function(UI)\n" + example + "\nend\nsetfenv(example, Mock.Environment)\nlocal window = example(UI)\n" + example_checks
(cache / "example.luau").write_text(example_harness, encoding="utf-8")
subprocess.run([args.luau, ".cache/example.luau"], cwd=ROOT, check=True)
esp = (ROOT / "examples/ESP.lua").read_text(encoding="utf-8").split("\n", 1)[1]
esp_checks = (ROOT / "tests/esp.luau").read_text(encoding="utf-8")
esp_harness = "local Mock = (function()\n" + mock + "\nend)()\nlocal factory = function()\n" + bundle + "\nend\nsetfenv(factory, Mock.Environment)\nlocal UI = factory()\nlocal example = function(UI)\n" + esp + "\nend\nsetfenv(example, Mock.Environment)\nlocal window = example(UI)\n" + esp_checks
(cache / "esp.luau").write_text(esp_harness, encoding="utf-8")
subprocess.run([args.luau, ".cache/esp.luau"], cwd=ROOT, check=True)
cursor_checks = (ROOT / "tests/cursor.luau").read_text(encoding="utf-8")
cursor_harness = "local Mock = (function()\n" + mock + "\nend)()\nlocal factory = function()\n" + bundle + "\nend\nsetfenv(factory, Mock.Environment)\nlocal UI = factory()\n" + cursor_checks
(cache / "cursor.luau").write_text(cursor_harness, encoding="utf-8")
subprocess.run([args.luau, ".cache/cursor.luau"], cwd=ROOT, check=True)
window_checks = (ROOT / "tests/window.luau").read_text(encoding="utf-8")
window_harness = "local Mock = (function()\n" + mock + "\nend)()\nlocal factory = function()\n" + bundle + "\nend\nsetfenv(factory, Mock.Environment)\nlocal UI = factory()\n" + window_checks
(cache / "window.luau").write_text(window_harness, encoding="utf-8")
subprocess.run([args.luau, ".cache/window.luau"], cwd=ROOT, check=True)
