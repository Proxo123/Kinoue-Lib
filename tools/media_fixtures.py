import io
import random
import zlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageSequence

ROOT = Path(__file__).resolve().parents[1]


def literal(data):
    return '"' + "".join(f"\\{byte:03d}" for byte in data) + '"'


def pixels(image, width, height):
    image = image.convert("RGBA")
    result = bytearray()
    for y in range(height):
        for x in range(width):
            pixel = image.getpixel((x * image.width // width, y * image.height // height))
            result.extend(pixel if pixel[3] else (0, 0, 0, 0))
    return bytes(result)


def main():
    fixtures = []
    palette = [0, 0, 0, 255, 40, 20, 20, 255, 40, 40, 20, 255] + [0] * 756
    frames = []
    for index in range(5):
        image = Image.new("P", (20, 18), 0)
        image.putpalette(palette)
        ImageDraw.Draw(image).rectangle((index * 2, 2, index * 2 + 5, 13), fill=index % 3 + 1)
        frames.append(image)
    for name, disposal in [("restore-background", 2), ("restore-previous", [1, 3, 3, 1, 2])]:
        stream = io.BytesIO()
        frames[0].save(stream, "GIF", save_all=True, append_images=frames[1:], transparency=0,
                       disposal=disposal, duration=[100, 50, 200, 30, 80], optimize=True)
        fixtures.append((name, stream.getvalue()))
    randomizer = random.Random(761)
    image = Image.new("P", (96, 96))
    image.putpalette([value for index in range(256) for value in (index, (index * 7) % 256, (index * 17) % 256)])
    image.putdata([randomizer.randrange(256) for _ in range(96 * 96)])
    stream = io.BytesIO()
    image.save(stream, "GIF", interlace=True)
    fixtures.append(("interlaced-dictionary-growth", stream.getvalue()))
    rows = ["return {"]
    for name, data in fixtures:
        image = Image.open(io.BytesIO(data))
        expected, half = [], []
        for frame in ImageSequence.Iterator(image):
            expected.append(zlib.crc32(pixels(frame, image.width, image.height)))
            half.append(zlib.crc32(pixels(frame, image.width // 2, image.height // 2)))
        rows.append(f'    {{ Name = "{name}", Data = {literal(data)}, Width = {image.width}, Height = {image.height},')
        rows.append("      Full = { " + ", ".join(str(n) for n in expected) + " }, Half = { " + ", ".join(str(n) for n in half) + " } },")
    rows.append("    Images = {")
    image = Image.new("RGB", (12, 8), (85, 120, 200))
    for name, format_name, options in [("png", "PNG", {}), ("jpeg", "JPEG", {}),
                                        ("progressive.jpeg", "JPEG", {"progressive": True})]:
        stream = io.BytesIO()
        image.save(stream, format_name, **options)
        rows.append(f'        {{ Name = "{name}", Data = {literal(stream.getvalue())}, Width = 12, Height = 8 }},')
    rows.extend(["    },", "}"])
    (ROOT / "tests/MediaFixtures.luau").write_text("\n".join(rows) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
