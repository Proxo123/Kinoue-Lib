local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local KeyDialog = require(script.Parent.internal.KeyDialog)
local Util = require(script.Parent.internal.Util)

local KeySystem = {}
KeySystem.__index = KeySystem

local MESSAGES = {
    invalid_credentials = "Invalid key or saved login.",
    hwid_mismatch = "Key is bound to another device.",
    license_expired = "Key expired.",
    license_revoked = "Key revoked.",
    session_expired = "Enter your key again.",
    rate_limited = "Too many attempts. Try again shortly.",
    script_unavailable = "Script unavailable.",
    invalid_request = "Invalid request.",
    unsupported_executor = "Unsupported executor: HWID unavailable.",
    unsupported_http = "Unsupported executor: HTTP unavailable.",
    unsupported_loader = "Unsupported executor: loadstring unavailable.",
    connection_failed = "Could not connect to the key server.",
    timeout = "Connection timed out.",
    invalid_response = "Invalid key server response.",
    script_failed = "Script failed to load.",
}

local function fingerprint()
    local providers = { gethwid, get_hwid, type(syn) == "table" and syn.get_hwid or nil }
    for _, provider in pairs(providers) do
        if type(provider) == "function" then
            local ok, value = pcall(provider)
            if ok and type(value) == "string" and #value > 0 and #value <= 512 and value:find("%S") then
                return value
            end
        end
    end
end

local function endpoint(value, localhost)
    assert(type(value) == "string" and not value:find("[?#@%s]"), "Endpoint must be an HTTPS service URL")
    local allowed = value:match("^https://[^/]+")
        or localhost and (value:match("^http://127%.0%.0%.1:%d+") or value:match("^http://localhost:%d+"))
    assert(allowed, "Endpoint requires HTTPS; AllowLocalhost only permits a loopback development service")
    if not value:match("^https://") then
        local host = value:match("^http://([^/]+)")
        assert(
            host and (host:match("^127%.0%.0%.1:%d+$") or host:match("^localhost:%d+$")),
            "Only loopback HTTP is allowed"
        )
    end
    return value:gsub("/+$", "")
end

function KeySystem:_status(text)
    if not self.Dead and not self.Window.Dead then
        self.Window:SetStatus(text)
    end
end

function KeySystem:_busy(value)
    self.Busy = value
    if not self.Window.Dead then
        self.Key:SetEnabled(not value and self.Supported)
        self.RedeemButton:SetEnabled(not value and self.Supported)
    end
end

function KeySystem:_fail(code)
    self.State, self.Error = "error", code
    self.Job = nil
    self:_busy(false)
    self:_status(MESSAGES[code] or "Key verification failed.")
    if self.Options.OnError then
        self.Window:Dispatch(self.Options.OnError, code, MESSAGES[code])
    end
end

function KeySystem:_clearCache()
    self.Token = nil
    self.Remembered = false
    if type(delfile) == "function" then
        pcall(delfile, self.CachePath)
    elseif type(writefile) == "function" then
        pcall(writefile, self.CachePath, "")
    end
end

function KeySystem:_save(response)
    if not self.RememberEnabled then
        return
    end
    local saved = pcall(function()
        local folder = ""
        for segment in self.CachePath:gmatch("([^/]+)/") do
            folder = folder == "" and segment or folder .. "/" .. segment
            if type(isfolder) ~= "function" or not isfolder(folder) then
                pcall(makefolder, folder)
            end
        end
        writefile(
            self.CachePath,
            HttpService:JSONEncode({
                Version = 1,
                Application = self.Application,
                Endpoint = self.Endpoint,
                Token = response.token,
                ExpiresAt = response.expires_at,
            })
        )
    end)
    self.Remembered = saved
end

