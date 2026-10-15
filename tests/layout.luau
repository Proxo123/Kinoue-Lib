local window = UI:CreateWindow({ Subtitle = "Demo", ReducedMotion = true })
Mock:Advance(1)
local main = window:AddTab("Main")
window:AddTab("Visuals")
local group = main:AddGroupbox("Main", "Left")

local feature =
    group:AddToggle("Feature", { Text = "Feature", SubToggle = true, Keybind = { Value = Mock.Enum.KeyCode.H } })
local row = feature.Root.Parent
local order = {}
for index, child in ipairs(row:GetChildren()) do
    order[child] = index
end
assert(feature.SettingsButton.ZIndex > feature.Root.ZIndex, "The cog sits above the row's click area")
assert(order[feature.SettingsButton] > order[feature.Root], "The cog is created after the row's click area")
assert(feature.Keybind.Root.ZIndex > feature.Root.ZIndex and feature.Keybind.Clear.ZIndex > feature.Root.ZIndex)
feature.SettingsButton.Activated:Fire()
assert(feature:IsSettingsOpen() and feature:Get() == false, "The cog opens settings without flipping the toggle")

assert(UI.Theme.Font.Name == "BuilderSans" and UI.Theme.FontBold.Name == "BuilderSansBold", "Labels use Builder Sans")
assert(UI.Theme.TextSize >= 14, "Body text is at least 14px")

assert(window.TabsInHeader, "Tabs sit in the header when they fit")
assert(window.Tabs.Position.Y.Offset > 0 and window.Tabs.Position.Y.Offset < 44, "Tabs share the top row")
assert(window.Tabs.Position.X.Offset > window.SubtitleLabel.Position.X.Offset, "Tabs follow the title and subtitle")
assert(window.Body.Position.Y.Offset == 44, "The page starts right under the header")

window.TabStrip.Size = Mock.Environment.UDim2.fromOffset(2000, 30)
window:Relayout()
assert(not window.TabsInHeader, "Too many tabs move to their own row")
assert(window.Tabs.Position.Y.Offset >= 44 and window.Body.Position.Y.Offset == 80)
window.TabStrip.Size = Mock.Environment.UDim2.fromOffset(0, 30)
window:Relayout()
assert(window.TabsInHeader and window.Body.Position.Y.Offset == 44, "Tabs return to the header when they fit again")

window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print("PASS: cog above the toggle row, Builder Sans text, tabs in the header with overflow row")
