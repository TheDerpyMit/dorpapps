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
    
    -- DorpPOS
    { url = github_base .. "Program_Files/DorpPOS/main.lua", dest = "Program_Files/DorpPOS/main.lua" },
    { url = github_base .. "Program_Files/DorpPOS/icon.bimg", dest = "Program_Files/DorpPOS/icon.bimg" },
    { url = github_base .. "Program_Files/DorpPOS/taskbar.bimg", dest = "Program_Files/DorpPOS/taskbar.bimg" },

    -- Gmail / Email
    { url = github_base .. "Program_Files/Email/main.lua", dest = "Program_Files/Email/main.lua" },
    { url = github_base .. "Program_Files/Email/email_core.lua", dest = "Program_Files/Email/email_core.lua" },
    { url = github_base .. "Program_Files/Email/email_server.lua", dest = "Program_Files/Email/email_server.lua" },
    { url = github_base .. "Program_Files/Email/icon.bimg", dest = "Program_Files/Email/icon.bimg" },
    { url = github_base .. "Program_Files/Email/taskbar.bimg", dest = "Program_Files/Email/taskbar.bimg" },
    
    -- LevelOS Core Patches
    { url = github_base .. "LevelOS/startup/lUtils.lua", dest = "LevelOS/startup/lUtils.lua" },
    
    -- Wallpaper
    { url = github_base .. "desktop.nfp", dest = "User/Images/desktop.nfp" }
}

-- Wipe old app directories to ensure clean install
print("  Wiping old app versions...")
local wipeDirs = {
    "Program_Files/Notepad++",
    "Program_Files/dorpchat",
    "Program_Files/SysInfo",
    "Program_Files/Music",
    "Program_Files/Updater",
    "Program_Files/DorpPOS",
    "Program_Files/Email",
    "Program_Files/StoreManager",
}
for _, dir in ipairs(wipeDirs) do
    if fs.exists(dir) then
        fs.delete(dir)
    end
end

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

-- Delete old removed app shortcuts
local oldShortcuts = { "Gelbooru.llnk", "Gelbooru.lnk" }
for _, oldSc in ipairs(oldShortcuts) do
    local oldPath = fs.combine(desktopDir, oldSc)
    if fs.exists(oldPath) then
        fs.delete(oldPath)
        print("  Removed Old Shortcut: " .. oldPath)
    end
end

local shortcuts = {
    { name = "Notepad++.llnk", target = "Program_Files/Notepad++/main.lua" },
    { name = "DorpChat.llnk", target = "Program_Files/dorpchat/main.lua" },
    { name = "SysInfo.llnk", target = "Program_Files/SysInfo/main.lua" },
    { name = "Music.llnk", target = "Program_Files/Music/main.lua" },
    { name = "Updater.llnk", target = "Program_Files/Updater/main.lua" },
    { name = "DorpPOS.llnk", target = "Program_Files/DorpPOS/main.lua" },
    { name = "Gmail.llnk", target = "Program_Files/Email/main.lua" }
}

for _, sc in ipairs(shortcuts) do
    local linkPath = fs.combine(desktopDir, sc.name)
    local f = fs.open(linkPath, "w")
    f.write(textutils.serialize({ sc.target }))
    f.close()
    print("  Created Shortcut: " .. linkPath)
end

-- Modify LevelOS core files (Changelogs & Login screen description)
print("  Applying DorpOS branding modifications...")

-- 1. Modify changelogs
for _, path in ipairs({"LevelOS/data/changelog.lconf", "LevelOS/data/nativelog.lconf"}) do
    if fs.exists(path) then
        local f = fs.open(path, "r")
        local data = textutils.unserialize(f.readAll() or "")
        f.close()
        if type(data) == "table" then
            local alreadyDone = false
            for _, entry in ipairs(data) do
                if entry.version == "DorpOS" or entry.description == "Modified with dorpapps by Mit" then
                    alreadyDone = true
                    break
                end
            end
            if not alreadyDone then
                table.insert(data, {
                    date = os.date and os.date("%d-%m-%Y") or "19-07-2026",
                    version = "DorpOS",
                    description = "Modified with dorpapps by Mit",
                    added = {
                        "DorpPOS app installed",
                        "Gelbooru app installed",
                        "DorpChat integrated",
                        "Music shortcuts set up",
                    },
                    fixed = {
                        "Integrated all custom dorpapps cleanly",
                    }
                })
                local f2 = fs.open(path, "w")
                f2.write(textutils.serialize(data))
                f2.close()
                print("    Updated changelog: " .. path)
            end
        end
    end
end

-- 2. Modify Login_screen.sgui
local loginScreenPath = "LevelOS/Login_screen.sgui"
if fs.exists(loginScreenPath) then
    local f = fs.open(loginScreenPath, "r")
    local content = f.readAll()
    f.close()
    
    local replacement = "This version of LevelOS is heavily modified to suit the DorpSMP needs."
    local modified = false
    
    -- Target standard text
    local target1 = "The ultimate multitasking OS. With LevelOS, you can accomplish anything."
    local target2 = "The ultimate multitasking os.. crap"
    
    if content:find(target1, 1, true) then
        content = content:gsub(target1, replacement)
        modified = true
    elseif content:find(target2, 1, true) then
        content = content:gsub(target2, replacement)
        modified = true
    else
        -- Broad match pattern fallback
        local pattern = "The ultimate multitasking[^\"\\]+"
        if content:find(pattern) then
            content = content:gsub(pattern, replacement)
            modified = true
        end
    end
    
    if modified then
        local f2 = fs.open(loginScreenPath, "w")
        f2.write(content)
        f2.close()
        print("    Updated login screen description")
    end
end

print("\nInstallation complete!")
print("Rebooting computer in 2 seconds to restart LevelOS...")
os.sleep(2)
os.reboot()