function KeySystem:_api(route, credentials, raw)
    local body = { application = self.Application, hwid = self.Hwid }
    for key, value in pairs(credentials) do
        body[key] = value
    end
    local ok, response = pcall(self.Request, {
        Url = self.Endpoint .. "/v1/" .. route,
        Method = "POST",
        Timeout = self.Timeout,
        Headers = { ["Content-Type"] = "application/json", Accept = raw and "text/plain" or "application/json" },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or type(response) ~= "table" or type(response.StatusCode) ~= "number" then
        return nil, "connection_failed"
    end
    if response.StatusCode >= 200 and response.StatusCode < 300 and raw then
        if type(response.Body) ~= "string" or #response.Body < 1 or #response.Body > 2097152 then
            return nil, "invalid_response"
        end
        return response.Body
    end
    local decoded, value = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decoded or type(value) ~= "table" then
        return nil, "invalid_response"
    end
    if response.StatusCode < 200 or response.StatusCode >= 300 then
        return nil, MESSAGES[value.error] and value.error or "connection_failed"
    end
    if route == "executions" then
        return value.ok == true and value or nil, value.ok ~= true and "invalid_response" or nil
    end
    if
        type(value.token) ~= "string"
        or #value.token < 32
        or #value.token > 256
        or type(value.expires_at) ~= "number"
        or value.expires_at ~= value.expires_at
        or value.expires_at == math.huge
        or value.expires_at <= os.time()
    then
        return nil, "invalid_response"
    end
    for _, field in ipairs({ "license_expires_at", "server_time" }) do
        local timestamp = value[field]
        if
            timestamp ~= nil
            and (type(timestamp) ~= "number" or timestamp ~= timestamp or math.abs(timestamp) == math.huge)
        then
            return nil, "invalid_response"
        end
    end
    return value
end

function KeySystem:_reportExecution()
    local player = Players.LocalPlayer
    if not player then
        return
    end
    local generation = self.Generation
    local credentials = {
        token = self.Token,
        execution_id = HttpService:GenerateGUID(false),
        user_id = player.UserId,
        username = player.Name,
        display_name = player.DisplayName,
        place_id = game.PlaceId,
        library_version = self.Library.Version,
    }
    self.ExecutionJob = task.defer(function()
        for attempt = 1, 3 do
            if self.Dead or not self.Loaded or generation ~= self.Generation then
                break
            end
            local response = self:_api("executions", credentials)
            if response then
                self.ExecutionReported = true
                break
            end
            if attempt < 3 then
                task.wait(attempt)
            end
        end
        self.ExecutionJob = nil
    end)
end

function KeySystem:_run(route, credentials)
    if self.Dead or self.Loaded or self.Busy or not self.Supported then
        return false
    end
    self.Generation += 1
    local generation = self.Generation
    self.State, self.Error = "checking", nil
    self.ExecutionReported = false
    self:_busy(true)
    self:_status("Checking key...")
    self.Job = task.defer(function()
        if self.Dead or generation ~= self.Generation then
            return
        end
        local response, code = self:_api(route, credentials)
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not response then
            if
                code == "invalid_credentials"
                or code == "hwid_mismatch"
                or code == "license_expired"
                or code == "license_revoked"
                or code == "session_expired"
            then
                self:_clearCache()
            end
            self:_fail(code)
            return
        end
        self.Token = response.token
        self.LicenseExpiresAt = response.license_expires_at
        self.ServerTime = response.server_time
        self.LicenseInfoKnown = response.license_expires_at ~= nil or response.server_time ~= nil
        self:_save(response)
        self.Key:SetSilent("")
        self:_status("Loading...")
        local source, downloadError = self:_api("script", { token = self.Token }, true)
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not source then
            self:_fail(downloadError)
            return
        end
        local loader = loadstring(source)
        if type(loader) ~= "function" then
            self:_fail("script_failed")
            return
        end
        self.State = "loading"
        self.Window:SetVisible(false)
        local loaded, result = pcall(loader)
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not loaded then
            self.Window:SetVisible(true)
            self:_fail("script_failed")
            return
        end
        self.Loaded, self.Result, self.State, self.Job, self.Busy = true, result, "loaded", nil, false
        self.Completing = true
        self.Window:Destroy()
        if type(result) == "table" then
            local window = result.Window or result
            if type(window) == "table" and type(window.SetLogoutHandler) == "function" then
                self:AttachWindow(window)
            end
        end
        if self.Options.OnLoaded then
            pcall(self.Options.OnLoaded, result)
        end
        if not self.Dead and self.Loaded then
            pcall(self._reportExecution, self)
        end
    end)
    task.delay(self.Timeout, function()
        if not self.Dead and self.Busy and generation == self.Generation and self.State ~= "loading" then
            self.Generation += 1
            if self.Job and type(task.cancel) == "function" then
                pcall(task.cancel, self.Job)
            end
            self.Job = nil
            self:_fail("timeout")
        end
    end)
    return true
end

function KeySystem:Redeem(key)
    if self.Dead then
        return false
    end
    key = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
    if #key < 16 or #key > 256 then
        self:_status("Enter a valid key.")
        return false
    end
    return self:_run("redeem", { key = key })
end

function KeySystem:Forget()
    if self.Dead or self.Loaded or self.Busy then
        return
    end
    self:_clearCache()
    self.Key:SetSilent("")
    self:_status("Enter key.")
end

function KeySystem:AttachWindow(window)
    assert(
        type(window) == "table" and type(window.SetLogoutHandler) == "function",
        "AttachWindow requires a Kinoue window"
    )
    if self.Dead then
        return self
    end
    if self.SessionWindow and not self.SessionWindow.Dead then
        self.SessionWindow:SetLogoutHandler(nil)
    end
    self.SessionWindow = window
    if type(window.SetSessionInfo) == "function" then
        window:SetSessionInfo({
            ExpiresAt = self.LicenseExpiresAt,
            ServerTime = self.ServerTime,
            Known = self.LicenseInfoKnown,
        })
    end
    window:SetLogoutHandler(function()
        self:Logout()
    end)
    return self
end

function KeySystem:Logout()
    if self.Dead or not self.Loaded or self.Busy then
        return false
    end
    local result = self.Result
    local unload = self.Options.OnUnload
    if not unload and type(result) == "table" and type(result.Destroy) == "function" then
        unload = function()
            result:Destroy()
        end
    end
    if not unload and self.SessionWindow then
        unload = function()
            self.SessionWindow:Destroy()
        end
    end
    if not unload then
        return false
    end
    self.Generation += 1
    self.State, self.Busy = "logging_out", true
    local generation, token = self.Generation, self.Token
    self:_clearCache()
    if token then
        local request = self.Request
        local parameters = {
            Url = self.Endpoint .. "/v1/logout",
            Method = "POST",
            Timeout = self.Timeout,
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ application = self.Application, hwid = self.Hwid, token = token }),
        }
        task.defer(function()
            pcall(request, parameters)
        end)
    end
    self.LogoutJob = task.defer(function()
        if self.Dead or generation ~= self.Generation then
            return
        end
        local ok, message = pcall(unload, result)
        self.LogoutJob = nil
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not ok then
            self.State, self.Busy = "loaded", false
            Util.warn("Logout cleanup failed: " .. tostring(message))
            if self.SessionWindow and not self.SessionWindow.Dead then
                self.SessionWindow:SetStatus("Could not unload script.")
            end
            return
        end
        if self.SessionWindow and not self.SessionWindow.Dead then
            self.SessionWindow:Destroy()
        end
        self.SessionWindow, self.Result, self.Loaded = nil, nil, false
        self.State, self.Error = "ready", nil
        self:_buildWindow()
        self:_busy(false)
        self:_status("Enter key.")
    end)
    return true
