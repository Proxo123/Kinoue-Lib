local HttpService = game:GetService("HttpService")
local Gif = require(script.Parent.Gif)
local Png = require(script.Parent.Png)

local Media = {}
local ROOT = "Kinoue/backgrounds"
local VERSION = 1
local PIXELS = 8388608

local function dimensions(data, png)
    local function word(at)
        assert(at + 1 <= #data, "Truncated image header")
        return string.byte(data, at) * 256 + string.byte(data, at + 1)
    end
    local width, height
    if png then
        assert(#data >= 33 and data:sub(13, 16) == "IHDR", "Invalid PNG header")
        width, height = word(17) * 65536 + word(19), word(21) * 65536 + word(23)
    else
        local at = 3
        while at <= #data do
            assert(string.byte(data, at) == 255, "Invalid JPEG header")
            while string.byte(data, at) == 255 do
                at += 1
            end
            local marker = string.byte(data, at)
            at += 1
            assert(marker and marker ~= 0xDA and marker ~= 0xD9, "JPEG has no dimensions")
            if marker ~= 0x01 and (marker < 0xD0 or marker > 0xD7) then
                local size = word(at)
                assert(size >= 2 and at + size - 1 <= #data, "Truncated JPEG segment")
                if marker >= 0xC0 and marker <= 0xCF and marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
                    assert(size >= 8, "Invalid JPEG frame")
                    height, width = word(at + 3), word(at + 5)
                    break
                end
                at += size
            end
        end
    end
    assert(
        width and height and width > 0 and height > 0 and width <= 4096 and height <= 4096,
        "Background images must be at most 4096 pixels per side"
    )
    return width, height
end

local function folder(path)
    if type(isfolder) == "function" and isfolder(path) then
        return
    end
    local ok, message = pcall(makefolder, path)
    if not ok and type(isfolder) == "function" and not isfolder(path) then
        error(message)
    end
end

local function valid(meta)
    if
        type(meta) ~= "table"
        or meta.Version ~= VERSION
        or type(meta.Frames) ~= "table"
        or type(meta.Pages) ~= "table"
    then
        return false
    end
    if
        type(meta.Width) ~= "number"
        or meta.Width < 1
        or meta.Width > 512
        or meta.Width % 1 ~= 0
        or type(meta.Height) ~= "number"
        or meta.Height < 1
        or meta.Height > 512
        or meta.Height % 1 ~= 0
    then
        return false
    end
    if
        #meta.Frames < 1
        or #meta.Frames > 300
        or #meta.Pages < 1
        or #meta.Pages > 32
        or meta.Width * meta.Height * #meta.Frames > PIXELS
    then
        return false
    end
    local previous = 0
    for _, page in ipairs(meta.Pages) do
        if
            type(page) ~= "table"
            or type(page.Width) ~= "number"
            or page.Width < 1
            or page.Width > 1024
            or page.Width % 1 ~= 0
            or type(page.Height) ~= "number"
            or page.Height < 1
            or page.Height > 1024
            or page.Height % 1 ~= 0
        then
            return false
        end
    end
    for _, frame in ipairs(meta.Frames) do
        if
            type(frame) ~= "table"
            or type(frame.Page) ~= "number"
            or frame.Page % 1 ~= 0
            or not meta.Pages[frame.Page]
            or type(frame.X) ~= "number"
            or type(frame.Y) ~= "number"
            or frame.X < 0
            or frame.Y < 0
            or frame.X % 1 ~= 0
            or frame.Y % 1 ~= 0
            or frame.X + meta.Width > meta.Pages[frame.Page].Width
            or frame.Y + meta.Height > meta.Pages[frame.Page].Height
            or type(frame.End) ~= "number"
            or frame.End ~= frame.End
            or frame.End <= previous
            or frame.End > 200000
        then
            return false
        end
        previous = frame.End
    end
    return true
end

local function register(meta, directory, asset, checkpoint)
    local images = {}
    for index in ipairs(meta.Pages) do
        if checkpoint then
            checkpoint()
        end
        local path = directory .. "/" .. index .. ".png"
        assert(type(isfile) ~= "function" or isfile(path), "Cached GIF page missing")
        images[index] = asset(path)
        assert(type(images[index]) == "string" and images[index] ~= "", "Executor did not register the GIF page")
    end
    local frames = {}
    for _, frame in ipairs(meta.Frames) do
        frames[#frames + 1] = {
            Image = images[frame.Page],
            X = frame.X,
            Y = frame.Y,
            Width = meta.Width,
            Height = meta.Height,
            End = frame.End,
        }
    end
    return {
        Kind = "GIF",
        Width = meta.Width,
        Height = meta.Height,
        Frames = frames,
        Pages = images,
        Duration = frames[#frames].End,
    }
end

function Media.load(path, checkpoint)
    local asset = type(getcustomasset) == "function" and getcustomasset or getsynasset
    assert(
        type(readfile) == "function" and type(asset) == "function",
        "Local backgrounds require executor readfile and getcustomasset functions"
    )
    assert(type(path) == "string" and path ~= "" and not path:find("%z"), "Enter a local image or GIF path")
    local read, data = pcall(readfile, path)
    assert(
        read and type(data) == "string",
        "Executor could not read this file. Use a path accessible to its workspace."
    )
    assert(#data > 0 and #data <= 33554432, "Background file must be between 1 byte and 32 MB")
    if checkpoint then
        checkpoint()
    end
    local gif = data:sub(1, 6) == "GIF89a" or data:sub(1, 6) == "GIF87a"
    local png = data:sub(1, 8) == "\137PNG\13\10\26\10"
    local jpeg = data:sub(1, 3) == "\255\216\255"
    assert(gif or png or jpeg, "Choose a PNG, JPEG, or GIF file")
    if not gif then
        local width, height = dimensions(data, png)
        local image
        if type(writefile) == "function" and type(makefolder) == "function" then
            folder("Kinoue")
            folder(ROOT)
            local cached = ROOT .. "/image-" .. Png.hash(data, checkpoint) .. (png and ".png" or ".jpg")
            if type(isfile) ~= "function" or not isfile(cached) then
                writefile(cached, data)
            end
            image = asset(cached)
        else
            image = asset(path)
        end
        assert(type(image) == "string" and image ~= "", "Executor did not register the image")
        return {
            Kind = "Image",
            Width = width,
            Height = height,
            Pages = { image },
            Frames = { { Image = image, X = 0, Y = 0, Width = 0, Height = 0, End = 0 } },
            Duration = 0,
        }
    end
    assert(
        type(writefile) == "function" and type(makefolder) == "function",
        "GIF backgrounds require executor writefile and makefolder functions"
    )
    folder("Kinoue")
    folder(ROOT)
    local directory = ROOT .. "/gif" .. VERSION .. "-" .. Png.hash(data, checkpoint)
    folder(directory)
    local manifest = directory .. "/frames.json"
    local cached, meta = pcall(function()
        local value = HttpService:JSONDecode(readfile(manifest))
        assert(valid(value), "Invalid GIF cache")
        return value
    end)
    if cached then
        local loaded, result = pcall(register, meta, directory, asset, checkpoint)
        if loaded then
            result.Cached = true
            return result
        end
        if checkpoint then
            checkpoint()
        end
    end
    local source = Gif.parse(data, checkpoint)
    local scale = math.min(
        1,
        512 / source.Width,
        512 / source.Height,
        math.sqrt(PIXELS / (#source.Frames * source.Width * source.Height))
    )
    local width, height = math.max(1, math.floor(source.Width * scale)), math.max(1, math.floor(source.Height * scale))
    local cellWidth, cellHeight = width + 2, height + 2
    local columns, rows = math.floor(1024 / cellWidth), math.floor(1024 / cellHeight)
    local perPage = columns * rows
    meta = { Version = VERSION, Width = width, Height = height, Pages = {}, Frames = {} }
    local raw, pageWidth, pageHeight, stride, page
    Gif.render(source, width, height, function(canvas, index)
        local slot = (index - 1) % perPage
        if slot == 0 then
            page = #meta.Pages + 1
            local remaining = math.min(perPage, #source.Frames - index + 1)
            pageWidth = math.min(columns, remaining) * cellWidth
            pageHeight = math.ceil(remaining / columns) * cellHeight
            stride = pageWidth * 4 + 1
            raw = buffer.create(stride * pageHeight)
            meta.Pages[page] = { Width = pageWidth, Height = pageHeight }
        end
        local x, y = slot % columns * cellWidth, math.floor(slot / columns) * cellHeight
        for row = 0, height - 1 do
            local destination = (y + row + 1) * stride + (x + 1) * 4 + 1
            buffer.copy(raw, destination, canvas, row * width * 4, width * 4)
            buffer.copy(raw, destination - 4, canvas, row * width * 4, 4)
            buffer.copy(raw, destination + width * 4, canvas, (row * width + width - 1) * 4, 4)
        end
        buffer.copy(raw, y * stride + x * 4 + 1, raw, (y + 1) * stride + x * 4 + 1, cellWidth * 4)
        buffer.copy(raw, (y + height + 1) * stride + x * 4 + 1, raw, (y + height) * stride + x * 4 + 1, cellWidth * 4)
        meta.Frames[index] = { Page = page, X = x + 1, Y = y + 1, End = source.Frames[index].End }
        if slot == perPage - 1 or index == #source.Frames then
            local encoded = Png.encode(pageWidth, pageHeight, raw, checkpoint)
            if checkpoint then
                checkpoint()
            end
            writefile(directory .. "/" .. page .. ".png", encoded)
            raw = nil
        end
    end, checkpoint)
    if checkpoint then
        checkpoint()
    end
    writefile(manifest, HttpService:JSONEncode(meta))
    return register(meta, directory, asset, checkpoint)
end

return Media
