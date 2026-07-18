local tArgs = {...}
local tFilepath = ""
if tArgs[1] ~= nil then
    tFilepath = tArgs[1]
end
local isReadOnly = false
if tArgs[2] ~= nil and tArgs[2] == "true" then
	isReadOnly = true
end

-- Default Theme Configuration
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
    else
        fs.makeDir("AppData")
        fs.makeDir("AppData/NotepadPlusPlus")
        local f = fs.open("AppData/NotepadPlusPlus/themes.lconf", "w")
        f.write(textutils.serialize(config))
        f.close()
    end
end
local isHighlightEnabled = true
local isPrinterMode = false



local theme = config.themes[config.current]
local tCol = {
    bg = theme.bg,
    txt = theme.txt,
    misc = theme.misc,
    misc2 = theme.misc2
}

local btns = {{"File",{{"New","Open...","Save","Save as..."},"Print","Quit"}},{"Edit",{"Undo",{"Search","Replace"},"Center Align","Time"}},{"View",{"Theme Editor", "Highlighting: On", "Printer Mode: Off"}}}

local function topbar()
    local w,h = term.getSize()
    local theline = string.rep("\131", w-1)
    term.setCursorPos(1,1)
    term.setBackgroundColor(tCol.bg)
    term.setTextColor(tCol.misc)
    term.clearLine()
    term.setCursorPos(1,2)
    term.write(theline)
    term.setCursorPos(1,1)
    term.setTextColor(tCol.txt)
    
    -- Dynamically update View submenu strings
    btns[3][2][2] = isHighlightEnabled and "Highlighting: On" or "Highlighting: Off"
    btns[3][2][3] = isPrinterMode and "Printer Mode: On" or "Printer Mode: Off"
    
    for t=1,#btns do
        btns[t].x = ({term.getCursorPos()})[1]
        btns[t].w = string.len(btns[t][1])+2
        term.write(" "..btns[t][1].." ")
    end
end

local w,h = term.getSize()
local a = {}

local pages = { { "" } }
local currentPage = 1

local function splitToPrinterWidth(linesList)
    local wrapped = {}
    for _, line in ipairs(linesList) do
        local wl = lUtils.wordwrap(line, 25)
        if #wl == 0 then
            table.insert(wrapped, "")
        else
            for _, wLine in ipairs(wl) do
                table.insert(wrapped, wLine)
            end
        end
    end
    return wrapped
end

local function linesToPages(linesList)
    local localPages = {}
    local currPage = {}
    for i, line in ipairs(linesList) do
        table.insert(currPage, line)
        if #currPage == 21 then
            table.insert(localPages, currPage)
            currPage = {}
        end
    end
    if #currPage > 0 or #localPages == 0 then
        table.insert(localPages, currPage)
    end
    return localPages
end

local function pagesToLines(localPages)
    local linesList = {}
    for _, page in ipairs(localPages) do
        for _, line in ipairs(page) do
            table.insert(linesList, line)
        end
    end
    if #linesList == 0 then
        linesList = {""}
    end
    return linesList
end



