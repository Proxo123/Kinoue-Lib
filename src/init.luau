local Window = require(script.Window)
local Library = { Version = "0.1.12", Theme = require(script.internal.Theme) }
function Library:CreateWindow(options) return Window.new(options or {}) end
function Library.FileStorage(path)
    assert(type(readfile) == "function" and type(writefile) == "function", "File APIs unavailable; supply your own Read/Write adapter")
    return {
        Read = function() if isfile and not isfile(path) then return nil end return readfile(path) end,
        Write = function(json)
            local folder = path:match("^(.*)/[^/]+$")
            if folder and makefolder and (not isfolder or not isfolder(folder)) then makefolder(folder) end
            writefile(path, json)
        end,
    }
end
return Library
