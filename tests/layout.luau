local window = UI:CreateWindow({ Subtitle = "Demo", ReducedMotion = true })
Mock:Advance(1)
local main = window:AddTab("Main")
window:AddTab("Visuals")
local group = main:AddGroupbox("Main", "Left")
local rightGroup = main:AddGroupbox("Right", "Right")
local outlines = {}
for _, card in ipairs({ group.Frame, rightGroup.Frame, window.TabStrip }) do
    local outline
    for _, child in ipairs(card:GetChildren()) do
        if child:IsA("UIStroke") then
            outline = child
            break
        end
    end
    assert(
        outline and outline.BorderStrokePosition == Mock.Enum.BorderStrokePosition.Inner,
        "Outlines stay inside cards and tab strips, including clipped left/top edges"
    )
    assert(outline.Thickness == 1)
    table.insert(outlines, outline)
end
window.Fade:Set(1)
for _, outline in ipairs(outlines) do
    assert(outline.Transparency == 1, "Inset outlines fade with the window")
end
window.Fade:Set(0)
for _, outline in ipairs(outlines) do
    assert(outline.Transparency == 0, "Inset outlines return after reopening")
end
local outlineColor = Mock.Environment.Color3.fromRGB(95, 100, 110)
UI:SetTheme({ Outline = outlineColor })
for _, outline in ipairs(outlines) do
    assert(outline.Color == outlineColor, "Inset outlines follow theme edits")
end
UI:SetTheme("Dark")

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

local pill = window.TabPill
local first = window.Pages[1].Button.Size.X.Offset
assert(pill.Visible and pill.Position.X.Offset == 0 and pill.Size.X.Offset == first, "The pill sits on the active tab")
window.Pages[2]:Select()
assert(pill.Position.X.Offset == first, "The pill slides to the selected tab")
assert(pill.Size.X.Offset == window.Pages[2].Button.Size.X.Offset, "The pill resizes to the selected tab")
assert(window.Pages[2].Button.BackgroundTransparency == 1, "Tabs themselves stay transparent")
window:OpenSettings()
assert(not pill.Visible, "No tab is highlighted while settings are open")
window:CloseSettings()
assert(pill.Visible and pill.Position.X.Offset == first)
window.Pages[1]:Select()

assert(not main.Title.Visible and main.Scroll.Position.Y.Offset == 16, "Pages start with their content, no title row")
main:SetTitle("Main page")
assert(main.Title.Visible and main.Scroll.Position.Y.Offset > 16, "SetTitle shows the title row")
assert(not window.Accent.Visible, "The rainbow line is off by default")

assert(window.TabsInHeader, "Tabs sit in the header when they fit")
assert(window.Tabs.Position.Y.Offset > 0 and window.Tabs.Position.Y.Offset < 52, "Tabs share the top row")
assert(window.Tabs.Position.X.Offset > window.SubtitleLabel.Position.X.Offset, "Tabs follow the title and subtitle")
assert(window.Body.Position.Y.Offset == 52, "The page starts right under the header")

window.TabStrip.Size = Mock.Environment.UDim2.fromOffset(2000, 30)
window:Relayout()
assert(not window.TabsInHeader, "Too many tabs move to their own row")
assert(window.Tabs.Position.Y.Offset >= 52 and window.Body.Position.Y.Offset == 96)
window.TabStrip.Size = Mock.Environment.UDim2.fromOffset(0, 30)
window:Relayout()
assert(window.TabsInHeader and window.Body.Position.Y.Offset == 52, "Tabs return to the header when they fit again")

window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print("PASS: cog above the toggle row, Builder Sans text, tabs in the header with overflow row")
