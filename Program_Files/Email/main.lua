-- Program_Files/Email/main.lua
-- Modern Gmail Application for DorpOS & ComputerCraft
-- Features: WebSocket Server Sync (@dorp.com domain), User Authentication (Login/Register), Persistence, Archive/Read/Starred/Trash/Compose

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
    return { name = "GMail", version = "3.1" }
end
if LevelOS and LevelOS.setTitle then
    LevelOS.setTitle("GMail")
end

-- Normalize handles to @dorp.com
local function normalizeEmail(addr)
    if not addr or addr:gsub("%s+", "") == "" then return "" end
    addr = addr:gsub("%s+", ""):lower()
    local atIdx = addr:find("@")
    if atIdx then
        addr = addr:sub(1, atIdx - 1)
    end
    return addr .. "@dorp.com"
end

-- App Mode State: "login" or "app"
local mode = "login"
local authMode = "login" -- "login" or "register"

-- Auth & Connection State
local userEmail = nil
local authToken = nil
local isConnected = false
local authError = ""

-- Login Form Input Fields
local authInputs = {
    email = "",
    password = ""
}
local activeAuthField = "email"

-- Main App State Variables
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

-- Save local mail cache
local function saveState()
    if userEmail then
        emailCore.saveLocalMail(userEmail, emails)
    end
end

-- Try connecting & authenticating with WebSocket server
local function initServerConnection()
    authError = "Connecting to server..."
    local ws, err = emailCore.connect()
    if not ws then
        isConnected = false
        authError = "Server offline: " .. (err or "Connection failed")
        return false
    end

    isConnected = true
    authError = ""
    return true
end

-- Attempt silent auto-login using stored auth file
local function tryAutoLogin()
    if not initServerConnection() then
        mode = "login"
        authError = "Server offline: Cannot connect to " .. emailCore.serverURL
        return
    end

    local saved = emailCore.loadAuth()
    if not saved then
        mode = "login"
        return
    end

    -- Send auth check request
    emailCore.sendPayload({ event = "auth_check", token = saved.token })
    local resp = emailCore.receiveMessage(3)
    if resp and resp.event == "auth_response" and resp.success then
        userEmail = resp.email
        authToken = saved.token
        mode = "app"

        -- Request email list from server
        emailCore.sendPayload({ event = "list", token = authToken })
        local listResp = emailCore.receiveMessage(2)
        if listResp and listResp.event == "list_response" and listResp.emails then
            emails = listResp.emails
            saveState()
        else
            emails = emailCore.loadLocalMail(userEmail) or {}
        end
    else
        -- Token expired or invalid
        emailCore.clearAuth()
        mode = "login"
        authError = "Session expired. Please log in again."
    end
end

-- Process Login or Registration Submit
local function submitAuth()
    local rawAlias = authInputs.email:gsub("%s+", "")
    if rawAlias == "" then
        authError = "Please enter an email username."
        return
    end
    if authInputs.password == "" then
        authError = "Please enter a password."
        return
    end

    if not isConnected then
        if not initServerConnection() then
            return
        end
    end

    authError = "Authenticating..."
    
    local fullEmail = normalizeEmail(rawAlias)

    local payload = {
        event = authMode,
        email = fullEmail,
        password = authInputs.password
    }
    
    emailCore.sendPayload(payload)
    local resp = emailCore.receiveMessage(4)

    if not resp then
        authError = "No response from server. Try again."
        return
    end

    local expectedEvt = authMode .. "_response"
    if resp.event == expectedEvt then
        if resp.success then
            userEmail = resp.email
            authToken = resp.token
            emailCore.saveAuth(userEmail, authToken)
            mode = "app"
            authError = ""
            authInputs = { email = "", password = "" }

            -- Fetch emails
            emailCore.sendPayload({ event = "list", token = authToken })
            local listResp = emailCore.receiveMessage(2)
            if listResp and listResp.event == "list_response" and listResp.emails then
                emails = listResp.emails
                saveState()
            else
                emails = emailCore.loadLocalMail(userEmail) or {}
            end
        else
            authError = resp.error or "Authentication failed."
        end
    else
        authError = "Unexpected response from server."
    end
end

