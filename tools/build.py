import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
DIST = ROOT / "dist"
DEMO = ROOT / "examples" / "Demo.client.luau"

LIBRARY_NAME = "Kinoue"
DEMO_NAME = "KinoueDemo"

REQUIRE_PATTERN = re.compile(r"require\((script(?:\.[A-Za-z_]\w*)+)\)")

RUNTIME = """
__require = function(name)
    if __cache[name] ~= nil then
        return __cache[name]
    end
    assert(not __loading[name], "Circular dependency: " .. name)
    local factory = assert(__factories[name], "Unknown module: " .. name)
    __loading[name] = true
    local value = factory()
    __loading[name] = nil
    __cache[name] = value
    return value
end

return __require("init")
"""


def module_name(path):
    relative = path.relative_to(SRC).with_suffix("").as_posix()
    if relative == "init":
        return "init"
    if relative.endswith("/init"):
        return relative[: -len("/init")]
    return relative


def resolve(current, expression):
    parts = [] if current == "init" else current.split("/")
    for segment in expression.split(".")[1:]:
        if segment == "Parent":
            if parts:
                parts.pop()
        else:
            parts.append(segment)
    return "/".join(parts) or "init"


def bundle():
    paths = sorted(SRC.rglob("*.luau"), key=lambda path: path.relative_to(SRC).as_posix())
    modules = {module_name(path): path.read_text(encoding="utf-8") for path in paths}
    chunks = ["local __factories, __cache, __loading = {}, {}, {}\nlocal __require\n"]
    for name, source in modules.items():

        def replace(match):
            target = resolve(name, match[1])
            if target not in modules:
                raise ValueError(f"{name}: missing dependency {target}")
            return f"__require({json.dumps(target)})"

        source = REQUIRE_PATTERN.sub(replace, source)
        chunks.append(f"\n__factories[{json.dumps(name)}] = function()\n{source.rstrip()}\nend\n")
    chunks.append(RUNTIME)
    return "".join(chunks)


def strip_loader(source):
    return source.split("\n", 1)[1]


def item(parent, class_name, name, source=None):
    referent = f"RBX{len(list(parent.iter('Item')))}_{name}"
    node = ET.SubElement(parent, "Item", {"class": class_name, "referent": referent})
    props = ET.SubElement(node, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    if source is not None:
        ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = source
    return node


def write_text(path, text):
    path.write_text(text, encoding="utf-8", newline="\n")


def write_xml(path, tree):
    ET.indent(tree, space="  ")
    with open(path, "wb") as file:
        ET.ElementTree(tree).write(file, encoding="utf-8", xml_declaration=True)


def main():
    DIST.mkdir(exist_ok=True)
    source = bundle()
    demo = DEMO.read_text(encoding="utf-8")

    write_text(DIST / f"{LIBRARY_NAME}.lua", source)
    write_text(DIST / f"{DEMO_NAME}.lua", f"local Library = (function()\n{source}\nend)()\n{strip_loader(demo)}")

    model = ET.Element("roblox", {"version": "4"})
    item(model, "ModuleScript", LIBRARY_NAME, source)
    write_xml(DIST / f"{LIBRARY_NAME}.rbxmx", model)

    place = ET.Element("roblox", {"version": "4"})
    replicated = item(place, "ReplicatedStorage", "ReplicatedStorage")
    item(replicated, "ModuleScript", LIBRARY_NAME, source)
    starter = item(place, "StarterPlayer", "StarterPlayer")
    scripts = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    item(scripts, "LocalScript", DEMO_NAME, demo)
    item(place, "Workspace", "Workspace")
    write_xml(DIST / f"{DEMO_NAME}.rbxlx", place)

    print(f"Built {LIBRARY_NAME}.lua, {DEMO_NAME}.lua, {LIBRARY_NAME}.rbxmx, {DEMO_NAME}.rbxlx")


if __name__ == "__main__":
    main()
