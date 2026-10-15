local env, http = Mock.Environment, Mock.Environment.game:GetService("HttpService")
local encoded, sequence = {}, 0
function http:JSONEncode(value)
    sequence += 1
    local key = "json:" .. sequence
    encoded[key] = value
    return key
end
function http:JSONDecode(value)
    return assert(encoded[value], "Invalid JSON")
end
local files, requests = {}, {}
env.gethwid = function()
    return "test-device"
end
env.get_hwid = nil
env.makefolder = function() end
env.isfolder = function()
    return true
end
env.readfile = function(path)
    return assert(files[path], "Missing cache")
end
env.writefile = function(path, value)
    files[path] = value
end
env.delfile = function(path)
    files[path] = nil
end
env.warn = function() end
local response
env.request = function(options)
    requests[#requests + 1] = options
    return response(options)
end
local token = string.rep("s", 43)
local key = "KING-" .. string.rep("a", 32)
local endpoint = "https://keys.example.test"
local function success(options)
    if options.Url:match("/script$") then
        return { StatusCode = 200, Body = 'return "protected-payload"' }
    end
    return { StatusCode = 200, Body = http:JSONEncode({ token = token, expires_at = os.time() + 600 }) }
end
response = success
local function create(extra)
    local options = { Name = "King", Application = "king", Endpoint = endpoint }
    for name, value in pairs(extra or {}) do
        options[name] = value
    end
    return UI:CreateKeySystem(options)
end
local gate = create()
Mock:Advance(1)
assert(gate.Supported and not gate.Busy and #requests == 0)
assert(not gate:Redeem("short") and #requests == 0)
assert(gate:Redeem(key) and not gate:Redeem(key), "Concurrent redemption must be suppressed")
Mock:Advance(0)
assert(gate.Loaded and gate.Result == "protected-payload" and gate.Window.Dead)
assert(#requests == 2)
local body = http:JSONDecode(requests[1].Body)
assert(body.application == "king" and body.hwid == "test-device" and body.key == key)
local cache = http:JSONDecode(files[gate.CachePath])
assert(cache.Token == token and cache.Key == nil and cache.Hwid == nil and cache.Endpoint == endpoint)
assert(gate.Remembered)
local old = gate
gate = create()
Mock:Advance(0)
assert(gate.Loaded and requests[3].Url:match("/session$"), "Saved sessions must be revalidated before loading")
old:Destroy()
gate:Destroy()
files = {}
response = function()
    return { StatusCode = 403, Body = http:JSONEncode({ error = "hwid_mismatch" }) }
end
gate = create()
gate:Redeem(key)
Mock:Advance(0)
assert(gate.State == "error" and gate.Error == "hwid_mismatch" and not gate.Loaded and not gate.Busy)
assert(gate.Window.Status.Text == "Key is bound to another device.")
assert(not files[gate.CachePath])
gate:Destroy()
local count = #requests
env.gethwid = nil
gate = create()
Mock:Advance(0)
assert(not gate.Supported and gate.Error == "unsupported_executor" and not gate:Redeem(key))
assert(
    not gate.RedeemButton.Enabled and #requests == count,
    "Unsupported HWID must never contact the server or load a script"
)
gate:Destroy()
env.get_hwid = function()
    return "alias-device"
end
response = success
gate = create({ Remember = false })
gate:Redeem(key)
Mock:Advance(0)
assert(gate.Loaded and not files[gate.CachePath])
gate:Destroy()
env.get_hwid = nil
env.gethwid = function()
    return "test-device"
end
response = function(options)
    if options.Url:match("/script$") then
        return { StatusCode = 200, Body = "not valid lua !" }
    end
    return success(options)
end
gate = create({ Remember = false })
gate:Redeem(key)
Mock:Advance(0)
assert(not gate.Loaded and gate.Error == "script_failed")
gate:Destroy()
response = function()
    return { StatusCode = 200, Body = "not-json" }
end
gate = create({ Remember = false })
gate:Redeem(key)
Mock:Advance(0)
assert(gate.Error == "invalid_response" and not gate.Loaded)
gate:Destroy()
response = success
gate = create({ Remember = false })
gate:Redeem(key)
count = #requests
gate:Destroy()
Mock:Advance(0)
assert(#requests == count, "Destroyed gates must cancel deferred verification")
files["Kinoue/keys/king.json"] = http:JSONEncode({
    Version = 1,
    Application = "king",
    Endpoint = endpoint,
    Token = token,
    ExpiresAt = os.time() + 600,
})
response = function()
    return { StatusCode = 503, Body = http:JSONEncode({ error = "unavailable" }) }
end
gate = create()
Mock:Advance(0)
assert(
    not gate.Loaded and files[gate.CachePath],
    "Network failure must preserve the remembered login without running code"
)
gate:Destroy()
response = function()
    return { StatusCode = 403, Body = http:JSONEncode({ error = "license_revoked" }) }
end
gate = create()
Mock:Advance(0)
assert(not gate.Loaded and not files[gate.CachePath], "Revoked cached logins must be removed and never load payloads")
gate:Destroy()
assert(not pcall(create, { Endpoint = "http://public.example.test" }))
assert(not pcall(create, { Endpoint = "http://127.0.0.1.attacker.test:8000", AllowLocalhost = true }))
assert(not pcall(create, { CachePath = "../auth.json" }))
gate = create({ Endpoint = "http://127.0.0.1:8765", AllowLocalhost = true, Remember = false })
gate:Destroy()
Mock:Advance(30)
assert(Mock:ConnectionCount() == 0, "Key windows must release every UI signal")
print(
    "PASS: key redemption, device checks, saved-session validation, no cached raw key/HWID, unsupported executors, failures and cleanup"
)