local function drawPageControls()
    local w,h = term.getSize()
    term.setCursorPos(1, h-2)
    term.setBackgroundColor(tCol.misc)
    term.setTextColor(tCol.txt)
    term.clearLine()
    
    local text = string.format(" Page %d of %d ", currentPage, #pages)
    
    term.setCursorPos(2, h-2)
    term.setBackgroundColor(currentPage > 1 and colors.lightGray or colors.gray)
    term.setTextColor(currentPage > 1 and colors.black or colors.lightGray)
    term.write("[<]")
    
    term.setCursorPos(6, h-2)
    term.setBackgroundColor(currentPage < #pages and colors.lightGray or colors.gray)
    term.setTextColor(currentPage < #pages and colors.black or colors.lightGray)
    term.write("[>]")
    
    term.setCursorPos(11, h-2)
    term.setBackgroundColor(tCol.misc)
    term.setTextColor(tCol.txt)
    term.write(text)
    
    term.setCursorPos(w - 23, h-2)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write("[+ Page]")
    
    term.setCursorPos(w - 13, h-2)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write("[- Page]")
end

local function txt()
    a = {{width=w-1,height=h-4,sTable={},filepath="",lines={""},changed=false},0,0,1,1}
	if tFilepath ~= "" then
		if fs.exists(tFilepath) == true then
			local openfile = fs.open(tFilepath,"r")
			a[1].lines = {}
			for line in openfile.readLine do
				a[1].lines[#a[1].lines+1] = line
			end
			openfile.close()
			if a[1].lines[1] == nil then
				a[1].lines[1] = ""
			end
		end
	end
    if isPrinterMode then
        local flat = a[1].lines
        local wrapped = splitToPrinterWidth(flat)
        pages = linesToPages(wrapped)
        currentPage = 1
        a[1].lines = pages[1]
    else
        pages = { { "" } }
        currentPage = 1
    end
    while true do
        local w,h = term.getSize()
        
        if isPrinterMode then
            local startX = math.floor((w - 25) / 2) + 1
            local startY = math.floor((h - 4 - 21) / 2) + 3
            if startY < 3 then startY = 3 end
            
            term.setBackgroundColor(tCol.bg)
            term.clear()
            
            drawPageControls()
            term.setTextColor(tCol.misc2)
            lUtils.border(startX - 1, startY - 1, startX + 25, startY + 21, nil, 3)
            
            a[1].width = 25
            a[1].height = 21
            
            -- Backup lines and state before drawEditBox
            local backupLines = {}
            for i, l in ipairs(a[1].lines) do
                backupLines[i] = l
            end
            local backupCursorCol = a[4] or 1
            local backupCursorLine = a[5] or 1
            local backupScrollX = a[2] or 0
            local backupScrollY = a[3] or 0
            
            local textCol = tCol.txt
            a[1].sTable = {
                background = {tCol.bg},
                text = {textCol},
                cursor = {theme.cursor or colors.red},
                keywords = {isHighlightEnabled and (theme.keywords or colors.blue) or textCol},
                numbers = {isHighlightEnabled and (theme.numbers or colors.orange) or textCol},
                notes = {isHighlightEnabled and (theme.comments or colors.gray) or textCol}
            }
            term.setCursorPos(1,5)
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
            local changesAllowed = true
            if isReadOnly == true or (tFilepath ~= "" and fs.isReadOnly(tFilepath) == true) then
                changesAllowed = false
            end
            
            local opull = os.pullEvent
            local hijacked = false
            _G.os.pullEvent = function(filter)
                if hijacked then
                    hijacked = false
                    return "mouse_click", 1, -999, -999
                end
                local event, button, x, y = opull(filter)
                if event == "char" or event == "key" or event == "paste" then
                    hijacked = true
                end
                return event, button, x, y
            end
            
            a = {lUtils.drawEditBox(a[1], startX, startY, a[2], a[3], a[4], a[5], true, true, nil, changesAllowed)}
            
            _G.os.pullEvent = opull
            
            a[2] = 0
            if a[4] and a[4] > 26 then
                a[4] = 26
            end
            
            -- Word wrap the text on the active page
            local lines = a[1].lines
            local lineIdx = 1
            local cursorCol = a[4] or 1
            local cursorLine = a[5] or 1
            
            while lineIdx <= #lines do
                local line = lines[lineIdx]
                if #line > 25 then
                    local spacePos = nil
                    for i = 25, 1, -1 do
                        if string.sub(line, i, i) == " " then
                            spacePos = i
                            break
                        end
                    end
                    
                    local part1, part2
                    if spacePos then
                        part1 = string.sub(line, 1, spacePos)
                        part2 = string.sub(line, spacePos + 1)
                        
                        if lineIdx == cursorLine then
                            if cursorCol > spacePos then
                                cursorLine = lineIdx + 1
                                cursorCol = cursorCol - spacePos
                            end
                        elseif lineIdx < cursorLine then
                            cursorLine = cursorLine + 1
                        end
                    else
                        part1 = string.sub(line, 1, 25)
                        part2 = string.sub(line, 26)
                        
                        if lineIdx == cursorLine then
                            if cursorCol > 25 then
                                cursorLine = lineIdx + 1
                                cursorCol = cursorCol - 25
                            end
                        elseif lineIdx < cursorLine then
                            cursorLine = cursorLine + 1
                        end
                    end
                    
                    lines[lineIdx] = part1
                    table.insert(lines, lineIdx + 1, part2)
                    a[1].changed = true
                else
                    local nextLine = lines[lineIdx + 1]
                    if nextLine and #line < 25 then
                        local firstWord = string.match(nextLine, "^[^%s]+")
                        if firstWord and #line + #firstWord + 1 <= 25 then
                            lines[lineIdx] = line .. (line:sub(-1) == " " and "" or " ") .. firstWord
                            lines[lineIdx + 1] = string.sub(nextLine, #firstWord + 1):gsub("^%s+", "")
                            
                            if lines[lineIdx + 1] == "" and #lines > lineIdx + 1 then
                                table.remove(lines, lineIdx + 1)
                                if cursorLine > lineIdx + 1 then
                                    cursorLine = cursorLine - 1
                                end
                            end
                            
                            if cursorLine == lineIdx + 1 then
                                if cursorCol <= #firstWord + 1 then
                                    cursorLine = lineIdx
                                    cursorCol = #line + (line:sub(-1) == " " and 0 or 1) + cursorCol
                                else
                                    cursorCol = cursorCol - #firstWord
                                    local diff = #nextLine - #lines[lineIdx + 1] - #firstWord
                                    cursorCol = cursorCol - diff
                                end
                            elseif cursorLine > lineIdx + 1 then
                                cursorLine = cursorLine - 1
                            end
                            a[1].changed = true
                            lineIdx = lineIdx - 1
                        end
                    end
                end
                lineIdx = lineIdx + 1
            end
            
            -- If we exceeded 21 lines, revert to backup and play beep
            if #lines > 21 then
                a[1].lines = backupLines
                a[4] = backupCursorCol
                a[5] = backupCursorLine
                a[2] = backupScrollX
                a[3] = backupScrollY
                local sp = peripheral.find("speaker")
                if sp then
                    pcall(sp.playNote, "bass", 1, 5)
                end
            else
                a[5] = cursorLine
                a[4] = cursorCol
                a[2] = 0
            end
        else
            a[1].width = w-1
            a[1].height = h-4
            
            local textCol = tCol.txt
            a[1].sTable = {
                background = {tCol.bg},
                text = {textCol},
                cursor = {theme.cursor or colors.red},
                keywords = {isHighlightEnabled and (theme.keywords or colors.blue) or textCol},
                numbers = {isHighlightEnabled and (theme.numbers or colors.orange) or textCol},
                notes = {isHighlightEnabled and (theme.comments or colors.gray) or textCol}
            }
            term.setCursorPos(1,5)
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
            local changesAllowed = true
            if isReadOnly == true or (tFilepath ~= "" and fs.isReadOnly(tFilepath) == true) then
                changesAllowed = false
            end
            a = {lUtils.drawEditBox(a[1], 1, 3, a[2], a[3], a[4], a[5], true, true, nil, changesAllowed)}
        end
        os.sleep(0)
    end
end

_G.thetxtfunction = txt

local function centerAlignLine(lineIdx)
    local line = a[1].lines[lineIdx]
    if not line then return end
    
    local text = line:gsub("^%s+", ""):gsub("%s+$", "")
    local targetWidth = isPrinterMode and 25 or (w - 1)
    
    local pad = math.max(0, math.floor((targetWidth - #text) / 2))
    a[1].lines[lineIdx] = string.rep(" ", pad) .. text
    a[1].changed = true
    a[4] = pad + #text + 1
end

local function save()
    if tFilepath == "" then
        while true do
            local i = {lUtils.inputbox("Filepath","Please enter a new filepath:",29,10,{"Done","Cancel"})}
            if i[2] == false or i[4] == "Cancel" then
                return false
            end
            if fs.exists(i[1]) == true then
                lUtils.popup("Error","This path already exists!",29,9,{"OK"})
            else
                tFilepath = i[1]
                break
            end
        end
    end
    local savefile = fs.open(tFilepath,"w")
    for t=1,#a[1].lines do
        savefile.writeLine(a[1].lines[t])
    end
	savefile.close()
    return true
end

local function uwansave()
    local name = ""
    if tFilepath == "" then
        name = "Untitled"
    else
        name = fs.getName(tFilepath)
    end
    local c = {lUtils.popup("Notepad++","Do you want to save your changes in "..name.."?",30,8,{"Save","Don't save","Cancel"})}
    if c[1] == false then return false
    elseif c[3] == "Save" then
        if tFilepath == "" then
            return false
        end
        local ayyy = fs.open(tFilepath,"w")
        for t=1,#a[1].lines do
            ayyy.writeLine(a[1].lines[t])
        end
    end
    if c[3] ~= "Cancel" then
        return true
    end
end

local function scrollbars()
    local w,h = term.getSize()
    term.setCursorPos(1,h-1)
    term.setBackgroundColor(tCol.misc)
    term.setTextColor(tCol.misc2)
    term.clearLine()
    term.setCursorPos(1,h-1)
    term.write("\17")
    term.setCursorPos(w-1,h-1)
    term.write("\16")
    for t=2,h-2 do
        term.setCursorPos(w,t)
        if t == 3 then
            term.write("\30")
        elseif t == h-2 then
            term.write("\31")
        else
            term.write(" ")
        end
    end
    term.setCursorPos(1,h)
    term.setBackgroundColor(tCol.misc)
    term.setTextColor(tCol.misc2)
    term.write(string.rep("\131", w))
end

local function drawStatus()
    local w,h = term.getSize()
    local line = (a[1] and a[5]) or 1
    local col = (a[1] and a[4]) or 1
    local text = " Ln " .. line .. ", Col " .. col .. " "
    term.setCursorPos(w - #text - 1, h)
    term.setBackgroundColor(tCol.misc)
    term.setTextColor(tCol.misc2)
    term.write(text)
end

function LevelOS.close()
	local u = true
	if a[1] and a[1].changed == true then
		u = uwansave()
	end
	if u == true then
		return
	else
		regevents()
	end
end

function regevents()
    scrollbars()
    drawStatus()
    local txtcor = coroutine.create(txt)
    topbar()
    coroutine.resume(txtcor)
    while true do
        e = {os.pullEvent()}
        scrollbars()
        drawStatus()
        if not ((e[1] == "mouse_click" or e[1] == "mouse_up") and e[4] == 1) then
            coroutine.resume(txtcor,table.unpack(e))
        end
        if e[1] == "notepad_theme_changed" then
            loadThemeConfig()
            theme = config.themes[config.current]
            tCol = {
                bg = theme.bg,
                txt = theme.txt,
                misc = theme.misc,
                misc2 = theme.misc2
            }
            topbar()
            scrollbars()
            drawStatus()
            coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
        elseif e[1] == "term_resize" then
            topbar()
            scrollbars()
            drawStatus()
            coroutine.resume(txtcor,"mouse_click",1,1,1)
        elseif e[1] == "mouse_click" then
            local w,h = term.getSize()
            if isPrinterMode and e[4] == h-2 then
                local cx = e[3]
                if cx >= 2 and cx <= 4 then
                    if currentPage > 1 then
                        pages[currentPage].cursorX = a[4]
                        pages[currentPage].cursorY = a[5]
                        pages[currentPage].scrollX = a[2]
                        pages[currentPage].scrollY = a[3]
                        
                        currentPage = currentPage - 1
                        a[1].lines = pages[currentPage]
                        a[4] = pages[currentPage].cursorX or 1
                        a[5] = pages[currentPage].cursorY or 1
                        a[2] = pages[currentPage].scrollX or 0
                        a[3] = pages[currentPage].scrollY or 0
                        coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                    end
                elseif cx >= 6 and cx <= 8 then
                    if currentPage < #pages then
                        pages[currentPage].cursorX = a[4]
                        pages[currentPage].cursorY = a[5]
                        pages[currentPage].scrollX = a[2]
                        pages[currentPage].scrollY = a[3]
                        
                        currentPage = currentPage + 1
                        a[1].lines = pages[currentPage]
                        a[4] = pages[currentPage].cursorX or 1
                        a[5] = pages[currentPage].cursorY or 1
                        a[2] = pages[currentPage].scrollX or 0
                        a[3] = pages[currentPage].scrollY or 0
                        coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                    end
                elseif cx >= w - 23 and cx <= w - 16 then
                    pages[currentPage].cursorX = a[4]
                    pages[currentPage].cursorY = a[5]
                    pages[currentPage].scrollX = a[2]
                    pages[currentPage].scrollY = a[3]
                    
                    table.insert(pages, currentPage + 1, { "" })
                    currentPage = currentPage + 1
                    a[1].lines = pages[currentPage]
                    a[4] = 1
                    a[5] = 1
                    a[2] = 0
                    a[3] = 0
                    a[1].changed = true
                    coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                elseif cx >= w - 13 and cx <= w - 6 then
                    if #pages > 1 then
                        local choice = {lUtils.popup("Notepad++", "Delete current page?", 29, 8, {"Delete", "Cancel"})}
                        if choice[1] == true and choice[3] == "Delete" then
                            table.remove(pages, currentPage)
                            if currentPage > #pages then
                                currentPage = #pages
                            end
                            a[1].lines = pages[currentPage]
                            a[4] = pages[currentPage].cursorX or 1
                            a[5] = pages[currentPage].cursorY or 1
                            a[2] = pages[currentPage].scrollX or 0
                            a[3] = pages[currentPage].scrollY or 0
                            a[1].changed = true
                            coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                        end
                    else
                        lUtils.popup("Notepad++", "Cannot delete the last page!", 29, 8, {"OK"})
                    end
                end
            elseif e[4] == 1 then
                topbar()
                term.setCursorBlink(false)
                local oldcursorpos = {term.getCursorPos()}
                for t=1,#btns do
                    if e[3] >= btns[t].x and e[3] <= btns[t].x+btns[t].w-1 then
                        term.setCursorPos(btns[t].x,1)
                        term.setBackgroundColor(colors.blue)
                        term.write(" "..btns[t][1].." ")
                        local disabled = {}
                        if btns[t][1] == "File" then
                            if not a[1] or a[1].changed == false then
                                disabled = {"Save","Save as..."}
                            end
                        end
                        local b = {lUtils.clickmenu(btns[t].x,2,20,btns[t][2],true,disabled)}
                        if b[1] ~= false then
                             if b[3] == "New" then
                                 local d = true
                                 if a[1] and a[1].changed == true then
                                     d = uwansave()
                                 end
                                 if d == true then
                                     tFilepath = ""
                                     pages = { { "" } }
                                     currentPage = 1
                                     a[1].lines = pages[1]
                                     txtcor = coroutine.create(txt)
                                     os.startTimer(0.1)
                                 end
                             elseif b[3] == "Open..." then
                                 local u = true
                                 if a[1] and a[1].changed == true then
                                     u = uwansave()
                                 end
                                 if u == true then
                                     local d = {lUtils.explorer("/","SelFile false")}
                                     if d[1] ~= nil and fs.exists(d[1]) then
                                         a = {{lines={""},changed=false}}
                                         tFilepath = d[1]
                                         local openfile = fs.open(tFilepath,"r")
                                         local loadedLines = {}
                                         for line in openfile.readLine do loadedLines[#loadedLines+1] = line end
                                         openfile.close()
                                         if isPrinterMode then
                                             pages = linesToPages(splitToPrinterWidth(loadedLines))
                                             currentPage = 1
                                             a[1].lines = pages[1]
                                         else
                                             pages = { { "" } }
                                             currentPage = 1
                                             a[1].lines = loadedLines
                                         end
                                         if #a[1].lines == 0 then a[1].lines[1] = "" end
                                         txtcor = coroutine.create(txt)
                                         coroutine.resume(txtcor)
                                     end
                                 end
                            elseif b[3] == "Save" then
                                if save() == true then
                                    a[1].changed = false
                                end
                            elseif b[3] == "Save as..." then
                                local oldF = tFilepath
                                tFilepath = ""
                                if save() == false then
                                    tFilepath = oldF
                                else
                                    a[1].changed = false
                                end
                            elseif b[3] == "Print" then
                                 local printer = peripheral.find("printer")
                                 if not printer then
                                     lUtils.popup("Notepad++", "No printer found!", 29, 9, {"OK"})
                                 else
                                    local choice = {lUtils.popup("Notepad++", "Print document?", 29, 8, {"Print", "Cancel"})}
                                    if choice[3] == "Print" then
                                        local ok, err = pcall(function()
                                            local title = tFilepath ~= "" and fs.getName(tFilepath) or "Untitled"
                                            if isPrinterMode then
                                                for pIdx, pageLines in ipairs(pages) do
                                                    if pIdx > 1 then printer.endPage() end
                                                    printer.newPage()
                                                    printer.setPageTitle(title .. " - Page " .. pIdx)
                                                    for y = 1, #pageLines do
                                                        printer.setCursorPos(1, y)
                                                        printer.write(pageLines[y])
                                                    end
                                                end
                                                printer.endPage()
                                            else
                                                printer.newPage()
                                                local y = 1
                                                for _, line in ipairs(a[1].lines) do
                                                    local wrapped = lUtils.wordwrap(line, 25)
                                                    for _, wl in ipairs(#wrapped > 0 and wrapped or {""}) do
                                                        if y > 21 then printer.endPage(); printer.newPage(); y = 1 end
                                                        printer.setCursorPos(1, y); printer.write(wl); y = y + 1
                                                    end
                                                end
                                                printer.endPage()
                                            end
                                        end)
                                    end
                                 end
                            elseif b[3] == "Quit" then
                                if u == true then
                                    return
                                end
                            elseif b[3] == "Time" then
                                local timeStr = os.date()
                                local line = a[5] or 1
                                local col = a[4] or 1
                                a[1].lines[line] = string.sub(a[1].lines[line], 1, col-1) .. timeStr .. string.sub(a[1].lines[line], col)
                                a[4] = col + #timeStr
                                a[1].changed = true
                                coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                            elseif b[3] == "Center Align" then
                                local line = a[5] or 1
                                centerAlignLine(line)
                                coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
							elseif b[3] == "Theme Editor" then
                                lUtils.openWin("Theme Editor", "Program_Files/Notepad++/theme_editor.lua", 5, 5, 34, 15, true)
                            elseif b[3] == "Highlighting: On" or b[3] == "Highlighting: Off" then
                                isHighlightEnabled = not isHighlightEnabled
                                coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                            elseif b[3] == "Printer Mode: On" or b[3] == "Printer Mode: Off" then
                                isPrinterMode = not isPrinterMode
                                if isPrinterMode then
                                    local flat = a[1].lines
                                    local wrapped = splitToPrinterWidth(flat)
                                    pages = linesToPages(wrapped)
                                    currentPage = 1
                                    a[1].lines = pages[1]
                                    a[4] = 1
                                    a[5] = 1
                                    a[2] = 0
                                    a[3] = 0
                                else
                                    a[1].lines = pagesToLines(pages)
                                    pages = { { "" } }
                                    currentPage = 1
                                    a[4] = 1
                                    a[5] = 1
                                    a[2] = 0
                                    a[3] = 0
                                end
                                coroutine.resume(txtcor, "mouse_click", 1, 1, 1)
                            end
                        end
                    end
                end
                topbar()
                term.setCursorPos(table.unpack(oldcursorpos))
                term.setTextColor(colors.red)
                term.setCursorBlink(true)
            end
        end
    end
end
regevents()
