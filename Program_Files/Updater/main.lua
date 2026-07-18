-- DorpOS Updater App
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
    
    -- Draw outline borders
    term.setTextColor(tCol.border)
    lUtils.border(1, 1, w, h, nil, 3)
    
    -- Title
    term.setCursorPos(2, 2)
    term.setTextColor(colors.yellow)
    term.write("DorpOS Updater")
    
    -- Status text
    term.setCursorPos(2, 4)
    term.setTextColor(tCol.txt)
    term.write(string.sub(status or "Initializing...", 1, w - 3))
    
    -- Progress Bar
    local barWidth = w - 4
    local fillWidth = math.floor(barWidth * progress)
    if fillWidth < 0 then fillWidth = 0 end
    if fillWidth > barWidth then fillWidth = barWidth end
    
    term.setCursorPos(2, 6)
    term.setBackgroundColor(tCol.barBg)
    term.write(string.rep(" ", barWidth))
    
    term.setCursorPos(2, 6)
    term.setBackgroundColor(tCol.bar)
    term.write(string.rep(" ", fillWidth))
    
    term.setBackgroundColor(tCol.bg)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(2, 8)
    term.write(string.format("%d%% Complete", math.floor(progress * 100)))
end

-- Initial render
drawUI(0.05, "Connecting to GitHub...")

local installer_url = "https://raw.githubusercontent.com/TheDerpyMit/dorpapps/refs/heads/main/install_dorp.lua"
local res = http.get(installer_url)
if not res then
    lUtils.popup("Updater Error", "Failed to connect to GitHub! Check your Internet connection.", 29, 9, {"OK"})
    return
end
local code = res.readAll()
res.close()

drawUI(0.15, "Compiling installer...")
local installer_func, err = load(code, "installer", "t", _ENV)
if not installer_func then
    lUtils.popup("Updater Error", "Failed to compile updater payload!", 29, 9, {"OK"})
    return
end

-- Estimate total steps
local totalFiles = 0
for _ in string.gmatch(code, "files%[\"[^\"]+\"%]") do
    totalFiles = totalFiles + 1
end
local totalDownloads = 0
for _ in string.gmatch(code, "dest%s*=%s*\"[^\"]+\"") do
    totalDownloads = totalDownloads + 1
end
local totalOps = totalFiles + totalDownloads + 5
if totalOps <= 5 then totalOps = 15 end
local completedOps = 0

local function updateProgress(status)
    completedOps = completedOps + 1
    local progress = math.min(0.99, completedOps / totalOps)
    drawUI(progress, status)
    os.sleep(0.05)
end

-- Hijack process environment
local env = setmetatable({}, { __index = _G })
env.print = function(...) end
env.write = function(...) end

local oHttpGet = http.get
env.http = setmetatable({}, { __index = http })
env.http.get = function(url, headers, binary)
    local filename = fs.getName(url) or "asset"
    updateProgress("Downloading: " .. filename)
    return oHttpGet(url, headers, binary)
end

local oFsOpen = fs.open
env.fs = setmetatable({}, { __index = fs })
env.fs.open = function(path, mode)
    if mode == "w" or mode == "wb" then
        local filename = fs.getName(path) or "file"
        updateProgress("Writing: " .. filename)
    end
    return oFsOpen(path, mode)
end

-- Run update payload
local ok, run_err = pcall(function()
    setfenv(installer_func, env)
    installer_func()
end)

if ok then
    drawUI(1.0, "Update successful!")
    os.sleep(1)
    lUtils.popup("Updater", "All DorpOS apps have been successfully updated!", 29, 8, {"OK"})
else
    lUtils.popup("Updater Error", "Update failed: " .. tostring(run_err), 29, 10, {"OK"})
end
