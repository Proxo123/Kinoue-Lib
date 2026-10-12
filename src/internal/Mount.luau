local Mount = {}
function Mount.core(screen, replaceExisting)
    -- Executor helpers are optional. Keep the destination CoreGui in every path.
    local protect = type(protect_gui) == "function" and protect_gui
        or (type(syn) == "table" and type(syn.protect_gui) == "function" and syn.protect_gui)
    if protect then pcall(protect, screen) end
    local function parent()
        local core = game:GetService("CoreGui")
        if replaceExisting then
            for _, existing in ipairs(core:GetChildren()) do
                if existing ~= screen and existing:IsA("ScreenGui") and existing.Name == screen.Name then existing:Destroy() end
            end
        end
        screen.Parent = core
    end
    local ok, message = pcall(parent)
    if ok then return end
    local getIdentity = type(getthreadidentity) == "function" and getthreadidentity
        or (type(syn) == "table" and syn.get_thread_identity)
    local setIdentity = type(setthreadidentity) == "function" and setthreadidentity
        or (type(syn) == "table" and syn.set_thread_identity)
    if type(getIdentity) == "function" and type(setIdentity) == "function" then
        local read, identity = pcall(getIdentity)
        if read then
            local elevated = pcall(setIdentity, 8)
            if elevated then ok, message = pcall(parent) end
            local restored, restoreError = pcall(setIdentity, identity)
            if not restored then
                screen:Destroy()
                error("[BoogaUI] Failed to restore thread identity: " .. tostring(restoreError), 2)
            end
            if ok then return end
        end
    end
    screen:Destroy()
    error("[BoogaUI] CoreGui mount failed. This client must allow CoreGui access: " .. tostring(message), 2)
end
return Mount
