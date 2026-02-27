#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Close Slack Redirect Tabs
# @raycast.mode inline

# Conditional parameters:
# @raycast.refreshTime 10s

# Documentation:
# @raycast.author liamfoneill
# @raycast.authorURL https://raycast.com/liamfoneill

osascript <<EOD
tell application "Google Chrome"
    set windowList to every window
    repeat with theWindow in windowList
        set tabList to every tab of theWindow
        repeat with theTab in tabList
            if title of theTab is "Redirecting... | Slack" then
                delete theTab
            end if
        end repeat
    end repeat
end tell
EOD
