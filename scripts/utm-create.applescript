-- Create UTM VM for NixOS
-- Usage: osascript scripts/utm-create.applescript /path/to/nixos.iso "VM Name"

on run argv
    set isoPath to item 1 of argv
    set vmName to item 2 of argv

    -- Convert to alias/file reference that AppleScript understands
    set isoFile to POSIX file isoPath

    tell application "UTM"
        -- Create VM with Apple backend (uses Apple Virtualization Framework)
        -- drives: first is removable ISO, second is 60GB main disk
        set vm to make new virtual machine with properties {backend:apple, configuration:{name:vmName, architecture:"aarch64", drives:{{removable:true, source:isoFile}, {guest size:61440}}}}
    end tell
end run