end

function KeySystem:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    self.Generation += 1
    if self.ExecutionJob and type(task.cancel) == "function" and self.ExecutionJob ~= coroutine.running() then
        pcall(task.cancel, self.ExecutionJob)
    end
    self.ExecutionJob = nil
    if self.Job and type(task.cancel) == "function" and self.Job ~= coroutine.running() then
        pcall(task.cancel, self.Job)
    end
    if self.LogoutJob and type(task.cancel) == "function" and self.LogoutJob ~= coroutine.running() then
        pcall(task.cancel, self.LogoutJob)
    end
    if self.SessionWindow and not self.SessionWindow.Dead then
        self.SessionWindow:SetLogoutHandler(nil)
    end
    self.LogoutJob, self.SessionWindow = nil, nil
    self.Job, self.Hwid, self.Token = nil, nil, nil
    if not self.Window.Dead then
        self.Window:Destroy()
    end
end

function KeySystem:_buildWindow()
    local options = self.Options
    self.Completing = false
    self.Window = KeyDialog.new({
        Name = options.Name or "Kinoue",
        Id = options.Id or "Kinoue_Key_" .. self.Application,
    })
    self.Key = self.Window.Key
    self.RedeemButton = self.Window.RedeemButton
    self.CloseButton = self.Window.CloseButton
    self.Window.Scope:Connect(self.RedeemButton.Root.Activated, function()
        if self.RedeemButton.Enabled then
            self:Redeem(self.Key.Root.Text)
        end
    end)
    self.Window.Scope:Connect(self.Key.Root.FocusLost, function(enter)
        if enter then
            self:Redeem(self.Key.Root.Text)
        end
    end)
    self.Window:OnDestroy(function()
        if not self.Completing then
            self:Destroy()
        end
    end)
