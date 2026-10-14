import argparse
import subprocess
from pathlib import Path

import build

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache"

COMPILE_TARGETS = [
    "dist/Kinoue.lua",
    "dist/KinoueDemo.lua",
    "examples/Example.lua",
    "examples/ESP.lua",
]

SUITES = [
    ("integration", "Library", "examples/Demo.client.luau"),
    ("example", "UI", "examples/Example.lua"),
    ("esp", "UI", "examples/ESP.lua"),
    ("cursor", "UI", None),
    ("window", "UI", None),
    ("context", "UI", None),
    ("performance", "UI", None),
    ("destruction", "UI", None),
    ("settings", "UI", None),
    ("keybinds", "UI", None),
    ("subtoggle", "UI", None),
]


def read(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


def harness(library, checks, example):
    parts = [
        "local Mock = (function()\n" + read("tests/RobloxMock.luau") + "\nend)()",
        "local factory = function()\n" + read("dist/Kinoue.lua") + "\nend",
        "setfenv(factory, Mock.Environment)",
        f"local {library} = factory()",
    ]
    if example:
        parts += [
            f"local example = function({library})\n" + build.strip_loader(read(example)) + "\nend",
            "setfenv(example, Mock.Environment)",
            f"local window = example({library})",
        ]
    parts.append(read(f"tests/{checks}.luau"))
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau")
    parser.add_argument("--compiler", default="luau-compile")
    args = parser.parse_args()

    build.main()
    subprocess.run([args.compiler, "--null", *COMPILE_TARGETS], cwd=ROOT, check=True)
    subprocess.run([args.luau, "tests/model.luau"], cwd=ROOT, check=True)

    CACHE.mkdir(exist_ok=True)
    for name, library, example in SUITES:
        path = CACHE / f"{name}.luau"
        path.write_text(harness(library, name, example), encoding="utf-8", newline="\n")
        subprocess.run([args.luau, path.relative_to(ROOT).as_posix()], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
