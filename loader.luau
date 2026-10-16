-- Always fetch the newest published Kinoue release. No service credentials live here.
local sourceOk, source = pcall(function()
    return game:HttpGet("https://github.com/Proxo123/Kinoue-Lib/releases/latest/download/Kinoue.lua", true)
end)
assert(
    sourceOk and type(source) == "string" and #source > 0 and #source <= 2097152,
    "[Kinoue] Latest release could not be downloaded"
)
local chunk = loadstring(source, "KinoueLatest")
assert(type(chunk) == "function", "[Kinoue] Latest release is not valid Luau")
local loaded, library = pcall(chunk)
assert(
    loaded
        and type(library) == "table"
        and type(library.Version) == "string"
        and type(library.CreateWindow) == "function"
        and type(library.CreateKeySystem) == "function",
    "[Kinoue] Latest release is invalid"
)
return library
