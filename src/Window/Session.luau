local RunService = game:GetService("RunService")

local Session = {}

local function remaining(info)
    if not info.Known then
        return "Time left: Unavailable"
    end
    if info.ExpiresAt == nil then
        return "Time left: No expiry"
    end
    local seconds = math.max(0, math.ceil(info.ExpiresAt - (os.time() + info.Offset)))
    if seconds == 0 then
        return "Time left: Expired"
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds / 3600) % 24
    local minutes = math.floor(seconds / 60) % 60
    local parts = {}
    if days > 0 then
        table.insert(parts, days .. "d")
    end
    if days > 0 or hours > 0 then
        table.insert(parts, hours .. "h")
    end
    table.insert(parts, minutes .. "m")
    table.insert(parts, seconds % 60 .. "s")
    return "Time left: " .. table.concat(parts, " ")
end

function Session.set(window, info)
    if window.Dead then
        return window
    end
    if window.SessionTick then
        window.Scope:Release(window.SessionTick)
        window.SessionTick = nil
    end
    if not info then
        if window.SessionTime then
            window.SessionTime:SetVisible(false)
        end
        window.SessionInfo = nil
        return window
    end
    assert(type(info) == "table", "SetSessionInfo requires a table")
    local expires = info.ExpiresAt
    assert(
        expires == nil or type(expires) == "number" and expires == expires and math.abs(expires) < math.huge,
        "ExpiresAt must be a finite Unix timestamp"
    )
    local serverTime = info.ServerTime
    assert(
        serverTime == nil
            or type(serverTime) == "number" and serverTime == serverTime and math.abs(serverTime) < math.huge,
        "ServerTime must be a finite Unix timestamp"
    )
    window.SessionInfo = {
        Known = info.Known ~= false,
        ExpiresAt = expires,
        Offset = serverTime and serverTime - os.time() or 0,
    }
    if not window.SessionTime then
        local page
        for _, candidate in ipairs(window.Pages) do
            if candidate.Name == "Session" then
                page = candidate
                break
            end
        end
        page = page or window:AddTab("Session")
        window.SessionPage = page
        window.SessionGroup = page:AddGroupbox("License", "Left")
        window.SessionTime = window.SessionGroup:AddLabel("")
    end
    window.SessionTime:SetVisible(true)
    local previous
    local function render()
        local text = remaining(window.SessionInfo)
        if text ~= previous then
            previous = text
            window.SessionTime:SetText(text)
        end
    end
    render()
    if expires then
        local elapsed = 0
        window.SessionTick = window.Scope:Connect(RunService.Heartbeat, function(delta)
            elapsed += delta
            if elapsed >= 1 then
                elapsed %= 1
                if window.Open and window.ActivePage == window.SessionPage then
                    render()
                end
            end
        end)
    end
    return window
end

return Session
