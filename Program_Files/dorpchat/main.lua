-- Program_Files/dorpchat/main.lua
local tArgs = {...}

-- Check if we already have name and key (passed from command line)
if tArgs[1] then
    local key = tArgs[2] or "dorpchat_smp_secure_key_999"
    shell.run("Program_Files/dorpchat/dorpchat_core.lua", tArgs[1], key)
    return
end

shell.run("LevelOS/startup/lUtils")

local w, h = term.getSize()

local function drawGUI(nameVal)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clear()
    
    -- Title
    term.setCursorPos(math.ceil(w/2 - 4), 2)
    term.write("DorpChat")
    
    -- Name Field
    term.setCursorPos(3, 5)
    term.write("Enter your username:")
    term.setCursorPos(3, 6)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(nameVal .. string.rep(" ", w - 6 - #nameVal))
    
    -- Connect Button
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.white)
    term.setCursorPos(math.ceil(w/2 - 11), 10)
    term.write("[ Connect to DorpChat ]")
    
    -- Draw outer window border
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    lUtils.border(1, 1, w, h, nil, 3)
end

local nameVal = ""

drawGUI(nameVal)

while true do
    local e = {os.pullEvent()}
    if e[1] == "mouse_click" and e[2] == 1 then
        local cx, cy = e[3], e[4]
        -- Click on Connect button
        if cy == 10 and cx >= math.ceil(w/2 - 11) and cx <= math.ceil(w/2 + 11) then
            if #nameVal >= 2 then
                -- Start Dorpchat with the secure private key
                shell.run("Program_Files/dorpchat/dorpchat_core.lua", nameVal, "dorpchat_smp_secure_key_999")
                break
            else
                lUtils.popup("DorpChat", "Username is required!", 27, 9, {"OK"})
                drawGUI(nameVal)
            end
        end
    elseif e[1] == "char" then
        if #nameVal < 20 then
            nameVal = nameVal .. e[2]
        end
        drawGUI(nameVal)
    elseif e[1] == "key" then
        if e[2] == keys.backspace then
            nameVal = nameVal:sub(1, #nameVal - 1)
            drawGUI(nameVal)
        elseif e[2] == keys.enter then
            if #nameVal >= 2 then
                shell.run("Program_Files/dorpchat/dorpchat_core.lua", nameVal, "dorpchat_smp_secure_key_999")
                break
            else
                lUtils.popup("DorpChat", "Username is required!", 27, 9, {"OK"})
                drawGUI(nameVal)
            end
        end
    elseif e[1] == "term_resize" then
        w, h = term.getSize()
        drawGUI(nameVal)
    end
end