-- Perform Logout
local function logout()
    emailCore.clearAuth()
    emailCore.close()
    userEmail = nil
    authToken = nil
    mode = "login"
    authError = ""
    emails = {}
end

-- Filtered emails for current tab
local function getFilteredEmails()
    local filtered = {}
    for _, msg in ipairs(emails) do
        if activeTab == "inbox" then
            if not msg.archived and not msg.deleted and (msg.to == userEmail or msg.to == "all@dorp.com") then
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

-- Count unread emails
local function getUnreadCount()
    local count = 0
    for _, msg in ipairs(emails) do
        if not msg.read and not msg.archived and not msg.deleted and (msg.to == userEmail or msg.to == "all@dorp.com") then
            count = count + 1
        end
    end
    return count
end

-- Draw Authentication (Login / Register) Screen
local function drawAuthScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    -- Title Bar
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("M GMail - Authentication")

    -- Server Info
    term.setCursorPos(w - 18, 1)
    term.setTextColor(isConnected and colors.lime or colors.yellow)
    term.write(isConnected and "[Server Online]" or "[Connecting...]")

    local boxWidth = math.min(42, w - 4)
    local boxX = math.floor((w - boxWidth) / 2) + 1
    local startY = 3

    -- Mode Tabs
    term.setCursorPos(boxX, startY)
    term.setBackgroundColor(authMode == "login" and colors.lightBlue or colors.gray)
    term.setTextColor(colors.white)
    term.write(" [ Log In ] ")

    term.setCursorPos(boxX + 13, startY)
    term.setBackgroundColor(authMode == "register" and colors.lime or colors.gray)
    term.setTextColor(colors.black)
    term.write(" [ Create Account ] ")

    -- Email / Username Label
    term.setCursorPos(boxX, startY + 3)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("Username / Alias (@dorp.com):")

    -- Email Field Box
    term.setCursorPos(boxX, startY + 4)
    term.setBackgroundColor(activeAuthField == "email" and colors.white or colors.lightGray)
    term.setTextColor(colors.black)
    local emailVal = authInputs.email
    term.write(" " .. emailVal .. string.rep(" ", boxWidth - #emailVal - 2) .. " ")

    -- Preview Full Address
    if #emailVal > 0 then
        term.setCursorPos(boxX, startY + 5)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        local fullPreview = normalizeEmail(emailVal)
        term.write(" -> " .. fullPreview:sub(1, boxWidth - 4))
    end

    -- Password Label
    term.setCursorPos(boxX, startY + 6)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("Password:")

    -- Password Field Box
    term.setCursorPos(boxX, startY + 7)
    term.setBackgroundColor(activeAuthField == "password" and colors.white or colors.lightGray)
    term.setTextColor(colors.black)
    local passVal = string.rep("*", #authInputs.password)
    term.write(" " .. passVal .. string.rep(" ", boxWidth - #passVal - 2) .. " ")

    -- Submit Button
    term.setCursorPos(boxX, startY + 10)
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.black)
    local btnText = authMode == "login" and " [ Log In ] " or " [ Create Account ] "
    term.write(btnText)

    -- Status / Error Message
    if authError ~= "" then
        term.setCursorPos(boxX, startY + 12)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        term.write(authError:sub(1, boxWidth))
    end

    -- Position cursor and enable blink for active input field
    if activeAuthField == "email" then
        term.setCursorPos(math.min(boxX + 1 + #authInputs.email, boxX + boxWidth - 2), startY + 4)
        term.setCursorBlink(true)
    elseif activeAuthField == "password" then
        term.setCursorPos(math.min(boxX + 1 + #authInputs.password, boxX + boxWidth - 2), startY + 7)
        term.setCursorBlink(true)
    else
        term.setCursorBlink(false)
    end
end

-- Draw Header Bar
local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("M GMail")
    
    if userEmail then
        local userBadge = "<" .. userEmail .. "> "
        local logoutBtn = "[ Logout ]"
        
        term.setCursorPos(w - #userBadge - #logoutBtn + 1, 1)
        term.setTextColor(colors.yellow)
        term.write(userBadge)

        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
        term.write(logoutBtn)
    end
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
        term.write("\149")
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
        local starSymbol = msg.starred and "\15" or "\18"
        local readDot = msg.read and " " or "\7"

        term.setCursorPos(listX + 1, y)
        term.setTextColor(msg.read and colors.lightGray or colors.yellow)
        term.write(starSymbol .. " ")
        term.setTextColor(msg.read and colors.lightGray or colors.lime)
        term.write(readDot .. " ")

        -- Sender
        term.setTextColor(msg.read and colors.lightGray or colors.white)
        local senderStr = (msg.from or ""):sub(1, 10)
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
    term.write(selectedEmail.from or "")

    term.setCursorPos(listX + 1, 6)
    term.setTextColor(colors.lightGray)
    term.write("To: ")
    term.setTextColor(colors.white)
    term.write(selectedEmail.to or "")

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
    term.write("To Alias: ")
    term.setBackgroundColor(activeField == "to" and colors.white or colors.lightGray)
    term.setTextColor(colors.black)
    local toStr = inputFields.composeTo
    term.write(" " .. toStr .. string.rep(" ", listWidth - #toStr - 13) .. " ")

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

    -- Set cursor for compose view
    if activeField == "to" then
        term.setCursorPos(listX + 12 + #inputFields.composeTo, 4)
        term.setCursorBlink(true)
    elseif activeField == "subject" then
        term.setCursorPos(listX + 10 + #inputFields.composeSubject, 6)
        term.setCursorBlink(true)
    elseif activeField == "body" then
        term.setCursorPos(listX + 2 + #inputFields.composeBody, 9)
        term.setCursorBlink(true)
    else
        term.setCursorBlink(false)
    end
end

-- Render Full UI
local function drawUI()
    if mode == "login" then
        drawAuthScreen()
        return
    end

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

-- Initialize App State & Attempt Login
tryAutoLogin()
drawUI()

-- Timer to poll background WebSocket messages
local wsTimer = os.startTimer(0.5)

while true do
    sleep(0)
    local e = { os.pullEvent() }
    local eventType = e[1]

    if eventType == "term_resize" then
        w, h = term.getSize()
        drawUI()
    end

    -- Poll incoming WebSocket messages
    if eventType == "timer" and e[2] == wsTimer then
        if mode == "app" and emailCore.ws then
            local msg = emailCore.receiveMessage(0)
            if msg then
                if msg.event == "newemail" and msg.data then
                    table.insert(emails, msg.data)
                    saveState()
                    drawUI()
                elseif msg.event == "list_response" and type(msg.emails) == "table" then
                    emails = msg.emails
                    saveState()
                    drawUI()
                end
            end
        end
        wsTimer = os.startTimer(0.5)
    end

    -- WebSocket direct event
    if eventType == "websocket_message" then
        if mode == "app" and type(e[2]) == "string" then
            local msg = textutils.unserializeJSON(e[2])
            if msg then
                if msg.event == "newemail" and msg.data then
                    table.insert(emails, msg.data)
                    saveState()
                    drawUI()
                elseif msg.event == "list_response" and type(msg.emails) == "table" then
                    emails = msg.emails
                    saveState()
                    drawUI()
                end
            end
        end
    end

    -- Mouse Clicks
    if eventType == "mouse_click" then
        local mx, my = e[3], e[4]

        if mode == "login" then
            local boxWidth = math.min(42, w - 4)
            local boxX = math.floor((w - boxWidth) / 2) + 1
            local startY = 3

            -- Mode Tabs Click
            if my == startY then
                if mx >= boxX and mx <= boxX + 11 then
                    authMode = "login"
                    authError = ""
                    drawUI()
                elseif mx >= boxX + 13 and mx <= boxX + 31 then
                    authMode = "register"
                    authError = ""
                    drawUI()
                end
            elseif my == startY + 3 or my == startY + 4 or my == startY + 5 then
                activeAuthField = "email"
                drawUI()
            elseif my == startY + 6 or my == startY + 7 then
                activeAuthField = "password"
                drawUI()
            elseif my >= startY + 9 and my <= startY + 11 then
                if mx >= boxX and mx <= boxX + 22 then
                    submitAuth()
                    drawUI()
                end
            end

        else
            -- Main App Header Click (Logout Button)
            if my == 1 then
                local userBadge = "<" .. (userEmail or "") .. "> "
                local logoutBtn = "[ Logout ]"
                local logoutX = w - #logoutBtn + 1
                if mx >= logoutX then
                    logout()
                    drawUI()
                end

            -- Sidebar Clicks
            elseif mx <= sidebarWidth then
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

                        -- Send update to server
                        if authToken then
                            emailCore.sendPayload({
                                event = "update_email",
                                token = authToken,
                                id = selectedEmail.id,
                                updates = { read = true }
                            })
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
                                if authToken then
                                    emailCore.sendPayload({
                                        event = "update_email",
                                        token = authToken,
                                        id = selectedEmail.id,
                                        updates = { archived = selectedEmail.archived }
                                    })
                                end
                                _G.lUtils.popup("Gmail", selectedEmail.archived and "Email moved to Archive." or "Email restored to Inbox.", 32, 9, { "OK" })
                                currentView = "list"
                                drawUI()
                            end
                        elseif mx >= listX + 25 and mx <= listX + 39 then
                            -- Mark Read / Unread
                            if selectedEmail then
                                selectedEmail.read = not selectedEmail.read
                                saveState()
                                if authToken then
                                    emailCore.sendPayload({
                                        event = "update_email",
                                        token = authToken,
                                        id = selectedEmail.id,
                                        updates = { read = selectedEmail.read }
                                    })
                                end
                                drawUI()
                            end
                        elseif mx >= listX + 41 and mx <= listX + 49 then
                            -- Delete / Trash
                            if selectedEmail then
                                selectedEmail.deleted = true
                                saveState()
                                if authToken then
                                    emailCore.sendPayload({
                                        event = "update_email",
                                        token = authToken,
                                        id = selectedEmail.id,
                                        updates = { deleted = true }
                                    })
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
                            if inputFields.composeTo:gsub("%s+", "") == "" then
                                _G.lUtils.popup("Gmail Error", "Please enter a recipient username.", 34, 9, { "OK" })
                                drawUI()
                            else
                                local targetTo = normalizeEmail(inputFields.composeTo)
                                local newMsg = {
                                    id = randomID(),
                                    from = userEmail,
                                    to = targetTo,
                                    subject = inputFields.composeSubject ~= "" and inputFields.composeSubject or "No Subject",
                                    body = inputFields.composeBody,
                                    timestamp = os.epoch("utc"),
                                    read = true,
                                    archived = false,
                                    starred = false,
                                    deleted = false
                                }

                                -- Send WebSocket event to server
                                if authToken then
                                    emailCore.sendPayload({
                                        event = "newemail",
                                        token = authToken,
                                        data = newMsg
                                    })
                                else
                                    table.insert(emails, newMsg)
                                    saveState()
                                end

                                _G.lUtils.popup("Gmail", "Email sent successfully to " .. targetTo, 36, 9, { "OK" })
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
        end

    -- Character Typing or Pasting
    elseif eventType == "char" or eventType == "paste" then
        local textInput = tostring(e[2])
        if mode == "login" and activeAuthField then
            if activeAuthField == "email" then
                authInputs.email = authInputs.email .. textInput
            elseif activeAuthField == "password" then
                authInputs.password = authInputs.password .. textInput
            end
            drawUI()
        elseif mode == "app" and currentView == "compose" and activeField then
            if activeField == "to" then
                inputFields.composeTo = inputFields.composeTo .. textInput
            elseif activeField == "subject" then
                inputFields.composeSubject = inputFields.composeSubject .. textInput
            elseif activeField == "body" then
                inputFields.composeBody = inputFields.composeBody .. textInput
            end
            drawUI()
        end

    -- Key presses
    elseif eventType == "key" then
        local key = e[2]
        if mode == "login" then
            if key == keys.backspace then
                if activeAuthField == "email" then
                    authInputs.email = authInputs.email:sub(1, #authInputs.email - 1)
                elseif activeAuthField == "password" then
                    authInputs.password = authInputs.password:sub(1, #authInputs.password - 1)
                end
                drawUI()
            elseif key == keys.tab or key == keys.down or key == keys.up then
                activeAuthField = (activeAuthField == "email") and "password" or "email"
                drawUI()
            elseif key == keys.enter or key == keys.numPadEnter then
                submitAuth()
                drawUI()
            end

        elseif mode == "app" and currentView == "compose" and activeField then
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
