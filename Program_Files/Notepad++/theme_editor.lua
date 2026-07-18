shell.run("LevelOS/startup/lUtils")

local config = {
    current = "Custom",
    themes = {
        ["Custom"] = {bg=colors.black, txt=colors.white, cursor=colors.red, keywords=colors.lightBlue, numbers=colors.yellow, comments=colors.lightGray, misc=colors.gray, misc2=colors.lightGray}
    }
}

local function loadThemeConfig()
    if fs.exists("AppData/NotepadPlusPlus/themes.lconf") then
        local f = fs.open("AppData/NotepadPlusPlus/themes.lconf", "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if data and data.themes and data.themes[data.current] then
            config = data
        end
    end
end
loadThemeConfig()

local theme = config.themes[config.current]

local properties = {
    { name = "Background", key = "bg" },
    { name = "Text Color", key = "txt" },
    { name = "Cursor Color", key = "cursor" },
    { name = "Keywords Color", key = "keywords" },
    { name = "Numbers Color", key = "numbers" },
    { name = "Comments Color", key = "comments" },
    { name = "UI Chrome Bg", key = "misc" },
    { name = "UI Chrome Text", key = "misc2" },
}

local selected_prop = 1

local colors_list = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768 }

local function draw()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clear()
    
    -- Draw list of properties
    for i=1,#properties do
        term.setCursorPos(2, i)
        if i == selected_prop then
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
        end
        local p = properties[i]
        local val = theme[p.key] or colors.white
        term.write(p.name .. string.rep(" ", 20 - #p.name))
        term.setBackgroundColor(val)
        term.write("   ")
    end
    
    -- Draw palette
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2, 10)
    term.write("Select Color:")
    
    -- Row 1 colors
    for i=1,8 do
        term.setCursorPos((i-1)*4 + 2, 11)
        term.setBackgroundColor(colors_list[i])
        term.write("   ")
    end
    -- Row 2 colors
    for i=9,16 do
        term.setCursorPos((i-9)*4 + 2, 12)
        term.setBackgroundColor(colors_list[i])
        term.write("   ")
    end
    
    -- Draw Save Button
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(8, 14)
    term.write("[ Save & Apply ]")
    
    -- Draw outer window border
    local w, h = term.getSize()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    lUtils.border(1, 1, w, h, nil, 3)
end

draw()
while true do
    local e = {os.pullEvent()}
    if e[1] == "mouse_click" and e[2] == 1 then
        local cx, cy = e[3], e[4]
        if cy >= 1 and cy <= #properties then
            selected_prop = cy
            draw()
        elseif cy == 11 then
            for i=1,8 do
                local bx = (i-1)*4 + 2
                if cx >= bx and cx <= bx+2 then
                    theme[properties[selected_prop].key] = colors_list[i]
                    draw()
                    break
                end
            end
        elseif cy == 12 then
            for i=9,16 do
                local bx = (i-9)*4 + 2
                if cx >= bx and cx <= bx+2 then
                    theme[properties[selected_prop].key] = colors_list[i]
                    draw()
                    break
                end
            end
        elseif cy == 14 and cx >= 8 and cx <= 24 then
            local f = fs.open("AppData/NotepadPlusPlus/themes.lconf", "w")
            f.write(textutils.serialize(config))
            f.close()
            os.queueEvent("notepad_theme_changed")
            lUtils.popup("Theme Editor", "Theme saved and applied!", 25, 9, {"OK"})
            draw()
        end
    elseif e[1] == "term_resize" then
        draw()
    end
end
