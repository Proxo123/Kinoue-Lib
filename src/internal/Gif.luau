local Gif = {}
local band, shift, left, bor = bit32.band, bit32.rshift, bit32.lshift, bit32.bor

function Gif.parse(data, checkpoint)
    assert(
        type(data) == "string" and #data >= 13 and (data:sub(1, 6) == "GIF89a" or data:sub(1, 6) == "GIF87a"),
        "Invalid GIF header"
    )
    assert(#data <= 32 * 1024 * 1024, "GIF exceeds the 32 MB file limit")
    local at = 7
    local function byte()
        assert(at <= #data, "Truncated GIF")
        local value = string.byte(data, at)
        at += 1
        return value
    end
    local function word()
        local low = byte()
        return low + byte() * 256
    end
    local function palette(size)
        local colors = table.create(size)
        for index = 1, size do
            local r, g, b = byte(), byte(), byte()
            colors[index] = r + g * 256 + b * 65536 + 0xFF000000
        end
        return colors
    end
    local function blocks()
        local values = {}
        while true do
            local size = byte()
            if size == 0 then
                break
            end
            assert(at + size - 1 <= #data, "Truncated GIF block")
            values[#values + 1] = data:sub(at, at + size - 1)
            at += size
        end
        if checkpoint then
            checkpoint()
        end
        return table.concat(values)
    end
    local width, height = word(), word()
    assert(width > 0 and height > 0 and width * height <= 4194304, "GIF canvas exceeds 4 million pixels")
    local packed, background = byte(), byte()
    byte()
    local global = band(packed, 128) ~= 0 and palette(2 ^ (band(packed, 7) + 1)) or nil
    local result = {
        Width = width,
        Height = height,
        Frames = {},
        Background = global and global[background + 1] or 0,
        Duration = 0,
    }
    local control = {}
    local work = 0
    while at <= #data do
        local marker = byte()
        if marker == 0x3B then
            break
        end
        if marker == 0x21 then
            local label = byte()
            if label == 0xF9 then
                assert(byte() == 4, "Invalid GIF control block")
                local flags, delay = byte(), word()
                local transparent = byte()
                assert(byte() == 0, "Invalid GIF control terminator")
                control = {
                    Disposal = band(shift(flags, 2), 7),
                    Transparent = band(flags, 1) ~= 0 and transparent or nil,
                    Delay = delay <= 1 and 0.1 or delay / 100,
                }
            else
                blocks()
                if label == 0x01 then
                    control = {}
                end
            end
        elseif marker == 0x2C then
            local frame = {
                Left = word(),
                Top = word(),
                Width = word(),
                Height = word(),
                Disposal = control.Disposal or 0,
                Transparent = control.Transparent,
                Delay = control.Delay or 0.1,
            }
            assert(
                frame.Width > 0 and frame.Height > 0 and frame.Width * frame.Height <= 4194304,
                "Invalid GIF frame dimensions"
            )
            work += frame.Width * frame.Height
            assert(work <= 200000000, "GIF exceeds the decoding work limit")
            local flags = byte()
            frame.Interlaced = band(flags, 64) ~= 0
            frame.Palette = band(flags, 128) ~= 0 and palette(2 ^ (band(flags, 7) + 1)) or global
            assert(frame.Palette, "GIF has no color table")
            frame.CodeSize = byte()
            assert(frame.CodeSize >= 1 and frame.CodeSize <= 8, "Invalid GIF LZW code size")
            frame.Data = blocks()
            result.Duration += frame.Delay
            frame.End = result.Duration
            result.Frames[#result.Frames + 1] = frame
            assert(#result.Frames <= 300, "GIF exceeds the 300 frame limit")
            control = {}
        else
            error("Invalid GIF block")
        end
    end
    assert(#result.Frames > 0, "GIF contains no frames")
    return result
end

local function decompress(frame, checkpoint)
    local data, at, bits, value = frame.Data, 1, 0, 0
    local size = frame.CodeSize + 1
    local clear = 2 ^ frame.CodeSize
    local ending, available = clear + 1, clear + 2
    local prefix, suffix = table.create(4096), table.create(4096)
    local stack, output = buffer.create(4097), buffer.create(frame.Width * frame.Height)
    local used, previous, first = 0, nil, nil
    local count = frame.Width * frame.Height
    local operations, lastYield = 0, 0
    local function code()
        while bits < size do
            if at > #data then
                return nil
            end
            value = bor(value, left(string.byte(data, at), bits))
            bits += 8
            at += 1
        end
        local result = band(value, 2 ^ size - 1)
        value = shift(value, size)
        bits -= size
        return result
    end
    while true do
        local current = code()
        if current == nil then
            assert(used == count, "Truncated GIF pixels")
            break
        end
        if current == ending then
            break
        end
        if current == clear then
            size, available, previous = frame.CodeSize + 1, clear + 2, nil
        elseif previous == nil then
            assert(current < clear and used < count, "Invalid GIF LZW stream")
            buffer.writeu8(output, used, current)
            used += 1
            previous, first = current, current
        else
            local original, length = current, 0
            if current == available then
                buffer.writeu8(stack, length, first)
                length += 1
                current = previous
            else
                assert(current < available, "Invalid GIF LZW code")
            end
            while current >= clear do
                assert(prefix[current] ~= nil and length < 4096, "Invalid GIF LZW dictionary")
                buffer.writeu8(stack, length, suffix[current])
                length += 1
                current = prefix[current]
            end
            first = current
            buffer.writeu8(stack, length, current)
            length += 1
            assert(used + length <= count, "GIF pixels exceed frame bounds")
            for index = length - 1, 0, -1 do
                buffer.writeu8(output, used, buffer.readu8(stack, index))
                used += 1
            end
            if available < 4096 then
                prefix[available], suffix[available] = previous, first
                available += 1
                if available == 2 ^ size and size < 12 then
                    size += 1
                end
            end
            previous = original
        end
        operations += 1
        if checkpoint and (operations % 2048 == 0 or used - lastYield >= 8192) then
            checkpoint()
            lastYield = used
        end
    end
    assert(used == count, "GIF frame has incomplete pixels")
    return output
end

function Gif.render(gif, width, height, emit, checkpoint)
    assert(width > 0 and height > 0 and width <= gif.Width and height <= gif.Height, "Invalid GIF output dimensions")
    local canvas = buffer.create(width * height * 4)
    local background = gif.Frames[1].Transparent ~= nil and 0 or gif.Background
    if background ~= 0 then
        for index = 0, width * height - 1 do
            buffer.writeu32(canvas, index * 4, background)
        end
    end
    local saved, previous
    local function bounds(frame)
        return math.max(0, math.ceil(frame.Left * width / gif.Width)),
            math.max(0, math.ceil(frame.Top * height / gif.Height)),
            math.min(width - 1, math.ceil((frame.Left + frame.Width) * width / gif.Width) - 1),
            math.min(height - 1, math.ceil((frame.Top + frame.Height) * height / gif.Height) - 1)
    end
    for index, frame in ipairs(gif.Frames) do
        if previous and previous.Disposal == 2 then
            local x0, y0, x1, y1 = bounds(previous)
            local color = previous.Transparent ~= nil and 0 or gif.Background
            for y = y0, y1 do
                for x = x0, x1 do
                    buffer.writeu32(canvas, (y * width + x) * 4, color)
                end
                if y % 16 == 0 and checkpoint then
                    checkpoint()
                end
            end
        elseif previous and previous.Disposal == 3 then
            buffer.copy(canvas, 0, saved)
        end
        if frame.Disposal == 3 then
            saved = saved or buffer.create(buffer.len(canvas))
            buffer.copy(saved, 0, canvas)
        end
        local pixels = decompress(frame, checkpoint)
        local rows = {}
        if frame.Interlaced then
            local row = 0
            for _, pass in ipairs({ { 0, 8 }, { 4, 8 }, { 2, 4 }, { 1, 2 } }) do
                for y = pass[1], frame.Height - 1, pass[2] do
                    rows[y] = row
                    row += 1
                end
            end
        end
        local x0, y0, x1, y1 = bounds(frame)
        for y = y0, y1 do
            local sourceY = math.floor(y * gif.Height / height) - frame.Top
            local row = frame.Interlaced and rows[sourceY] or sourceY
            for x = x0, x1 do
                local sourceX = math.floor(x * gif.Width / width) - frame.Left
                local color = buffer.readu8(pixels, row * frame.Width + sourceX)
                if color ~= frame.Transparent then
                    buffer.writeu32(
                        canvas,
                        (y * width + x) * 4,
                        assert(frame.Palette[color + 1], "Invalid GIF palette index")
                    )
                end
            end
            if y % 16 == 0 and checkpoint then
                checkpoint()
            end
        end
        emit(canvas, index)
        previous = frame
        if checkpoint then
            checkpoint()
        end
    end
end

return Gif