end

function KeySystem.new(library, options)
    options = options or {}
    local application = options.Application
    assert(
        type(application) == "string" and #application <= 64 and application:match("^[a-z][a-z0-9_-]*$"),
        "Application requires a lowercase application ID"
    )
    local self = setmetatable({
        Options = options,
        Library = library,
        Application = application,
        Endpoint = endpoint(options.Endpoint, options.AllowLocalhost == true),
        Generation = 0,
        State = "ready",
        Dead = false,
        Busy = false,
        Loaded = false,
    }, KeySystem)
    self.Timeout = math.clamp(tonumber(options.Timeout) or 20, 5, 60)
    self.CachePath = (options.CachePath or "Kinoue/keys/" .. application .. ".json"):gsub("\\", "/")
    assert(
        self.CachePath:match("^[%w_./-]+$") and not self.CachePath:find("%.%.") and self.CachePath:sub(1, 1) ~= "/",
        "CachePath must be an executor workspace path"
    )
    self.CanRemember = type(readfile) == "function" and type(writefile) == "function" and type(makefolder) == "function"
    self.RememberEnabled = self.CanRemember and options.Remember ~= false
    self.Hwid = fingerprint()
    self.Request = request or http_request or (type(syn) == "table" and syn.request)
    self.Supported = self.Hwid ~= nil and type(self.Request) == "function" and type(loadstring) == "function"
    self:_buildWindow()
    if not self.Supported then
        local code = not self.Hwid and "unsupported_executor"
            or type(self.Request) ~= "function" and "unsupported_http"
            or "unsupported_loader"
        self:_fail(code)
        Util.warn(MESSAGES[code])
        return self
    end
    self:_status("Enter key.")
    if self.RememberEnabled then
        local ok, cache = pcall(function()
            return HttpService:JSONDecode(readfile(self.CachePath))
        end)
        if
            ok
            and type(cache) == "table"
            and cache.Version == 1
            and cache.Application == self.Application
            and cache.Endpoint == self.Endpoint
            and type(cache.Token) == "string"
            and #cache.Token >= 32
            and #cache.Token <= 256
            and type(cache.ExpiresAt) == "number"
            and cache.ExpiresAt > os.time()
        then
            self:_run("session", { token = cache.Token })
        end
    end
    return self
end

Util.protect(KeySystem, { "Redeem", "Forget", "AttachWindow", "Logout", "Destroy" })
return KeySystem
