local window = UI:CreateWindow({})
Mock:Advance(1)
local group = window:AddTab("Performance"):AddGroupbox("Controls")
assert(window.Fade.Entries[window.ActivePage.Frame] and not window.Fade.Active[window.ActivePage.Frame], "Transparent containers must be excluded from fade rendering")
window.ActivePage.Frame.BackgroundTransparency=0.5
assert(window.Fade.Active[window.ActivePage.Frame], "Opacity changes must rejoin the fade set")
window.Fade:Set(0.5)
assert(window.ActivePage.Frame.BackgroundTransparency==0.75)
window.Fade:Set(0)
window.ActivePage.Frame.BackgroundTransparency=1
assert(not window.Fade.Active[window.ActivePage.Frame])
local controls = {}
for i = 1, 3 do controls[i] = group:AddToggle("Mode" .. i, { Value = false }) end
local before = Mock.TweenCreates
for _ = 1, 1000 do for _, control in ipairs(controls) do control:SetSilent(false) end end
assert(Mock.TweenCreates == before, "Unchanged synchronization must not start animations")
controls[1]:Set(true)
assert(Mock.TweenCreates == before + 3, "Changed toggles must still animate")
local dropdown = group:AddDropdown("Material", { Options = {{ Value = "Wood", Meta = 10 }} })
dropdown:UpdateOptions({{ Value = "Wood", Meta = 20 }})
local found = false
for _, object in ipairs(dropdown.Root:GetChildren()) do if object.Text == "20" then found = true end end
assert(found, "Unchanged selections must still refresh changed option metadata")
local V = Mock.Environment.Vector2.new
local preview = group:AddPreview({ Points = {V(0, 0), V(1, 0), V(2, 0)} })
local first, instances = preview.Parts[1], #Mock.Instances
for _ = 1, 100 do preview:SetPoints({V(0, 0), V(1, 0), V(2, 0)}) end
assert(#Mock.Instances == instances and preview.Parts[1] == first, "Unchanged previews must allocate no instances")
preview:SetPoints({V(0, 0), V(1, 1), V(2, 0)})
assert(preview.Parts[1] == first and #Mock.Instances == instances, "Changed geometry must reuse existing pixels")
preview:SetPoints({V(0, 0)})
assert(#preview.Parts == 1 and preview.Parts[1] == first)
preview:SetPoints({V(0, 0), V(1, 0)})
assert(#preview.Parts == 2 and preview.Parts[1] == first)
local connections = Mock:ConnectionCount()
for _ = 1, 10 do
    window:SetVisible(false)
    assert(window.AccentScope == nil, "Hidden windows must disconnect the accent animation")
    window:SetVisible(true)
end
assert(Mock:ConnectionCount() == connections, "Reopening must not accumulate connections")
window:Destroy(); Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print("PASS: 3,000 unchanged toggle updates create zero tweens; preview reuse, metadata refresh, hidden accent suspension, and reopen cleanup")
