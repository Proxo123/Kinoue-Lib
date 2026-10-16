local env, http = Mock.Environment, Mock.Environment.game:GetService("HttpService")
local encoded, sequence = {}, 0
local guidSequence = 0
function http:GenerateGUID()
    guidSequence += 1
    return string.format("%08x-0000-4000-8000-%012x", guidSequence, guidSequence)
end
local player = env.game:GetService("Players").LocalPlayer
player.UserId, player.Name, player.DisplayName = 1234567, "Test_Player", "Test Player"
env.game.PlaceId = 987654
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
    if options.Url:match("/executions$") then
        return { StatusCode = 200, Body = http:JSONEncode({ ok = true }) }
    end
    if options.Url:match("/script$") then
        return { StatusCode = 200, Body = 'return "protected-payload"' }
    end
    return {
        StatusCode = 200,
        Body = http:JSONEncode({
            token = token,
            expires_at = os.time() + 600,
            license_expires_at = os.time() + 172800,
            server_time = os.time(),
        }),
    }
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
assert(gate.ForgetButton == nil)
local fields, buttons = 0, 0
for _, child in ipairs(gate.Window.Screen:GetDescendants()) do
    if child:IsA("TextBox") then
        fields += 1
    elseif child:IsA("TextButton") then
        buttons += 1
        assert(child.Text == "Redeem" or child.Text == "Close", "The key dialog has only its two actions")
    elseif child:IsA("TextLabel") then
        assert(not child.Visible, "The resting key dialog has no labels or window chrome")
    end
