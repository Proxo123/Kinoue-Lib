local RunService = game:GetService("RunService")
local Media = require(script.Parent.Parent.internal.LocalMedia)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local Background = {}
local DEFAULTS = { Enabled = false, File = "", Opacity = 0.6, PanelOpacity = 0.8, Fit = "Cover", Speed = 1 }
local FIT = { Cover = Enum.ScaleType.Crop, Contain = Enum.ScaleType.Fit, Stretch = Enum.ScaleType.Stretch }

local function active(state)
    return state.Options.Enabled and state.Media ~= nil and state.Options.Opacity > 0
end

local function paint(state, index)
    if index == state.Index then
        return
    end
    local frame = state.Media.Frames[index]
    state.Image.Image = frame.Image
    state.Image.ImageRectOffset = frame.Offset
    state.Image.ImageRectSize = frame.Size
    state.Index = index
end

function Background.init(window, options)
    window.BackgroundState = { Options = table.clone(DEFAULTS), Surfaces = {}, Generation = 0, Time = 0 }
    if options then
        Background.set(window, options)
    end
end

function Background.surface(window, object)
    local state = window.BackgroundState
    local entry = window.Fade and window.Fade.Entries[object]
    state.Surfaces[object] = entry and entry.Base.BackgroundTransparency or object.BackgroundTransparency
    if active(state) then
        object.BackgroundTransparency = 1 - state.Options.PanelOpacity
    end
    window.Scope:Connect(object.Destroying, function()
        state.Surfaces[object] = nil
    end)
end

function Background.mount(window)
    local state = window.BackgroundState
    state.Image = Util.new("ImageLabel", {
        Name = "BackgroundMedia",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 0,
        Visible = false,
        Image = "",
        ImageTransparency = 1,
        ScaleType = FIT[state.Options.Fit],
    }, window.Root)
    Util.corner(state.Image, Theme.WindowRadius)
    Background.sync(window)
    Background.load(window)
end

function Background.sync(window)
    local state = window.BackgroundState
    if not state or not state.Image then
        return
    end
    local enabled = active(state)
    state.Image.Visible = enabled
    state.Image.ImageTransparency = 1 - state.Options.Opacity
    state.Image.ScaleType = FIT[state.Options.Fit]
    for object, original in pairs(state.Surfaces) do
        object.BackgroundTransparency = enabled and (1 - state.Options.PanelOpacity) or original
    end
    local playing = enabled and window.Open and not window.ReducedMotion and #state.Media.Frames > 1
    if not playing and state.Connection then
        window.Scope:Release(state.Connection)
        state.Connection = nil
    elseif playing and not state.Connection then
        state.Connection = window.Scope:Connect(RunService.RenderStepped, function(delta)
            state.Time = (state.Time + (delta or 1 / 60) * state.Options.Speed) % state.Media.Duration
            local low, high = 1, #state.Media.Frames
            while low < high do
                local mid = math.floor((low + high) / 2)
                if state.Time < state.Media.Frames[mid].End then
                    high = mid
                else
                    low = mid + 1
                end
            end
            paint(state, low)
        end)
    end
end

local function cancel(state)
    state.Generation += 1
    if state.Job and task.cancel then
        pcall(task.cancel, state.Job)
    end
    state.Job = nil
    state.Loading = false
end

function Background.load(window)
    local state = window.BackgroundState
    cancel(state)
    if not state.Image or not state.Options.Enabled or state.Options.File == "" then
        return
    end
    local path, generation = state.Options.File, state.Generation
    state.Loading, state.Error = true, nil
    state.Job = task.defer(function()
        local budget = os.clock()
        local function checkpoint()
            assert(not window.Dead and generation == state.Generation, "Background load cancelled")
            if os.clock() - budget >= 0.003 then
                RunService.Heartbeat:Wait()
                budget = os.clock()
                assert(not window.Dead and generation == state.Generation, "Background load cancelled")
            end
        end
        local ok, result = pcall(function()
            checkpoint()
            local media = Media.load(path, checkpoint)
            checkpoint()
            local failed = false
            game:GetService("ContentProvider"):PreloadAsync(media.Pages, function(_, status)
                if status ~= Enum.AssetFetchStatus.Success then
                    failed = true
                end
            end)
            checkpoint()
            assert(not failed, "Roblox could not load the background image")
            for _, frame in ipairs(media.Frames) do
                frame.Offset, frame.Size = Vector2.new(frame.X, frame.Y), Vector2.new(frame.Width, frame.Height)
            end
            return media
        end)
        if window.Dead or generation ~= state.Generation then
            return
        end
        state.Job, state.Loading = nil, false
        Util.withContext(function()
            if ok then
                state.Media, state.LoadedFile = result, path
                state.Time, state.Index = 0, nil
                paint(state, 1)
                Background.sync(window)
            else
                state.Error = tostring(result):gsub("^.-:%d+: ", "")
                window:Notify({ Title = "Background", Text = state.Error })
            end
        end)
    end)
end

function Background.set(window, options, reload)
    local state = window.BackgroundState
    if window.Dead then
        return
    end
    if type(options) == "string" then
        options = { File = options, Enabled = true }
    end
    assert(type(options) == "table", "SetBackground requires a file path or options table")
    local nextOptions = table.clone(state.Options)
    for key, value in pairs(options) do
        assert(DEFAULTS[key] ~= nil, "Unknown background option: " .. tostring(key))
        if key == "Enabled" then
            assert(type(value) == "boolean", "Background Enabled requires a boolean")
        elseif key == "File" then
            assert(type(value) == "string" and #value <= 1024 and not value:find("%z"), "Invalid background file path")
        elseif key == "Fit" then
            assert(FIT[value], "Background Fit must be Cover, Contain, or Stretch")
        else
            assert(
                type(value) == "number" and value == value and math.abs(value) < math.huge,
                "Invalid background " .. key
            )
            value = math.clamp(value, key == "Speed" and 0.1 or 0, key == "Speed" and 4 or 1)
        end
        nextOptions[key] = value
    end
    local changedFile = nextOptions.File ~= state.Options.File
    local changedEnabled = nextOptions.Enabled ~= state.Options.Enabled
    state.Options = nextOptions
    for key, value in pairs(nextOptions) do
        local control = window.Controls["UI.Background." .. key]
        if control then
            control:SetSilent(value)
        end
    end
    if changedFile or changedEnabled or reload then
        cancel(state)
        if nextOptions.File == "" then
            state.Media, state.LoadedFile, state.Index, state.Error = nil, nil, nil, nil
            if state.Image then
                state.Image.Image = ""
            end
        end
        if nextOptions.Enabled and nextOptions.File ~= "" and (reload or state.LoadedFile ~= nextOptions.File) then
            Background.load(window)
        end
    end
    Background.sync(window)
    if window.ConfigChanged then
        window:ConfigChanged()
    end
end

function Background.destroy(window)
    local state = window.BackgroundState
    cancel(state)
    if state.Connection then
        window.Scope:Release(state.Connection)
        state.Connection = nil
    end
    state.Media = nil
    table.clear(state.Surfaces)
end

return Background
