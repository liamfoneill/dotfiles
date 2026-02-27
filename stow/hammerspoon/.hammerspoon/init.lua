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

--------------------------------------------------------------------------------
-- File Mover — auto-move new files by extension (mini Hazel)
--------------------------------------------------------------------------------
--
-- Add rules to the fileMoverRules table below. Each rule needs:
--   source    = watched directory (tilde is expanded)
--   dest      = destination directory
--   ext       = file extension to match (with or without leading dot)
--   notify    = (optional, default true) show a macOS notification on move
--
-- Example:
--   { source = "~/Downloads", dest = "~/Documents/PDFs", ext = ".pdf" },
--   { source = "~/Desktop",   dest = "~/Pictures/Screenshots", ext = "png", notify = false },

local fileMoverRules = {
    {
        source = "/Users/liamoneill/Library/CloudStorage/GoogleDrive-liamoneill@stripe.com/My Drive/Pictures/Screenshots",
        dest   = "/Users/liamoneill/Screen Recordings",
        ext    = ".mp4",
    },
}

local fileMoverTempExts = { ".part", ".crdownload", ".tmp", ".download", ".partial" }

local function fileMoverExpandPath(path)
    if path:sub(1, 1) == "~" then
        return os.getenv("HOME") .. path:sub(2)
    end
    return path
end

local function fileMoverNormalizeExt(ext)
    ext = ext:lower()
    if ext:sub(1, 1) ~= "." then ext = "." .. ext end
    return ext
end

local function fileMoverIsTempExt(ext)
    for _, tmp in ipairs(fileMoverTempExts) do
        if ext:lower() == tmp then return true end
    end
    return false
end

local function fileMoverSafeDest(destDir, filename)
    local target = destDir .. "/" .. filename
    if not hs.fs.attributes(target) then return target end

    local name, extension = filename:match("^(.+)(%.%w+)$")
    if not name then
        name = filename
        extension = ""
    end

    local counter = 1
    while true do
        local candidate = destDir .. "/" .. name .. " (" .. counter .. ")" .. extension
        if not hs.fs.attributes(candidate) then return candidate end
        counter = counter + 1
    end
end

local function fileMoverProcessFile(filePath, rule)
    local filename = filePath:match("([^/]+)$")
    if not filename then return end

    local ext = filename:match("(%.%w+)$")
    if not ext then return end

    if fileMoverIsTempExt(ext) then return end
    if ext:lower() ~= rule._ext then return end

    hs.timer.doAfter(0.5, function()
        local attrs = hs.fs.attributes(filePath)
        if not attrs or attrs.mode == "directory" then return end

        local destPath = fileMoverSafeDest(rule._dest, filename)
        local ok, err = os.rename(filePath, destPath)
        if ok then
            print("[File Mover] Moved " .. filename .. " → " .. destPath)
            if rule.notify ~= false then
                hs.notify.show("File Mover", "", "Moved " .. filename)
            end
        else
            print("[File Mover] Failed to move " .. filename .. ": " .. tostring(err))
        end
    end)
end

local fileMoverWatchers = {}

for _, rule in ipairs(fileMoverRules) do
    local src = fileMoverExpandPath(rule.source)
    local dest = fileMoverExpandPath(rule.dest)
    rule._ext = fileMoverNormalizeExt(rule.ext)
    rule._dest = dest

    if hs.fs.attributes(src, "mode") ~= "directory" then
        print("[File Mover] Warning: source does not exist: " .. src)
    elseif hs.fs.attributes(dest, "mode") ~= "directory" then
        print("[File Mover] Warning: destination does not exist: " .. dest)
    else
        local watcher = hs.pathwatcher.new(src, function(paths)
            for _, path in ipairs(paths) do
                fileMoverProcessFile(path, rule)
            end
        end)
        watcher:start()
        table.insert(fileMoverWatchers, watcher)
        print("[File Mover] Watching " .. src .. " for *" .. rule._ext .. " → " .. dest)
    end
end