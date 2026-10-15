import argparse
import subprocess
import struct
import zlib
from pathlib import Path

import build

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache"

COMPILE_TARGETS = [
    "dist/Kinoue.lua",
    "dist/KinoueDemo.lua",
    "examples/Example.lua",
    "examples/ESP.lua",
    "examples/KeySystem.lua",
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
    ("conflicts", "UI", None),
    ("notifications", "UI", None),
    ("search", "UI", None),
    ("replace", "UI", None),
    ("background", "UI", None),
    ("keysystem", "UI", None),
    ("layout", "UI", None),
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
    media = subprocess.run([args.luau, "tests/media.luau"], cwd=ROOT, check=True, capture_output=True, text=True)
    for line in media.stdout.splitlines():
        if not line.startswith("PNG:"):
            print(line)
            continue
        data = bytes.fromhex(line[4:])
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        offset, compressed = 8, bytearray()
        while offset < len(data):
            size = struct.unpack_from(">I", data, offset)[0]
            chunk = data[offset + 4:offset + 8 + size]
            assert zlib.crc32(chunk) == struct.unpack_from(">I", data, offset + 8 + size)[0]
            if chunk[:4] == b"IDAT":
                compressed.extend(chunk[4:])
            offset += 12 + size
        assert zlib.decompress(compressed) == bytes([0, 255, 0, 0, 255, 0, 255, 0, 128])

    CACHE.mkdir(exist_ok=True)
    for name, library, example in SUITES:
        path = CACHE / f"{name}.luau"
        path.write_text(harness(library, name, example), encoding="utf-8", newline="\n")
        subprocess.run([args.luau, path.relative_to(ROOT).as_posix()], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
