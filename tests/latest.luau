local env = Mock.Environment
local downloaded, revision = 0, 1
local fail, malformed = false, false
local first = { Version = "0.10.3", CreateWindow = function() end, CreateKeySystem = function() end }
local second = { Version = "0.10.4", CreateWindow = function() end, CreateKeySystem = function() end }
env.game.HttpGet = function(_, url, fresh)
    assert(url == "https://github.com/Proxo123/Kinoue-Lib/releases/latest/download/Kinoue.lua" and fresh == true)
    downloaded += 1
    if fail then
        error("internal request details must not leak")
    end
    return malformed and "bad-source" or "release-" .. revision
end
env.loadstring = function(source)
    if source == "bad-source" then
        return nil, "internal compiler details"
    end
    return function()
        return revision == 1 and first or second
    end
end
setfenv(bootstrap, env)
assert(bootstrap() == first)
revision = 2
assert(bootstrap() == second and downloaded == 2, "Bootstrap must fetch a fresh release for each execution")
fail = true
local ok, message = pcall(bootstrap)
assert(not ok and not tostring(message):find("internal request details", 1, true))
fail, malformed = false, true
assert(not pcall(bootstrap), "Do not reuse an older release after compilation failure")
print("PASS: latest-release bootstrap, cache bypass, fresh library each run, sanitized failures, no stale fallback")
