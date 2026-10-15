local Png = {}
local xor, shift, band = bit32.bxor, bit32.rshift, bit32.band
local crcTable = table.create(256)
for index = 0, 255 do
    local value = index
    for _ = 1, 8 do
        value = band(value, 1) == 1 and xor(shift(value, 1), 0xEDB88320) or shift(value, 1)
    end
    crcTable[index + 1] = value
end

local function big(value)
    return string.char(
        band(shift(value, 24), 255),
        band(shift(value, 16), 255),
        band(shift(value, 8), 255),
        band(value, 255)
    )
end

local function crc(data, value, checkpoint)
    value = value or 0xFFFFFFFF
    for first = 1, #data, 16384 do
        for index = first, math.min(#data, first + 16383) do
            value = xor(shift(value, 8), crcTable[xor(band(value, 255), string.byte(data, index)) + 1])
        end
        if checkpoint then
            checkpoint()
        end
    end
    return value
end

function Png.hash(data, checkpoint)
    local second = 2166136261
    for first = 1, #data, 16384 do
        for index = first, math.min(#data, first + 16383) do
            second = xor(second, string.byte(data, index))
            second = (second * 403 + bit32.lshift(second, 24)) % 4294967296
        end
        if checkpoint then
            checkpoint()
        end
    end
    return string.format("%08x%08x-%x", bit32.bnot(crc(data, nil, checkpoint)), second, #data)
end

local function chunk(kind, data, checkpoint)
    local checksum = bit32.bnot(crc(data, crc(kind), checkpoint))
    return big(#data) .. kind .. data .. big(checksum)
end

function Png.encode(width, height, raw, checkpoint)
    assert(width > 0 and height > 0 and buffer.len(raw) == (width * 4 + 1) * height, "Invalid PNG dimensions")
    local data = buffer.tostring(raw)
    local blocks = { string.char(0x78, 0x01) }
    local a, b = 1, 0
    for first = 1, #data, 5552 do
        for index = first, math.min(#data, first + 5551) do
            a += string.byte(data, index)
            b += a
        end
        a, b = a % 65521, b % 65521
        if checkpoint then
            checkpoint()
        end
    end
    for first = 1, #data, 65535 do
        local length = math.min(65535, #data - first + 1)
        local inverse = 65535 - length
        blocks[#blocks + 1] = string.char(
            first + length > #data and 1 or 0,
            length % 256,
            math.floor(length / 256),
            inverse % 256,
            math.floor(inverse / 256)
        ) .. string.sub(data, first, first + length - 1)
        if checkpoint then
            checkpoint()
        end
    end
    blocks[#blocks + 1] = big(b * 65536 + a)
    local header = big(width) .. big(height) .. string.char(8, 6, 0, 0, 0)
    return "\137PNG\13\10\26\10"
        .. chunk("IHDR", header)
        .. chunk("IDAT", table.concat(blocks), checkpoint)
        .. chunk("IEND", "")
end

return Png
