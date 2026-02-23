# Raycast Configuration

Raycast doesn't support symlinked config files, so settings must be exported and imported manually.

## Exporting Settings (source machine)

1. Open **Raycast** (Cmd+Space or your configured hotkey)
2. Go to **Settings** (Cmd+,) > **Advanced**
3. Click **Export Settings & Data**
4. Optionally set an export password in Settings > Advanced > Export Password
5. Save the `.rayconfig` file to this directory as `Raycast.rayconfig`
6. Commit and push

## Importing Settings (target machine)

1. Install Raycast (included in the Brewfile or via `brew install --cask raycast`)
2. Open **Raycast** > **Settings** > **Advanced**
3. Click **Import Settings & Data**
4. Select the `Raycast.rayconfig` file from this directory
5. Enter the export password if one was set

## What's Included

The `.rayconfig` export contains:

- Quicklinks and snippets
- Extension settings and hotkeys
- Aliases and preferences
- Window management settings

## What's NOT Included

- Extension data that requires authentication (re-login required)
- System-level permissions (grant manually after import)