end
assert(fields == 1 and buttons == 2, "The key dialog contains only a key input, Redeem, and Close")
assert(gate.Window.Root.AbsoluteSize.X == 360 and gate.Window.Root.AbsoluteSize.Y == 112)
assert(gate.Remember == nil and gate.Window.SettingsPage == nil and gate.Window.Pages == nil)
assert(gate.Supported and not gate.Busy and #requests == 0)
assert(not gate:Redeem("short") and #requests == 0)
assert(gate.Window.Status.Visible and gate.Window.Root.AbsoluteSize.Y == 152)
gate:Forget()
assert(not gate.Window.Status.Visible and gate.Window.Root.AbsoluteSize.Y == 112)
gate.Key.Root.Text = string.rep("a", 300)
assert(#gate.Key.Root.Text == 256, "Pasted keys are bounded to the API limit")
gate.Key.Root.Text = key
gate.Key.Root.FocusLost:Fire(true)
assert(gate.Busy and not gate:Redeem(key), "Enter submits and concurrent redemption is suppressed")
assert(not gate.Key.Enabled and not gate.RedeemButton.Enabled and gate.CloseButton.Enabled)
Mock:Advance(0)
Mock:Advance(0)
assert(gate.Loaded and gate.Result == "protected-payload" and gate.Window.Dead)
assert(#requests == 3 and gate.ExecutionReported)
local execution = http:JSONDecode(requests[3].Body)
assert(
    requests[3].Url:match("/executions$") and execution.user_id == player.UserId and execution.username == player.Name
)
assert(execution.display_name == player.DisplayName and execution.place_id == env.game.PlaceId and execution.key == nil)
local body = http:JSONDecode(requests[1].Body)
assert(body.application == "king" and body.hwid == "test-device" and body.key == key)
local cache = http:JSONDecode(files[gate.CachePath])
assert(cache.Token == token and cache.Key == nil and cache.Hwid == nil and cache.Endpoint == endpoint)
assert(gate.Remembered)
local old = gate
gate = create()
Mock:Advance(0)
assert(gate.Loaded and requests[4].Url:match("/session$"), "Saved sessions must be revalidated before loading")
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
gate.Key.Root.Text = key
gate.RedeemButton.Root.Activated:Fire()
Mock:Advance(0)
assert(gate.Loaded and not files[gate.CachePath], "Redeem works without saving a session")
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
gate.CloseButton.Root.Activated:Fire()
assert(gate.Dead and gate.Window.Dead, "Close destroys the dialog and key controller while busy")
Mock:Advance(0)
assert(#requests == count, "Closing must cancel deferred verification")
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
files = { ["King/settings.json"] = "preserved-settings" }
local unloaded = 0
local originalLoader = env.loadstring
env.loadstring = function(source)
    local compiled, message = loadstring(source)
    if compiled then
        setfenv(compiled, env)
    end
    return compiled, message
end
env.createLogoutPayload = function()
    local window = UI:CreateWindow({ Name = "Protected", ReducedMotion = true })
    return {
        Window = window,
        Destroy = function()
            unloaded += 1
            window:Destroy()
        end,
    }
end
response = function(options)
    if options.Url:match("/script$") then
        return { StatusCode = 200, Body = "return createLogoutPayload()" }
    end
    return success(options)
end
gate = create()
assert(gate:Redeem(key))
Mock:Advance(0)
assert(gate.Loaded and gate.SessionWindow == gate.Result.Window)
local loadedWindow = gate.Result.Window
assert(loadedWindow.SessionPage.Name == "Session" and loadedWindow.SessionTime.Root.Text:find("Time left:", 1, true))
assert(loadedWindow.SessionInfo.ExpiresAt == gate.LicenseExpiresAt and gate.LicenseExpiresAt > os.time() + 86400)
local logout = loadedWindow.SettingsPage.Controls.Logout
assert(logout and logout.Root.Text == "Logout")
loadedWindow:OpenSettings()
logout.Root.Activated:Fire()
assert(not files[gate.CachePath] and not gate.Remembered and not gate:Logout())
Mock:Advance(0)
assert(unloaded == 1 and loadedWindow.Dead and not gate.Loaded and gate.Result == nil)
assert(gate.State == "ready" and not gate.Window.Dead and not gate.Busy and not gate.Token)
assert(gate.Window.Root.Name == "KeyDialog" and gate.Key.Root.Text == "" and not gate.Window.Status.Visible)
assert(files["King/settings.json"] == "preserved-settings")
local logoutRequest
for _, request in ipairs(requests) do
    if request.Url:match("/logout$") then
        logoutRequest = request
    end
end
assert(logoutRequest and http:JSONDecode(logoutRequest.Body).token == token)
assert(gate:Redeem(key))
Mock:Advance(0)
assert(gate.Loaded and gate.Result.Window ~= loadedWindow and gate.Result.Window.SettingsPage.Controls.Logout)
assert(gate:Logout())
Mock:Advance(0)
assert(unloaded == 2 and gate.State == "ready" and not gate.Loaded)
gate:Destroy()
gate = create({ Remember = false })
gate.Key.Root:CaptureFocus()
Mock.Input.InputBegan:Fire({ KeyCode = Mock.Enum.KeyCode.Escape })
assert(gate.Dead and gate.Window.Dead and Mock.Input.Focused == nil, "Escape closes and releases focus")
local oldGate = create({ Remember = false })
oldGate:Redeem(key)
count = #requests
gate = create({ Remember = false })
Mock:Advance(0)
assert(oldGate.Dead and oldGate.Window.Dead and #requests == count, "Replacement cancels the old key dialog")
gate:Destroy()
env.createLogoutPayload = nil

response = function(options)
    if options.Url:match("/script$") then
        return {
            StatusCode = 200,
            Body = [[
            local context = ...
            assert(type(context) == "table" and type(context.Library) == "table")
            local fields = 0
            for name in pairs(context) do
                fields += 1
                assert(name == "Library", "Protected payload context must not contain credentials")
            end
            assert(fields == 1)
            return context.Library
        ]],
        }
    end
    return success(options)
end
gate = create({ Remember = false })
assert(gate:Redeem(key))
Mock:Advance(0)
assert(gate.Loaded and gate.Result == UI, "Payload must receive the exact authenticated library instance")
gate:Destroy()
env.loadstring = originalLoader
Mock:Advance(30)
assert(Mock:ConnectionCount() == 0, "Key windows must release every UI signal")
print(
    "PASS: compact key dialog, Enter/Redeem, Close/Escape cancellation, replacement cleanup, remembered sessions, logout/re-login, device checks and failures"
)
