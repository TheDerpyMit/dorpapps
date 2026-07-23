-- Program_Files/Email/main.lua
-- Modern Gmail Application for LevelOS & ComputerCraft
-- Features: Rednet Mail Sync, Archive/Unarchive, Read/Unread, Starred, Sent, Trash, Compose

if not _G.lUtils then shell.run("LevelOS/startup/lUtils") end

local emailCore
if fs.exists("Program_Files/Email/email_core.lua") then
    emailCore = dofile("Program_Files/Email/email_core.lua")
elseif fs.exists("email_core.lua") then
    emailCore = dofile("email_core.lua")
else
    emailCore = dofile(shell.resolve("email_core.lua"))
end

local tArgs = { ... }
if tArgs[1] == "load" then
    return { name = "GMail", version = "2.0" }
end
if LevelOS and LevelOS.setTitle then
    LevelOS.setTitle("GMail")
end

-- State Variables
local userEmail = os.getComputerLabel() and (os.getComputerLabel():lower():gsub("%s+", "") .. "@tuah") or ("user" .. os.getComputerID() .. "@tuah")
local serverID = nil
local activeTab = "inbox" -- "inbox", "archive", "starred", "sent", "trash"
local currentView = "list" -- "list", "detail", "compose"
local selectedEmail = nil

local emails = {}
local inputFields = {
    composeTo = "",
    composeSubject = "",
    composeBody = ""
}
local activeField = nil

local w, h = term.getSize()
local sidebarWidth = 14

