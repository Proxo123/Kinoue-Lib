local Gif = require("../src/internal/Gif")
local Png = require("../src/internal/Png")
local fixtures = require("./MediaFixtures")

local function crc(data)
    local value = 0xFFFFFFFF
    for index = 1, #data do
        value = bit32.bxor(value, string.byte(data, index))
        for _ = 1, 8 do
            value = bit32.bxor(bit32.rshift(value, 1), bit32.band(value, 1) == 1 and 0xEDB88320 or 0)
        end
    end
    return bit32.bnot(value)
end

local checkpoints = 0
for _, fixture in ipairs(fixtures) do
    local gif = Gif.parse(fixture.Data)
    assert(gif.Width == fixture.Width and gif.Height == fixture.Height)
    assert(#gif.Frames == #fixture.Full)
    for _, scale in ipairs({ 1, 2 }) do
        local expected = scale == 1 and fixture.Full or fixture.Half
        Gif.render(gif, math.floor(gif.Width / scale), math.floor(gif.Height / scale), function(canvas, index)
            for offset = 0, buffer.len(canvas) - 4, 4 do
                if buffer.readu8(canvas, offset + 3) == 0 then
                    buffer.writeu32(canvas, offset, 0)
                end
            end
            assert(
                crc(buffer.tostring(canvas)) == expected[index],
                fixture.Name .. " frame " .. index .. " scale " .. scale
            )
        end, function()
            checkpoints += 1
        end)
    end
end
assert(checkpoints > 0)
for _, data in ipairs({ "", "GIF89a", fixtures[1].Data:sub(1, 30), "GIF89a" .. string.rep("\255", 12) }) do
    assert(not pcall(Gif.parse, data), "Malformed GIF must fail")
end
assert(not pcall(function()
    Gif.render(Gif.parse(fixtures[1].Data), 20, 18, function() end, function()
        error("cancelled")
    end)
end), "Decoding must be cancellable")
local raw = buffer.create(9)
buffer.writeu32(raw, 1, 0xFF0000FF)
buffer.writeu32(raw, 5, 0x8000FF00)
local png = Png.encode(2, 1, raw)
print("PNG:" .. (png:gsub(".", function(byte)
    return string.format("%02x", string.byte(byte))
end)))
assert(Png.hash("hello") == "3610a6864f9f2cab-5")
print(
    "PASS: GIF palette, transparency, disposal, interlace, dictionary growth, downsampling, cancellation, PNG encoding"
)
