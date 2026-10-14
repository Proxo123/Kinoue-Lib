local CORE_IDENTITY = 8

local Mount = {}

local function protector()
    if type(protect_gui) == "function" then
        return protect_gui
    end
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        return syn.protect_gui
    end
    return nil
end

local function identityHelpers()
    local getIdentity = type(getthreadidentity) == "function" and getthreadidentity
        or (type(syn) == "table" and syn.get_thread_identity)
    local setIdentity = type(setthreadidentity) == "function" and setthreadidentity
        or (type(syn) == "table" and syn.set_thread_identity)
    if type(getIdentity) == "function" and type(setIdentity) == "function" then
        return getIdentity, setIdentity
    end
    return nil, nil
end

local function attach(screen, replaceExisting)
    local core = game:GetService("CoreGui")
    if replaceExisting then
        for _, existing in ipairs(core:GetChildren()) do
            if existing ~= screen and existing:IsA("ScreenGui") and existing.Name == screen.Name then
                existing:Destroy()
            end
        end
    end
    screen.Parent = core
end

function Mount.core(screen, replaceExisting)
    local protect = protector()
    if protect then
        pcall(protect, screen)
    end

    local ok, message = pcall(attach, screen, replaceExisting)
    if ok then
        return
    end

    local getIdentity, setIdentity = identityHelpers()
    if getIdentity then
        local read, identity = pcall(getIdentity)
        if read then
            if pcall(setIdentity, CORE_IDENTITY) then
                ok, message = pcall(attach, screen, replaceExisting)
            end
            local restored, restoreError = pcall(setIdentity, identity)
            if not restored then
                screen:Destroy()
                error("[Kinoue] Failed to restore thread identity: " .. tostring(restoreError), 2)
            end
            if ok then
                return
            end
        end
    end

    screen:Destroy()
    error("[Kinoue] CoreGui mount failed. This client must allow CoreGui access: " .. tostring(message), 2)
end

return Mount
