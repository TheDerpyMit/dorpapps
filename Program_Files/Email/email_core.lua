-- Program_Files/Email/email_core.lua
-- Core WebSocket Communication & Auth Library for LevelOS Gmail

local emailCore = {}

emailCore.serverURL = "ws://th-us1.terohost.com:25616"
emailCore.ws = nil

-- Save Auth Token locally so user stays logged in
function emailCore.saveAuth(email, token)
    local dir = "User/EmailData"
    if not fs.exists(dir) then fs.makeDir(dir) end
    local filePath = dir .. "/auth.json"
    local f = fs.open(filePath, "w")
    if f then
        f.write(textutils.serializeJSON({ email = email, token = token }))
        f.close()
    end
end

-- Load saved Auth Token
function emailCore.loadAuth()
    local filePath = "User/EmailData/auth.json"
    if not fs.exists(filePath) then return nil end
    local f = fs.open(filePath, "r")
    if f then
        local content = f.readAll()
        f.close()
        local data = textutils.unserializeJSON(content)
        if data and data.email and data.token then
            return data
        end
    end
    return nil
end

-- Clear Auth Token (Logout)
function emailCore.clearAuth()
    local filePath = "User/EmailData/auth.json"
    if fs.exists(filePath) then
        fs.delete(filePath)
    end
end

-- Connect to WebSocket server
function emailCore.connect(customURL)
    local url = customURL or emailCore.serverURL
    if emailCore.ws then
        pcall(function() emailCore.ws.close() end)
        emailCore.ws = nil
    end

    if not http or not http.websocket then
        return nil, "HTTP / WebSocket API is disabled in ComputerCraft settings."
    end

    local ws, err = http.websocket(url)
    if ws then
        emailCore.ws = ws
        return ws
    else
        return nil, err or "Failed to connect to " .. url
    end
end

-- Close connection
function emailCore.close()
    if emailCore.ws then
        pcall(function() emailCore.ws.close() end)
        emailCore.ws = nil
    end
end

-- Send JSON payload over WebSocket
function emailCore.sendPayload(payload)
    if not emailCore.ws then return false, "Not connected" end
    local jsonStr = textutils.serializeJSON(payload)
    local ok, err = pcall(function() emailCore.ws.send(jsonStr) end)
    if not ok then
        emailCore.ws = nil
        return false, err
    end
    return true
end

-- Receive a single JSON message with optional timeout
function emailCore.receiveMessage(timeout)
    if not emailCore.ws then return nil end
    local ok, msg = pcall(function() return emailCore.ws.receive(timeout) end)
    if ok and msg then
        local data = textutils.unserializeJSON(msg)
        return data
    end
    return nil
end

-- Local persistence storage for offline caching
function emailCore.saveLocalMail(userEmail, emailList)
    if not userEmail then return end
    local dir = "User/EmailData"
    if not fs.exists(dir) then fs.makeDir(dir) end
    local filePath = dir .. "/" .. textutils.urlEncode(userEmail) .. ".json"
    local f = fs.open(filePath, "w")
    if f then
        f.write(textutils.serializeJSON(emailList))
        f.close()
    end
end

function emailCore.loadLocalMail(userEmail)
    if not userEmail then return nil end
    local filePath = "User/EmailData/" .. textutils.urlEncode(userEmail) .. ".json"
    if not fs.exists(filePath) then return nil end
    local f = fs.open(filePath, "r")
    if f then
        local content = f.readAll()
        f.close()
        return textutils.unserializeJSON(content)
    end
    return nil
end

return emailCore
