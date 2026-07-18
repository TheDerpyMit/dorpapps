-- Program_Files/SysInfo/main.lua
shell.run("LevelOS/startup/lUtils")

local w, h = term.getSize()

-- Color palette matching SysInfo theme
local bg = colors.gray
local fg = colors.white
local labelCol = colors.lightGray
local activeCol = colors.lime
local inactiveCol = colors.red

local function formatBytes(bytes)
    if bytes >= 1024 * 1024 then
        return string.format("%.2f MB", bytes / (1024 * 1024))
    elseif bytes >= 1024 then
        return string.format("%.2f KB", bytes / 1024)
    else
        return bytes .. " B"
    end
end

local function drawInfo()
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.clear()
    
    -- Title
    term.setCursorPos(math.ceil(w/2 - 6), 2)
    term.setTextColor(colors.white)
    term.write("About Your PC")
    
    -- Horizontal separator line
    term.setCursorPos(2, 3)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", w - 2))
    
    local specs = {
        { label = "Computer ID:", val = tostring(os.getComputerID()) },
        { label = "Label:", val = os.getComputerLabel() or "Unnamed" },
        { label = "OS Version:", val = _HOST or "CraftOS" },
        { label = "Lua Engine:", val = _VERSION .. (jit and " (JIT)" or "") },
        { label = "Free Disk:", val = formatBytes(fs.getFreeSpace("/")) },
    }
    
    local y = 5
    for _, spec in ipairs(specs) do
        term.setCursorPos(3, y)
        term.setTextColor(labelCol)
        term.write(spec.label)
        term.setCursorPos(18, y)
        term.setTextColor(fg)
        term.write(spec.val)
        y = y + 1
    end
    
    -- Separator
    term.setCursorPos(2, y + 1)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", w - 2))
    
    term.setCursorPos(3, y + 3)
    term.setTextColor(fg)
    term.write("Peripherals Connection:")
    
    local peripherals = {
        { name = "Speaker", type = "speaker" },
        { name = "Printer", type = "printer" },
        { name = "Modem", type = "modem" },
        { name = "Disk Drive", type = "drive" },
        { name = "Monitor", type = "monitor" },
    }
    
    y = y + 5
    for _, p in ipairs(peripherals) do
        local connected = peripheral.find(p.type) ~= nil
        term.setCursorPos(3, y)
        term.setTextColor(labelCol)
        term.write(p.name .. ":")
        
        term.setCursorPos(18, y)
        if connected then
            term.setTextColor(activeCol)
            term.write("\7 Connected")
        else
            term.setTextColor(inactiveCol)
            term.write("\7 Disconnected")
        end
        y = y + 1
    end

    -- Draw outer window border
    term.setTextColor(colors.lightGray)
    lUtils.border(1, 1, w, h, nil, 3)
end

drawInfo()

while true do
    local e = {os.pullEvent()}
    if e[1] == "term_resize" then
        w, h = term.getSize()
        drawInfo()
    elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
        drawInfo()
    elseif e[1] == "mouse_click" or e[1] == "key" then
        drawInfo()
    end
end
