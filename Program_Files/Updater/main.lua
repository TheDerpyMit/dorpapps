-- DorpOS Universal Updater App
-- Dynamically updates all current and future DorpApps directly from GitHub repository

if not _G.lUtils then shell.run("LevelOS/startup/lUtils") end

local w, h = term.getSize()
local theme = {}
if fs.exists("AppData/NotepadPlusPlus/themes.lconf") then
    local f = fs.open("AppData/NotepadPlusPlus/themes.lconf", "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    if data and data.themes and data.themes[data.current] then
        theme = data.themes[data.current]
    end
end

local tCol = {
    bg = theme.bg or colors.black,
    txt = theme.txt or colors.white,
    bar = colors.lime,
    barBg = colors.gray,
    border = theme.misc2 or colors.lightGray
}

local function drawUI(progress, status)
    term.setBackgroundColor(tCol.bg)
    term.clear()
    
    -- Outline borders
    term.setTextColor(tCol.border)
    lUtils.border(1, 1, w, h, nil, 3)
    
    -- Title
    term.setCursorPos(2, 2)
    term.setTextColor(colors.yellow)
    term.write("DorpOS Universal App Updater")
    
    -- Status text
    term.setCursorPos(2, 4)
    term.setTextColor(tCol.txt)
    local statusText = status or "Initializing..."
    if #statusText > (w - 3) then
        statusText = statusText:sub(1, w - 6) .. "..."
    end
    term.write(statusText .. string.rep(" ", w - 3 - #statusText))
    
    -- Progress Bar
    local barWidth = w - 4
    local fillWidth = math.floor(barWidth * math.min(1.0, math.max(0.0, progress)))
    
    term.setCursorPos(2, 6)
    term.setBackgroundColor(tCol.barBg)
    term.write(string.rep(" ", barWidth))
    
    if fillWidth > 0 then
        term.setCursorPos(2, 6)
        term.setBackgroundColor(tCol.bar)
        term.write(string.rep(" ", fillWidth))
    end
    
    term.setBackgroundColor(tCol.bg)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(2, 8)
    term.write(string.format("%d%% Complete", math.floor(progress * 100)))
end

-- Initial render
drawUI(0.02, "Connecting to GitHub repository...")

-- Fetch installer manifest with cache-busting
local manifest_url = "https://raw.githubusercontent.com/TheDerpyMit/dorpapps/main/install_dorp.lua"
local headers = {
    ["Cache-Control"] = "no-cache, no-store, must-revalidate",
    ["Pragma"] = "no-cache"
}
local ts = (os.epoch and os.epoch("utc")) or math.random(100000, 999999)
local res = http.get(manifest_url .. "?ts=" .. ts .. "_" .. math.random(1000, 9999), headers)

if not res then
    lUtils.popup("Updater Error", "Failed to connect to GitHub repository!\nCheck your ComputerCraft HTTP settings.", 36, 9, {"OK"})
    return
end

local installer_code = res.readAll()
res.close()

drawUI(0.10, "Parsing update manifest...")
local installer_func, err = load(installer_code, "installer", "t", _ENV)
if not installer_func then
    lUtils.popup("Updater Error", "Failed to compile update payload:\n" .. tostring(err), 34, 9, {"OK"})
    return
end

-- Estimate total operations for progress calculation
local totalOps = 0
for _ in installer_code:gmatch("dest%s*=%s*\"[^\"]+\"") do
    totalOps = totalOps + 1
end
if totalOps == 0 then totalOps = 15 end

local completedOps = 0

local function updateProgress(status)
    completedOps = completedOps + 1
    local progress = math.min(0.98, completedOps / (totalOps + 3))
    drawUI(progress, status)
    os.sleep(0.02)
end

-- Intercept execution environment
local env = setmetatable({}, { __index = _G })

-- Override print/write so terminal output doesn't corrupt GUI
env.print = function(...) end
env.write = function(...) end

-- Intercept HTTP downloads to update progress bar
local oHttpGet = http.get
env.http = setmetatable({}, { __index = http })
env.http.get = function(url, reqHeaders, binary)
    local filename = fs.getName(url) or "file"
    if filename:find("%?") then
        filename = filename:sub(1, filename:find("%?") - 1)
    end
    updateProgress("Downloading: " .. filename)
    return oHttpGet(url, reqHeaders, binary)
end

-- Intercept File writing to update progress bar
local oFsOpen = fs.open
env.fs = setmetatable({}, { __index = fs })
env.fs.open = function(path, mode)
    if mode == "w" or mode == "wb" then
        local filename = fs.getName(path) or "file"
        updateProgress("Installing: " .. filename)
    end
    return oFsOpen(path, mode)
end

-- Intercept os.reboot so updater can show success screen before reboot
local shouldReboot = false
env.os = setmetatable({}, { __index = os })
env.os.reboot = function()
    shouldReboot = true
end

-- Execute update payload
local ok, run_err = pcall(function()
    setfenv(installer_func, env)
    installer_func()
end)

if ok then
    drawUI(1.0, "All apps updated successfully!")
    os.sleep(0.5)
    _G.lUtils.popup("DorpOS Updater", "All current & new DorpApps have been updated!\nSystem will now reboot.", 36, 9, {"OK"})
    if shouldReboot then
        os.reboot()
    end
else
    lUtils.popup("Updater Error", "Update failed:\n" .. tostring(run_err), 32, 10, {"OK"})
end
