local fixtures = require("../tests/MediaFixtures")
local files = {
    ["rain.gif"] = fixtures[1].Data,
    ["other.gif"] = fixtures[2].Data,
    ["still.png"] = "\137PNG\13\10\26\10\0\0\0\13IHDR\0\0\0\2\0\0\0\1" .. string.rep("\0", 9),
    ["bad.bin"] = "invalid",
}
local writes, assets, reads = 0, 0, 0
Mock.Environment.isfile = function(path)
    return files[path] ~= nil
end
Mock.Environment.isfolder = function()
    return true
end
Mock.Environment.makefolder = function() end
Mock.Environment.readfile = function(path)
    reads += 1
    return assert(files[path], "Missing file")
end
Mock.Environment.writefile = function(path, data)
    writes += 1
    files[path] = data
end
Mock.Environment.getcustomasset = function(path)
    assert(files[path], "Asset must exist")
    assets += 1
    return "local://" .. path
end

local window = UI:CreateWindow({ RainbowAccent = false })
local group = window:AddTab("Main"):AddGroupbox("Settings", "Left")
Mock:Advance(1)
assert(not window.BackgroundState.Image.Visible and not window.BackgroundState.Connection)
window:SetBackground("rain.gif")
assert(window:GetBackgroundStatus().Loading)
Mock:Advance(0)
local state, status = window.BackgroundState, window:GetBackgroundStatus()
assert(not status.Error, status.Error)
assert(status.Kind == "GIF" and status.Frames == 5 and status.Width == 20 and state.Image.Visible)
assert(state.Connection and state.Image.ImageRectSize.X == 20 and state.Image.ImageRectOffset.X == 1)
assert(math.abs(window.Header.BackgroundTransparency - 0.2) < 0.001)
assert(window.Controls["UI.Background.File"]:Get() == "rain.gif")
local index = state.Index
for _ = 1, 7 do
    Mock:Render()
end
assert(state.Index ~= index, "GIF timing advances with render delta")
local original = state.Time
window:SetVisible(false)
assert(not state.Connection, "Hidden windows release animation connection")
Mock:Render()
assert(state.Time == original)
window:SetVisible(true)
assert(state.Connection)
window:SetReducedMotion(true)
assert(not state.Connection)
window:SetReducedMotion(false)
window:SetBackground({ Opacity = 0 })
assert(not state.Connection and not state.Image.Visible and window.Header.BackgroundTransparency == 0)
window:SetBackground({ Opacity = 0.75, PanelOpacity = 0.45, Fit = "Contain", Speed = 2 })
assert(state.Connection and state.Image.ScaleType == Mock.Enum.ScaleType.Fit)
assert(math.abs(window.Header.BackgroundTransparency - 0.55) < 0.001)
local written = writes
window:SetBackground({ Enabled = true }, true)
Mock:Advance(0)
assert(window:GetBackgroundStatus().Cached and writes == written, "Cached GIFs avoid redecoding and rewriting")
local old = state.Media
window:SetBackground("bad.bin")
Mock:Advance(0)
assert(window:GetBackgroundStatus().Error and state.Media == old, "Invalid files preserve the active background")
Mock.MediaFailure = true
window:SetBackground("still.png")
Mock:Advance(0)
assert(
    window:GetBackgroundStatus().Error and state.Media == old,
    "Failed Roblox asset loads preserve the active background"
)
Mock.MediaFailure = false
window:SetBackground({ Enabled = true }, true)
Mock:Advance(0)
assert(window:GetBackgroundStatus().Kind == "Image" and not state.Connection, "Images need no render connection")
assert(state.Image.ImageRectSize.X == 0 and state.Image.ImageRectOffset.X == 0)
for _, image in ipairs(fixtures.Images) do
    files[image.Name] = image.Data
    window:SetBackground(image.Name)
    Mock:Advance(0)
    local imageStatus = window:GetBackgroundStatus()
    assert(not imageStatus.Error and imageStatus.Kind == "Image", imageStatus.Error)
    assert(imageStatus.Width == image.Width and imageStatus.Height == image.Height)
end
local workingImage = state.Media
files["oversized.png"] = "\137PNG\13\10\26\10\0\0\0\13IHDR\0\0\32\0\0\0\0\1" .. string.rep("\0", 9)
window:SetBackground("oversized.png")
Mock:Advance(0)
assert(
    window:GetBackgroundStatus().Error and state.Media == workingImage,
    "Oversized images are rejected before registration"
)
window:SetBackground("still.png")
Mock:Advance(0)
local saved = window:GetConfig()
window:ClearBackground()
assert(not state.Image.Visible and not state.Media and window.Header.BackgroundTransparency == 0)
window:LoadConfig(saved)
Mock:Advance(0)
assert(window:GetBackgroundStatus().Kind == "Image" and state.Options.Speed == 2 and state.Options.Fit == "Contain")
window:SetBackground("rain.gif")
window:SetBackground("other.gif")
Mock:Advance(0)
assert(window:GetBackgroundStatus().File == "other.gif", "Newer requests supersede pending loads")
Mock.OnPreload = function()
    window:ClearBackground()
end
window:SetBackground("rain.gif")
Mock:Advance(0)
assert(not state.Media and not state.Loading, "Cancelled preloads cannot replace a cleared background")
Mock.OnPreload = nil
assert(not pcall(function()
    window:SetBackground({ Speed = 0 / 0 })
end))
assert(not pcall(function()
    window:SetBackground({ Fit = "invalid" })
end))
window:SetBackground("rain.gif")
Mock:Advance(0)
window:SetVisible(false)
Mock:Advance(1)
window:SetBackground({ PanelOpacity = 0.35 })
window:SetVisible(true)
assert(math.abs(window.Header.BackgroundTransparency - 0.65) < 0.001, "Background surfaces survive window fading")
UI:SetTheme("Ocean")
assert(math.abs(window.Header.BackgroundTransparency - 0.65) < 0.001, "Themes preserve media transparency")
window:SetBackground("other.gif")
window:Destroy()
local before = assets
Mock:Advance(1)
assert(assets == before and not state.Media and not state.Connection)
assert(Mock:ConnectionCount() == 0, "Unload releases background resources and all signals")
print(
    "PASS: local media loading, asset failures, cache reuse, timing, pause, config, fading, cancellation and teardown"
)
