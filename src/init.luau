local Theme = require(script.internal.Theme)
local Util = require(script.internal.Util)
local Window = require(script.Window)
local KeySystem = require(script.KeySystem)

local Library = {
    Version = "0.8.0",
    Theme = Theme,
    Themes = Theme.PresetNames,
}

function Library:CreateWindow(options)
    return Window.new(options or {}, Library.Version)
end

function Library:CreateKeySystem(options)
    return Util.withContext(KeySystem.new, self, options)
end

function Library:SetTheme(theme)
    Util.withContext(Theme.apply, theme)
end

function Library:GetTheme()
    return Theme.Preset
end

function Library.FileStorage(path)
    assert(
        type(readfile) == "function" and type(writefile) == "function",
        "File APIs unavailable; supply your own Read/Write adapter"
    )

    local function read()
        if isfile and not isfile(path) then
            return nil
        end
        return readfile(path)
    end

    local function write(json)
        local folder = path:match("^(.*)/[^/]+$")
        if folder and makefolder and (not isfolder or not isfolder(folder)) then
            makefolder(folder)
        end
        writefile(path, json)
    end

    return { Read = read, Write = write }
end

return Library
