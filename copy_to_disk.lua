-- copy_to_disk.lua
-- Run this on the computer containing the custom apps to create an installation floppy disk!

local diskPath = nil
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" then
        local drive = peripheral.wrap(name)
        if drive.isDiskPresent() then
            diskPath = drive.getMountPath()
            break
        end
    end
end

if not diskPath then
    print("Error: No floppy disk found! Please put a disk drive next to this computer and insert a floppy disk.")
    return
end

print("Found floppy disk mounted at: /" .. diskPath)

-- Clean and recreate app directory on the disk
local destDir = fs.combine(diskPath, "DorpOS_Apps")
if fs.exists(destDir) then
    fs.delete(destDir)
end
fs.makeDir(destDir)

-- List of files to copy
local files = {
    -- Notepad++
    ["Program_Files/Notepad++/main.lua"] = "NotepadPlusPlus/main.lua",
    ["Program_Files/Notepad++/theme_editor.lua"] = "NotepadPlusPlus/theme_editor.lua",
    ["Program_Files/Notepad++/icon.bimg"] = "NotepadPlusPlus/icon.bimg",
    ["Program_Files/Notepad++/taskbar.bimg"] = "NotepadPlusPlus/taskbar.bimg",
    -- DorpChat
    ["Program_Files/dorpchat/main.lua"] = "dorpchat/main.lua",
    ["Program_Files/dorpchat/dorpchat_core.lua"] = "dorpchat/dorpchat_core.lua",
    ["Program_Files/dorpchat/icon.bimg"] = "dorpchat/icon.bimg",
    ["Program_Files/dorpchat/taskbar.bimg"] = "dorpchat/taskbar.bimg",
    -- SysInfo
    ["Program_Files/SysInfo/main.lua"] = "SysInfo/main.lua",
    ["Program_Files/SysInfo/icon.bimg"] = "SysInfo/icon.bimg",
    ["Program_Files/SysInfo/taskbar.bimg"] = "SysInfo/taskbar.bimg",
    -- Updater
    ["Program_Files/Updater/main.lua"] = "Updater/main.lua",
    ["dorp_updater_icon.bimg"] = "Updater/icon.bimg",
    -- Music
    ["music.lua"] = "Music/main.lua",
    ["music_icon.bimg"] = "Music/icon.bimg",
    ["music_icon.bimg"] = "Music/taskbar.bimg",
    -- Gelbooru
    ["Program_Files/Gelbooru/main.lua"] = "Gelbooru/main.lua",
    ["Program_Files/Gelbooru/icon.bimg"] = "Gelbooru/icon.bimg",
    ["Program_Files/Gelbooru/taskbar.bimg"] = "Gelbooru/taskbar.bimg",
    ["Program_Files/Gelbooru/monrun.lua"] = "Gelbooru/monrun.lua",
    -- Store Manager
    ["Program_Files/StoreManager/main.lua"] = "StoreManager/main.lua",
    ["Program_Files/StoreManager/icon.bimg"] = "StoreManager/icon.bimg",
    ["Program_Files/StoreManager/taskbar.bimg"] = "StoreManager/taskbar.bimg",
    -- Wallpaper
    ["desktop.nfp"] = "desktop.nfp"
}

print("Copying custom app files to disk...")
for src_rel, dest_rel in pairs(files) do
    local src = src_rel
    local dest = fs.combine(destDir, dest_rel)
    local dest_folder = fs.getDir(dest)
    if not fs.exists(dest_folder) then
        fs.makeDir(dest_folder)
    end
    
    -- Handle taskbar duplicating in copy
    if src_rel == "dorp_updater_icon.bimg" then
        if fs.exists(src) then
            fs.copy(src, dest)
            fs.copy(src, fs.combine(dest_folder, "taskbar.bimg"))
            print("  Copied Updater Icons")
        end
    else
        if fs.exists(src) then
            fs.copy(src, dest)
            print("  Copied " .. src_rel)
        else
            print("  Warning: Source file " .. src .. " not found!")
        end
    end
end

