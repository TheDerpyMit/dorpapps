-- Dorp Apps Custom Apps Installer
print("Dorp Apps Installer starting...")

local github_base = "https://raw.githubusercontent.com/TheDerpyMit/dorpapps/refs/heads/main/"

local downloads = {
    -- Notepad++
    { url = github_base .. "Program_Files/Notepad%2B%2B/main.lua", dest = "Program_Files/Notepad++/main.lua" },
    { url = github_base .. "Program_Files/Notepad%2B%2B/theme_editor.lua", dest = "Program_Files/Notepad++/theme_editor.lua" },
    { url = github_base .. "notepad_plus_icon.bimg", dest = "Program_Files/Notepad++/icon.bimg" },
    { url = github_base .. "notepad_plus_icon.bimg", dest = "Program_Files/Notepad++/taskbar.bimg" },
    
    -- DorpChat
    { url = github_base .. "Program_Files/dorpchat/main.lua", dest = "Program_Files/dorpchat/main.lua" },
    { url = github_base .. "Program_Files/dorpchat/dorpchat_core.lua", dest = "Program_Files/dorpchat/dorpchat_core.lua" },
    { url = github_base .. "dorpchat_icon.bimg", dest = "Program_Files/dorpchat/icon.bimg" },
    { url = github_base .. "dorpchat_icon.bimg", dest = "Program_Files/dorpchat/taskbar.bimg" },
    
    -- SysInfo
    { url = github_base .. "Program_Files/SysInfo/main.lua", dest = "Program_Files/SysInfo/main.lua" },
    { url = github_base .. "sysinfo_icon.bimg", dest = "Program_Files/SysInfo/icon.bimg" },
    { url = github_base .. "sysinfo_icon.bimg", dest = "Program_Files/SysInfo/taskbar.bimg" },
    
    -- Updater
    { url = github_base .. "Program_Files/Updater/main.lua", dest = "Program_Files/Updater/main.lua" },
    { url = github_base .. "dorp_updater_icon.bimg", dest = "Program_Files/Updater/icon.bimg" },
    { url = github_base .. "dorp_updater_icon.bimg", dest = "Program_Files/Updater/taskbar.bimg" },
    
    -- Music
    { url = github_base .. "music.lua", dest = "Program_Files/Music/main.lua" },
    { url = github_base .. "music_icon.bimg", dest = "Program_Files/Music/icon.bimg" },
    { url = github_base .. "music_icon.bimg", dest = "Program_Files/Music/taskbar.bimg" },
    
    -- Gelbooru
    { url = github_base .. "Program_Files/Gelbooru/main.lua", dest = "Program_Files/Gelbooru/main.lua" },
    { url = github_base .. "Program_Files/Gelbooru/icon.bimg", dest = "Program_Files/Gelbooru/icon.bimg" },
    { url = github_base .. "Program_Files/Gelbooru/taskbar.bimg", dest = "Program_Files/Gelbooru/taskbar.bimg" },
    { url = github_base .. "Program_Files/Gelbooru/monrun.lua", dest = "Program_Files/Gelbooru/monrun.lua" },
    
    -- Wallpaper
    { url = github_base .. "desktop.nfp", dest = "User/Images/desktop.nfp" }
}

for _, dl in ipairs(downloads) do
    local dir = fs.getDir(dl.dest)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    print("  Downloading: " .. dl.dest)
    local res = http.get(dl.url .. "?cb=" .. math.random(1, 100000), nil, true) -- binary download mode
    if res then
        local f = fs.open(dl.dest, "wb")
        f.write(res.readAll())
        f.close()
        res.close()
    else
        print("  Error: Failed to download " .. dl.url)
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

local shortcuts = {
    { name = "Notepad++.llnk", target = "Program_Files/Notepad++/main.lua" },
    { name = "DorpChat.llnk", target = "Program_Files/dorpchat/main.lua" },
    { name = "SysInfo.llnk", target = "Program_Files/SysInfo/main.lua" },
    { name = "Music.llnk", target = "Program_Files/Music/main.lua" },
    { name = "Updater.llnk", target = "Program_Files/Updater/main.lua" },
    { name = "Gelbooru.llnk", target = "Program_Files/Gelbooru/main.lua" }
}

for _, sc in ipairs(shortcuts) do
    local linkPath = fs.combine(desktopDir, sc.name)
    local f = fs.open(linkPath, "w")
    f.write(textutils.serialize({ sc.target }))
    f.close()
    print("  Created Shortcut: " .. linkPath)
end

print("\nInstallation complete!")
print("Restart LevelOS or check your Desktop to see the new apps!")
