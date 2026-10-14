local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent.internal.Util)

local CONFIG_VERSION = 1
local SAVE_INTERVAL = 0.5

local Config = {}

local function encodeValue(value)
    if typeof(value) == "EnumItem" then
        return { Type = "KeyCode", Name = value.Name }
    end
    if typeof(value) == "Color3" then
        return { Type = "Color3", R = value.R, G = value.G, B = value.B }
    end
    return value
end

local function decodeValue(value)
    if type(value) == "table" and value.Type == "KeyCode" then
        return Enum.KeyCode[value.Name]
    end
    if type(value) == "table" and value.Type == "Color3" then
        return Color3.new(value.R, value.G, value.B)
    end
    return value
end

function Config:GetConfig()
    local values = {}
    for id, control in pairs(self.Controls) do
        if control.Persist ~= false then
            values[id] = encodeValue(control:Get())
        end
    end
    return { Version = CONFIG_VERSION, Values = values }
end

function Config:LoadConfig(config)
    assert(
        type(config) == "table" and config.Version == CONFIG_VERSION and type(config.Values) == "table",
        "Unsupported UI config"
    )
    for id, saved in pairs(config.Values) do
        local control = self.Controls[id]
        if control then
            local ok, message = pcall(function()
                control:Set(decodeValue(saved))
            end)
            if not ok then
                Util.warn("Skipped saved value for " .. id .. ": " .. tostring(message))
            end
        end
    end
end

function Config:EncodeConfig()
    return HttpService:JSONEncode(self:GetConfig())
end

function Config:DecodeConfig(json)
    self:LoadConfig(HttpService:JSONDecode(json))
end

function Config:ConfigChanged()
    if self.Storage and not self.RestoringConfig then
        self.ConfigDirty = true
    end
end

function Config:FlushConfig()
    if not self.Storage or not self.ConfigDirty then
        return
    end
    local ok, message = pcall(self.Storage.Write, self:EncodeConfig())
    if ok then
        self.ConfigDirty = false
    else
        Util.warn("Config save failed: " .. tostring(message))
    end
end

function Config:EnablePersistence(adapter)
    assert(
        type(adapter) == "table" and type(adapter.Read) == "function" and type(adapter.Write) == "function",
        "Persistence requires Read/Write functions"
    )
    self.Storage = adapter
    self.RestoringConfig = true
    local ok, json = pcall(adapter.Read)
    if ok and json and json ~= "" then
        local loaded, message = pcall(function()
            self:DecodeConfig(json)
        end)
        if not loaded then
            Util.warn("Ignored invalid config: " .. tostring(message))
        end
    end
    self.RestoringConfig = false

    if not self.PersistenceConnection then
        local elapsed = 0
        self.PersistenceConnection = self.Scope:Connect(RunService.Heartbeat, function(deltaTime)
            elapsed += deltaTime
            if elapsed >= SAVE_INTERVAL then
                elapsed = 0
                self:FlushConfig()
            end
        end)
    end
end

return Config
