-- SHIFT+OPTION+DOWN  → minimize focused window
-- SHIFT+OPTION+UP    → restore last minimized window
--                  if pressed again (and nothing to restore) → maximize focused window

local lastMinimizedAppPID = nil
local lastMinimizedWindowID = nil
local lastRestoredWindowID = nil

local function isWindowUsable(win)
    return win
        and win:id() ~= nil
        and win:application() ~= nil
        and win:application():isRunning()
end

-- Returns true ONLY if it actually restored (unminimized) a minimized window.
local function restoreTrackedWindow()
    if lastMinimizedAppPID == nil or lastMinimizedWindowID == nil then
        return false
    end

    local app = hs.application.applicationForPID(lastMinimizedAppPID)
    if not app then return false end

    for _, win in ipairs(app:allWindows()) do
        if win:id() == lastMinimizedWindowID then
            -- Critical: only treat as "restored" if it was minimized.
            if win:isMinimized() then
                win:unminimize()
                win:focus()
                lastRestoredWindowID = win:id()
                return true
            end

            -- If it exists but is not minimized anymore, do not consume CMD+SHIFT+UP.
            return false
        end
    end

    return false
end

-- SHIFT+OPTION+DOWN → minimize focused window and remember it
hs.hotkey.bind({ "shift", "option" }, "down", function()
    local win = hs.window.focusedWindow()
    if not isWindowUsable(win) then return end

    lastMinimizedAppPID = win:application():pid()
    lastMinimizedWindowID = win:id()
    lastRestoredWindowID = nil

    win:minimize()
end)

-- SHIFT+OPTION+UP → restore if possible, otherwise maximize on repeat
hs.hotkey.bind({ "shift", "option" }, "up", function()
    -- 1) Restore last minimized window if it is currently minimized
    if restoreTrackedWindow() then
        return
    end

    -- 2) If there is nothing to restore, and we're still on the last restored window → maximize
    local focused = hs.window.focusedWindow()
    if focused and lastRestoredWindowID ~= nil and focused:id() == lastRestoredWindowID then
        focused:maximize()
        return
    end

    -- 3) Otherwise, default to maximize focused window
    if focused then
        focused:maximize()
    end
end)