-- Helper to generate random email ID
local function randomID()
    local charset = "abcdefghijklmnopqrstuvwxyz0123456789"
    local res = ""
    for i = 1, 8 do
        local rand = math.random(1, #charset)
        res = res .. charset:sub(rand, rand)
    end
    return res
end

-- Default sample emails for first launch / offline mode
local function getInitialEmails()
    local localCached = emailCore.loadLocalMail(userEmail)
    if localCached and #localCached > 0 then
        return localCached
    end

    local sample = {
        {
            id = "welcome01",
            from = "system@tuah",
            to = userEmail,
            subject = "Welcome to Gmail for LevelOS!",
            body = "Welcome to your brand new Gmail client on LevelOS!\n\nFeatures:\n- Full Rednet email server sync\n- Archive & Unarchive emails\n- Read & Unread tracking\n- Starred / Important folder\n- Sent & Trash folders\n\nEnjoy sending emails across your ComputerCraft network!",
            timestamp = os.epoch("utc") - 3600000,
            read = false,
            archived = false,
            starred = true,
            deleted = false
        },
        {
            id = "tips02",
            from = "support@tuah",
            to = userEmail,
            subject = "Getting Started Tips",
            body = "Tips for using Gmail:\n- Click [+ Compose] to write a new email.\n- Click Archive to remove messages from your Inbox into All Mail.\n- Use Arrow Keys or Mouse to navigate emails.",
            timestamp = os.epoch("utc") - 86400000,
            read = true,
            archived = false,
            starred = false,
            deleted = false
        }
    }
    emailCore.saveLocalMail(userEmail, sample)
    return sample
end

emails = getInitialEmails()

-- Save emails to cache
local function saveState()
    emailCore.saveLocalMail(userEmail, emails)
end

-- Connect Rednet Server
local function connectServer()
    serverID = emailCore.getServerID()
    if serverID then
        emailCore.send("hello", { sender = userEmail }, serverID)
        emailCore.send("list", { sender = userEmail, user = userEmail, token = "auth_token" }, serverID)
    end
end

connectServer()

-- Helper to format email timestamps
local function formatDate(ts)
    if not ts then return "" end
    local delta = (os.epoch("utc") - ts) / 1000
    if delta >= 86400 then
        return os.date("%m/%d", math.floor(ts / 1000))
    else
        return os.date("%H:%M", math.floor(ts / 1000))
    end
end

-- Get filtered list of emails for current tab
local function getFilteredEmails()
    local filtered = {}
    for _, msg in ipairs(emails) do
        if activeTab == "inbox" then
            if not msg.archived and not msg.deleted and (msg.to == userEmail or msg.to == "all@tuah") then
                table.insert(filtered, msg)
            end
        elseif activeTab == "archive" then
            if msg.archived and not msg.deleted then
                table.insert(filtered, msg)
            end
        elseif activeTab == "starred" then
            if msg.starred and not msg.deleted then
                table.insert(filtered, msg)
            end
        elseif activeTab == "sent" then
            if msg.from == userEmail and not msg.deleted then
                table.insert(filtered, msg)
            end
        elseif activeTab == "trash" then
            if msg.deleted then
                table.insert(filtered, msg)
            end
        end
    end
    table.sort(filtered, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    return filtered
end

-- Count unread emails in Inbox
local function getUnreadCount()
    local count = 0
    for _, msg in ipairs(emails) do
        if not msg.read and not msg.archived and not msg.deleted and (msg.to == userEmail or msg.to == "all@tuah") then
            count = count + 1
        end
    end
    return count
end

-- Draw Header Bar
local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("M GMail")
    
    local userBadge = "<" .. userEmail .. ">"
    term.setCursorPos(w - #userBadge, 1)
    term.setTextColor(colors.yellow)
    term.write(userBadge)
end

-- Draw Sidebar Navigation
local function drawSidebar()
    term.setBackgroundColor(colors.gray)
    for y = 2, h do
        term.setCursorPos(1, y)
        term.setTextColor(colors.lightGray)
        term.write(string.rep(" ", sidebarWidth))
        term.setCursorPos(sidebarWidth, y)
        term.setTextColor(colors.lightGray)
        term.write("\149") -- Vertical separator
    end

    -- Compose Button
    term.setCursorPos(2, 3)
    term.setBackgroundColor(currentView == "compose" and colors.lime or colors.lightGray)
    term.setTextColor(colors.black)
    term.write(" [+ Compose] ")

    -- Nav Tabs
    local tabs = {
        { id = "inbox", label = "Inbox", count = getUnreadCount() },
        { id = "starred", label = "Starred" },
        { id = "archive", label = "Archive" },
        { id = "sent", label = "Sent" },
        { id = "trash", label = "Trash" },
    }

    local startY = 5
    for _, tab in ipairs(tabs) do
        term.setCursorPos(2, startY)
        if activeTab == tab.id and currentView ~= "compose" then
            term.setBackgroundColor(colors.lightBlue)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
        end
        local lbl = tab.label
        if tab.count and tab.count > 0 then
            lbl = lbl .. " (" .. tab.count .. ")"
        end
        term.write(lbl .. string.rep(" ", sidebarWidth - #lbl - 2))
        startY = startY + 1
    end
end

-- Draw Email List View
local function drawListView()
    local filtered = getFilteredEmails()
    local listX = sidebarWidth + 1
    local listWidth = w - sidebarWidth

    -- Action / Status Header
    term.setCursorPos(listX, 2)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clearLine()
    term.setCursorPos(listX + 1, 2)
    term.write(activeTab:upper() .. " (" .. #filtered .. " messages)")

    local y = 3
    for i, msg in ipairs(filtered) do
        if y >= h then break end
        term.setCursorPos(listX, y)
        
        local bg = (i % 2 == 0) and colors.black or colors.gray
        term.setBackgroundColor(bg)
        term.clearLine()

        -- Read / Unread Indicator & Star
        local starSymbol = msg.starred and "\15" or "\18" -- Star symbol
        local readDot = msg.read and " " or "\7" -- Bullet dot for unread

        term.setCursorPos(listX + 1, y)
        term.setTextColor(msg.read and colors.lightGray or colors.yellow)
        term.write(starSymbol .. " ")
        term.setTextColor(msg.read and colors.lightGray or colors.lime)
        term.write(readDot .. " ")

        -- Sender
        term.setTextColor(msg.read and colors.lightGray or colors.white)
        local senderStr = msg.from:sub(1, 10)
        term.write(senderStr .. string.rep(" ", 11 - #senderStr))

        -- Subject preview
        local dateStr = formatDate(msg.timestamp)
        local maxSubjLen = listWidth - 20 - #dateStr
        local subjStr = msg.subject or "No Subject"
        if #subjStr > maxSubjLen then
            subjStr = subjStr:sub(1, maxSubjLen - 2) .. ".."
        end
        term.write(subjStr)

        -- Date
        term.setCursorPos(w - #dateStr, y)
        term.setTextColor(colors.lightGray)
        term.write(dateStr)

        y = y + 1
    end

    if #filtered == 0 then
        term.setCursorPos(listX + 2, 4)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.write("No emails in " .. activeTab .. ".")
    end
end

-- Draw Email Detail View
local function drawDetailView()
    local listX = sidebarWidth + 1
    local listWidth = w - sidebarWidth

    if not selectedEmail then
        currentView = "list"
        return
    end

    -- Toolbar
    term.setCursorPos(listX, 2)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clearLine()
    term.setCursorPos(listX + 1, 2)
    term.write(" [< Back]  ")
    
    term.setBackgroundColor(selectedEmail.archived and colors.lightBlue or colors.blue)
    term.setTextColor(colors.white)
    term.write(selectedEmail.archived and " [Unarchive] " or " [Archive] ")
    
    term.setBackgroundColor(colors.gray)
    term.write(selectedEmail.read and " [Mark Unread] " or " [Mark Read] ")
    
    term.setBackgroundColor(colors.red)
    term.write(" [Delete] ")

    -- Headers
    term.setCursorPos(listX + 1, 4)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.write("Subject: " .. (selectedEmail.subject or "No Subject"))

    term.setCursorPos(listX + 1, 5)
    term.setTextColor(colors.lightGray)
    term.write("From: ")
    term.setTextColor(colors.white)
    term.write(selectedEmail.from)

    term.setCursorPos(listX + 1, 6)
    term.setTextColor(colors.lightGray)
    term.write("To: ")
    term.setTextColor(colors.white)
    term.write(selectedEmail.to)

    term.setCursorPos(listX + 1, 7)
    term.setTextColor(colors.lightGray)
    term.write("Date: ")
    term.setTextColor(colors.white)
    term.write(os.date("%Y-%m-%d %H:%M", math.floor((selectedEmail.timestamp or 0)/1000)))

    -- Separator
    term.setCursorPos(listX + 1, 8)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", listWidth - 2))

    -- Body text wrapping
    local body = selectedEmail.body or ""
    local y = 10
    for line in body:gmatch("[^\r\n]+") do
        while #line > 0 and y < (h - 1) do
            local chunk = line:sub(1, listWidth - 3)
            line = line:sub(listWidth - 2)
            term.setCursorPos(listX + 1, y)
            term.setTextColor(colors.white)
            term.write(chunk)
            y = y + 1
        end
    end
end

-- Draw Compose View
local function drawComposeView()
    local listX = sidebarWidth + 1
    local listWidth = w - sidebarWidth

    term.setCursorPos(listX, 2)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(listX + 1, 2)
    term.write("New Message")

    -- To Field
    term.setCursorPos(listX + 1, 4)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("To: ")
    term.setBackgroundColor(activeField == "to" and colors.white or colors.lightGray)
    term.setTextColor(colors.black)
    local toStr = inputFields.composeTo
    term.write(" " .. toStr .. string.rep(" ", listWidth - #toStr - 8) .. " ")

    -- Subject Field
    term.setCursorPos(listX + 1, 6)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("Subject: ")
    term.setBackgroundColor(activeField == "subject" and colors.white or colors.lightGray)
    term.setTextColor(colors.black)
    local subStr = inputFields.composeSubject
    term.write(" " .. subStr .. string.rep(" ", listWidth - #subStr - 13) .. " ")

    -- Body Label
    term.setCursorPos(listX + 1, 8)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("Message:")

    -- Body Box
    term.setCursorPos(listX + 1, 9)
    term.setBackgroundColor(activeField == "body" and colors.white or colors.lightGray)
    term.setTextColor(colors.black)
    local bodyStr = inputFields.composeBody
    term.write(" " .. bodyStr .. string.rep(" ", listWidth - #bodyStr - 5) .. " ")

    -- Action Buttons
    term.setCursorPos(listX + 1, 12)
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.black)
    term.write(" [ Send ] ")

    term.setCursorPos(listX + 12, 12)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write(" [ Cancel ] ")
end

-- Render Full UI
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    drawHeader()
    drawSidebar()

    if currentView == "list" then
        drawListView()
    elseif currentView == "detail" then
        drawDetailView()
    elseif currentView == "compose" then
        drawComposeView()
    end
end

-- Main Event Loop
drawUI()

if not serverID then
    _G.lUtils.popup("Gmail Status", "No Rednet Mail Server found!\nEnsure wireless modem is attached.\nRunning in Offline Mode.", 36, 9, { "OK" })
    drawUI()
end

while true do
    sleep(0)
    local e = { os.pullEvent() }
    local eventType = e[1]

    if eventType == "term_resize" then
        w, h = term.getSize()
        drawUI()
    end

    -- Handle incoming Rednet messages
    if eventType == "rednet_message" then
        local parsed = emailCore.parseMessage(e)
        if parsed then
            if parsed.event == "newemail" and parsed.data then
                table.insert(emails, parsed.data)
                saveState()
                drawUI()
            elseif parsed.event == "list" and type(parsed.data) == "table" then
                emails = parsed.data
                saveState()
                drawUI()
            end
        end
    end

    if eventType == "mouse_click" then
        local mx, my = e[3], e[4]

        -- Sidebar Clicks
        if mx <= sidebarWidth then
            if my == 3 then
                currentView = "compose"
                activeField = "to"
                drawUI()
            elseif my >= 5 and my <= 9 then
                local tabIndex = my - 4
                local tabList = { "inbox", "starred", "archive", "sent", "trash" }
                if tabList[tabIndex] then
                    activeTab = tabList[tabIndex]
                    currentView = "list"
                    drawUI()
                end
            end
        else
            -- Main View Clicks
            local listX = sidebarWidth + 1

            if currentView == "list" then
                local filtered = getFilteredEmails()
                local clickedIdx = my - 2
                if clickedIdx >= 1 and clickedIdx <= #filtered then
                    selectedEmail = filtered[clickedIdx]
                    selectedEmail.read = true
                    saveState()

                    -- Send read notification to server
                    if serverID then
                        emailCore.send("read", { id = selectedEmail.id, sender = userEmail, user = userEmail, token = "auth_token" }, serverID)
                    end
                    currentView = "detail"
                    drawUI()
                end

            elseif currentView == "detail" then
                if my == 2 then
                    -- Toolbar button clicks
                    if mx >= listX + 1 and mx <= listX + 9 then
                        currentView = "list"
                        drawUI()
                    elseif mx >= listX + 11 and mx <= listX + 23 then
                        -- Archive / Unarchive
                        if selectedEmail then
                            selectedEmail.archived = not selectedEmail.archived
                            saveState()
                            _G.lUtils.popup("Gmail", selectedEmail.archived and "Email moved to Archive." or "Email restored to Inbox.", 32, 9, { "OK" })
                            currentView = "list"
                            drawUI()
                        end
                    elseif mx >= listX + 25 and mx <= listX + 39 then
                        -- Mark Read / Unread
                        if selectedEmail then
                            selectedEmail.read = not selectedEmail.read
                            saveState()
                            if serverID then
                                local evt = selectedEmail.read and "read" or "unread"
                                emailCore.send(evt, { id = selectedEmail.id, sender = userEmail, user = userEmail, token = "auth_token" }, serverID)
                            end
                            drawUI()
                        end
                    elseif mx >= listX + 41 and mx <= listX + 49 then
                        -- Delete / Trash
                        if selectedEmail then
                            selectedEmail.deleted = true
                            saveState()
                            if serverID then
                                emailCore.send("delete", { id = selectedEmail.id, sender = userEmail, user = userEmail, token = "auth_token" }, serverID)
                            end
                            _G.lUtils.popup("Gmail", "Email moved to Trash.", 30, 9, { "OK" })
                            currentView = "list"
                            drawUI()
                        end
                    end
                end

            elseif currentView == "compose" then
                if my == 4 then
                    activeField = "to"
                    drawUI()
                elseif my == 6 then
                    activeField = "subject"
                    drawUI()
                elseif my == 8 or my == 9 then
                    activeField = "body"
                    drawUI()
                elseif my == 12 then
                    if mx >= listX + 1 and mx <= listX + 10 then
                        -- Send Button
                        if inputFields.composeTo == "" then
                            _G.lUtils.popup("Gmail Error", "Please enter a recipient email address.", 34, 9, { "OK" })
                            drawUI()
                        else
                            local newMsg = {
                                id = randomID(),
                                from = userEmail,
                                to = inputFields.composeTo,
                                subject = inputFields.composeSubject ~= "" and inputFields.composeSubject or "No Subject",
                                body = inputFields.composeBody,
                                timestamp = os.epoch("utc"),
                                read = true,
                                archived = false,
                                starred = false,
                                deleted = false
                            }
                            table.insert(emails, newMsg)
                            saveState()

                            -- Send Rednet message
                            emailCore.send("newemail", newMsg, serverID)

                            _G.lUtils.popup("Gmail", "Email sent successfully to " .. inputFields.composeTo, 34, 9, { "OK" })
                            inputFields = { composeTo = "", composeSubject = "", composeBody = "" }
                            currentView = "list"
                            activeTab = "sent"
                            drawUI()
                        end
                    elseif mx >= listX + 12 and mx <= listX + 22 then
                        -- Cancel Button
                        inputFields = { composeTo = "", composeSubject = "", composeBody = "" }
                        currentView = "list"
                        drawUI()
                    end
                end
            end
        end

    elseif eventType == "char" and currentView == "compose" and activeField then
        if activeField == "to" then
            inputFields.composeTo = inputFields.composeTo .. e[2]
        elseif activeField == "subject" then
            inputFields.composeSubject = inputFields.composeSubject .. e[2]
        elseif activeField == "body" then
            inputFields.composeBody = inputFields.composeBody .. e[2]
        end
        drawUI()

    elseif eventType == "key" then
        local key = e[2]
        if currentView == "compose" and activeField then
            if key == keys.backspace then
                if activeField == "to" then
                    inputFields.composeTo = inputFields.composeTo:sub(1, #inputFields.composeTo - 1)
                elseif activeField == "subject" then
                    inputFields.composeSubject = inputFields.composeSubject:sub(1, #inputFields.composeSubject - 1)
                elseif activeField == "body" then
                    inputFields.composeBody = inputFields.composeBody:sub(1, #inputFields.composeBody - 1)
                end
                drawUI()
            elseif key == keys.tab then
                if activeField == "to" then activeField = "subject"
                elseif activeField == "subject" then activeField = "body"
                elseif activeField == "body" then activeField = "to" end
                drawUI()
            end
        end
    end
end
