local V = Mock.Environment.Vector2.new
local window = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)

local main = window:AddTab("Main")
local combat = main:AddGroupbox("Combat", "Left")
local aim = combat:AddToggle("Aim", { Text = "Aim assist", SubToggle = true })
local smooth = aim.Settings:AddSlider("Smooth", { Text = "Smoothness", Min = 0, Max = 10 })
local advanced = combat:AddDisclosure("Advanced")
local fov = advanced:AddSlider("FOV", { Text = "Field of view", Min = 1, Max = 120 })
combat:AddButton({ Text = "Run script" })
local visuals = window:AddTab("Visuals")
visuals:AddSubTab("Players")
local world = visuals:AddSubTab("World")
local bright = world:AddGroupbox("Lighting", "Left"):AddToggle("Bright", { Text = "Fullbright" })

local state = window.Search
assert(state.Button.Parent == window.Header, "The search button lives in the header")
assert(state.Button.Position.X.Offset < window.SettingsButton.Position.X.Offset, "Search sits left of settings")

state.Button.Activated:Fire()
assert(state.Open and state.Box.Visible and Mock.Input.Focused == state.Box, "Opening focuses the search box")
assert(state.Icon.Color == UI.Theme.Accent)
assert(not state.Results.Visible, "Results wait for a query")

state.Box.Text = "smooth"
assert(#state.Matches == 1 and state.Matches[1].Name == "Smoothness" and #state.Rows == 1)
assert(state.Rows[1]:WaitForChild("Path").Text == "Main > Combat > Aim assist", "Results show where a setting lives")
state.Rows[1].Activated:Fire()
assert(not state.Open and not state.Results.Visible and Mock.Input.Focused == nil, "Picking a result closes search")
assert(aim:IsSettingsOpen(), "Search opens sub-toggle settings")
Mock:Advance(0)
assert(smooth.Row:WaitForChild("SearchHighlight"), "The found setting flashes")
Mock:Advance(1)

window:OpenSearch()
state.Box.Text = "fullbright"
assert(state.Matches[1].Name == "Fullbright")
assert(state.Rows[1]:WaitForChild("Path").Text == "Visuals > World > Lighting")
state.Box.FocusLost:Fire(true)
assert(window.ActivePage == visuals and visuals.ActiveSubpage == world, "Enter jumps to the first result")

window:OpenSearch()
state.Box.Text = "field"
state.Rows[1].Activated:Fire()
assert(window.ActivePage == main and advanced:IsOpen(), "Search opens collapsed sections")
assert(fov.Row.Parent ~= nil)

window:OpenSearch()
state.Box.Text = "combat"
assert(state.Matches[1].Kind == "Group" and state.Matches[1].Name == "Combat")
state.Box.Text = "visuals"
assert(state.Matches[1].Kind == "Tab")
state.Box.Text = "world"
assert(state.Matches[1].Kind == "Tab" and state.Rows[1]:WaitForChild("Path").Text == "Visuals")
state.Box.Text = "run"
assert(state.Rows[1]:WaitForChild("Title").Text == "Run script" and state.Matches[1].Kind == "Setting")
state.Box.Text = "accent"
assert(state.Matches[1].Name == "Accent", "Built-in settings are searchable")
assert(state.Rows[1]:WaitForChild("Path").Text == "UI settings > Theme")
state.Rows[1].Activated:Fire()
assert(window.SettingsOpen, "Search opens the settings page")
window:CloseSettings()

window:OpenSearch()
state.Box.Text = "zzzz"
assert(#state.Matches == 0 and #state.Rows == 1 and state.Results.Visible, "Empty searches say so")
bright:SetVisible(false)
state.Box.Text = "fullbright"
assert(#state.Matches == 0, "Hidden controls are left out")
bright:SetVisible(true)

Mock:Key("Escape")
assert(not state.Open, "Escape closes search")
window:OpenSearch()
Mock.Input.InputBegan:Fire({
    UserInputType = Mock.Enum.UserInputType.MouseButton1,
    KeyCode = Mock.Enum.KeyCode.Unknown,
    Position = V(5, 700),
}, false)
assert(not state.Open, "Clicking elsewhere closes search")
state.Button.Activated:Fire()
state.Button.Activated:Fire()
assert(not state.Open, "The search button toggles")
window:OpenSearch()
window:SetVisible(false)
assert(not state.Open, "Hiding the window closes search")
window:SetVisible(true)

window:OpenSearch()
state.Box.Text = "aim"
window:Destroy()
Mock:Advance(2)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
print("PASS: header search, ranking, paths, tab/sub-tab/section/sub-toggle navigation, settings search, closing rules")