-- Write installer onto the disk
local installerPath = fs.combine(diskPath, "install.lua")
local installerCode = [[
-- DorpOS Custom Apps Installer Disk
print("Installing custom apps onto this computer...")

local diskPath = shell.getRunningProgram():match("^(.-)/install%.lua$") or "disk"
local srcDir = fs.combine(diskPath, "DorpOS_Apps")

if not fs.exists(srcDir) then
    print("Error: Source files not found on disk at " .. srcDir)
    return
end

-- Create Program_Files directory if needed
if not fs.exists("Program_Files") then
    fs.makeDir("Program_Files")
end

-- Files mapping to copy
local files = {
    ["NotepadPlusPlus/main.lua"] = "Program_Files/Notepad++/main.lua",
    ["NotepadPlusPlus/theme_editor.lua"] = "Program_Files/Notepad++/theme_editor.lua",
    ["NotepadPlusPlus/icon.bimg"] = "Program_Files/Notepad++/icon.bimg",
    ["NotepadPlusPlus/taskbar.bimg"] = "Program_Files/Notepad++/taskbar.bimg",
    ["dorpchat/main.lua"] = "Program_Files/dorpchat/main.lua",
    ["dorpchat/dorpchat_core.lua"] = "Program_Files/dorpchat/dorpchat_core.lua",
    ["dorpchat/icon.bimg"] = "Program_Files/dorpchat/icon.bimg",
    ["dorpchat/taskbar.bimg"] = "Program_Files/dorpchat/taskbar.bimg",
    ["SysInfo/main.lua"] = "Program_Files/SysInfo/main.lua",
    ["SysInfo/icon.bimg"] = "Program_Files/SysInfo/icon.bimg",
    ["SysInfo/taskbar.bimg"] = "Program_Files/SysInfo/taskbar.bimg",
    ["Updater/main.lua"] = "Program_Files/Updater/main.lua",
    ["Updater/icon.bimg"] = "Program_Files/Updater/icon.bimg",
    ["Updater/taskbar.bimg"] = "Program_Files/Updater/taskbar.bimg",
    ["Music/main.lua"] = "Program_Files/Music/main.lua",
    ["Music/icon.bimg"] = "Program_Files/Music/icon.bimg",
    ["Music/taskbar.bimg"] = "Program_Files/Music/taskbar.bimg",
    ["Gelbooru/main.lua"] = "Program_Files/Gelbooru/main.lua",
    ["Gelbooru/icon.bimg"] = "Program_Files/Gelbooru/icon.bimg",
    ["Gelbooru/taskbar.bimg"] = "Program_Files/Gelbooru/taskbar.bimg",
    ["Gelbooru/monrun.lua"] = "Program_Files/Gelbooru/monrun.lua",
    ["StoreManager/main.lua"] = "Program_Files/StoreManager/main.lua",
    ["StoreManager/icon.bimg"] = "Program_Files/StoreManager/icon.bimg",
    ["StoreManager/taskbar.bimg"] = "Program_Files/StoreManager/taskbar.bimg",
    ["desktop.nfp"] = "User/Images/desktop.nfp"
}

for src_rel, dest_rel in pairs(files) do
    local src = fs.combine(srcDir, src_rel)
    local dest = dest_rel
    local dest_folder = fs.getDir(dest)
    if not fs.exists(dest_folder) then
        fs.makeDir(dest_folder)
    end
    if fs.exists(dest) then
        fs.delete(dest)
    end
    if fs.exists(src) then
        fs.copy(src, dest)
        print("  Installed: " .. dest_rel)
    else
        print("  Error: Missing " .. src_rel)
    end
end

-- Set desktop wallpaper
local lconfPath = "LevelOS/data/desktop.lconf"
local dConfig = {
    _VERSION = 1,
    files = {},
    sizes = {},
    shortcutIcon = true,
    background = { path = "User/Images/desktop.nfp", resize = "stretch" }
}

if fs.exists(lconfPath) then
    local f = fs.open(lconfPath, "r")
    local val = textutils.unserialize(f.readAll())
    f.close()
    if val then
        dConfig = val
        dConfig.background = { path = "User/Images/desktop.nfp", resize = "stretch" }
    end
else
    local dir = fs.getDir(lconfPath)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local f = fs.open(lconfPath, "w")
f.write(textutils.serialize(dConfig))
f.close()
print("  Set LevelOS Desktop Wallpaper to: User/Images/desktop.nfp")

-- Create desktop shortcuts
local desktopDir = "User/Desktop"
if not fs.exists(desktopDir) then
    fs.makeDir(desktopDir)
end

-- Notepad++ Link
local nppLink = fs.combine(desktopDir, "Notepad++.llnk")
local f1 = fs.open(nppLink, "w")
f1.write('{ "Program_Files/Notepad++/main.lua" }')
f1.close()
print("  Created Shortcut: " .. nppLink)

-- DorpChat Link
local dcLink = fs.combine(desktopDir, "DorpChat.llnk")
local f2 = fs.open(dcLink, "w")
f2.write('{ "Program_Files/dorpchat/main.lua" }')
f2.close()
print("  Created Shortcut: " .. dcLink)

-- SysInfo Link
local siLink = fs.combine(desktopDir, "SysInfo.llnk")
local f3 = fs.open(siLink, "w")
f3.write('{ "Program_Files/SysInfo/main.lua" }')
f3.close()
print("  Created Shortcut: " .. siLink)

-- Music Link
local musicLink = fs.combine(desktopDir, "Music.llnk")
local f4 = fs.open(musicLink, "w")
f4.write('{ "Program_Files/Music/main.lua" }')
f4.close()
print("  Created Shortcut: " .. musicLink)

-- Updater Link
local updaterLink = fs.combine(desktopDir, "Updater.llnk")
local f5 = fs.open(updaterLink, "w")
f5.write('{ "Program_Files/Updater/main.lua" }')
f5.close()
print("  Created Shortcut: " .. updaterLink)

-- Gelbooru Link
local gelbooruLink = fs.combine(desktopDir, "Gelbooru.llnk")
local f6 = fs.open(gelbooruLink, "w")
f6.write('{ "Program_Files/Gelbooru/main.lua" }')
f6.close()
print("  Created Shortcut: " .. gelbooruLink)

-- Store Manager Link
local storeManagerLink = fs.combine(desktopDir, "Store Manager.llnk")
local f7 = fs.open(storeManagerLink, "w")
f7.write('{ "Program_Files/StoreManager/main.lua" }')
f7.close()
print("  Created Shortcut: " .. storeManagerLink)

print("\nInstallation successful!")
]]

local f = fs.open(installerPath, "w")
f.write(installerCode)
f.close()

print("Installer written to: /" .. installerPath)
print("Done! You can now take the floppy disk to any computer and run: /" .. diskPath .. "/install")
