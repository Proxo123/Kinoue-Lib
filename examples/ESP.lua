local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/booga-ui/v0.1.7/dist/BoogaUI.lua"))()

local Players = game:GetService("Players")
local environment = type(getgenv) == "function" and getgenv() or shared
if environment and environment.BoogaESPExample then environment.BoogaESPExample:Destroy() end
local window = UI:CreateWindow({ Name = "BOOGA", Id = "BoogaESPExample", Footer = "ESP example" })
if environment then environment.BoogaESPExample = window end

local page = window:AddTab("Visuals")
local esp = page:AddGroupbox("Player ESP", "Left")
local appearance = page:AddGroupbox("Appearance", "Right")
local enabled, throughWalls, preview = true, true, false
local tint, transparency = Color3.fromRGB(57, 128, 233), 0.75
local records = {}
local function apply(record)
    local highlight = record.Highlight
    if not highlight then return end
    highlight.Enabled = enabled and (record.Player ~= Players.LocalPlayer or preview)
    highlight.FillColor = tint; highlight.OutlineColor = tint
    highlight.FillTransparency = transparency; highlight.OutlineTransparency = 0
    highlight.DepthMode = throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
end
local function refresh() for _, record in pairs(records) do apply(record) end end
esp:AddToggle("ESP", { Text = "Player ESP", Value = true, Callback = function(value) enabled = value; refresh() end })
esp:AddToggle("ThroughWalls", { Text = "Through walls", Value = true, Callback = function(value) throughWalls = value; refresh() end })
esp:AddToggle("SelfPreview", { Text = "Self preview", Value = false, Callback = function(value) preview = value; refresh() end })
appearance:AddColorPicker("ESPColor", { Text = "Color", Value = tint, Callback = function(value) tint = value; refresh() end })
appearance:AddSlider("FillTransparency", { Text = "Fill transparency", Min = 0, Max = 100, Value = 75, Suffix = "%", Callback = function(value) transparency = value / 100; refresh() end })
local function clear(record)
    if record.Highlight then record.Highlight:Destroy(); record.Highlight = nil end
end
local function remove(player)
    local record = records[player]
    if not record then return end
    for _, connection in ipairs(record.Connections) do connection:Disconnect() end
    clear(record); records[player] = nil
end
local function add(player)
    if records[player] then return end
    local record = { Player = player, Connections = {} }
    records[player] = record
    local function characterAdded(character)
        clear(record)
        local highlight = Instance.new("Highlight")
        highlight.Name = "BoogaESPExample"
        highlight.Adornee = character
        record.Highlight = highlight
        apply(record)
        highlight.Parent = character
    end
    table.insert(record.Connections, player.CharacterAdded:Connect(characterAdded))
    table.insert(record.Connections, player.CharacterRemoving:Connect(function() clear(record) end))
    if player.Character then characterAdded(player.Character) end
end
window.Scope:Connect(Players.PlayerAdded, add)
window.Scope:Connect(Players.PlayerRemoving, remove)
window:OnDestroy(function()
    for player in pairs(records) do remove(player) end
    if environment and environment.BoogaESPExample == window then environment.BoogaESPExample = nil end
end)
for _, player in ipairs(Players:GetPlayers()) do add(player) end

local settings = window:AddTab("Settings"):AddGroupbox("Window", "Left")
settings:AddKeybind("MenuKey", { Text = "Show / hide menu", Value = Enum.KeyCode.RightShift, Callback = function(key) window:SetToggleKey(key) end })
settings:AddButton({ Text = "Unload", Callback = function() window:Destroy() end })
window:SetStatus("Click the color swatch to test")
page:Select()
return window
