-- Program_Files/Email/email_core.lua
-- Core Email Protocol & Rednet Communication Library for LevelOS Gmail

local emailCore = {}

emailCore.protocol = "email"
emailCore.hostname = "tuah"

-- Ensure rednet is open on connected modem
function emailCore.initRednet()
    if not rednet.isOpen() then
        peripheral.find("modem", rednet.open)
    end
end

-- Find email server on rednet network
function emailCore.getServerID()
    emailCore.initRednet()
    return rednet.lookup(emailCore.protocol, emailCore.hostname)
end

-- Send message to server
function emailCore.send(event, payload, serverID)
    emailCore.initRednet()
    local msg = event .. "|" .. textutils.serialise(payload)
    if serverID then
        rednet.send(serverID, msg, emailCore.protocol)
    else
        rednet.broadcast(msg, emailCore.protocol)
    end
end

-- Parse incoming rednet message
function emailCore.parseMessage(evt)
    local msg = evt[3]
    local sender = evt[2]
    if type(msg) ~= "string" then return nil end
    local sepIdx = string.find(msg, "|")
    if not sepIdx then return nil end
    local event = string.sub(msg, 1, sepIdx - 1)
    local data = textutils.unserialise(string.sub(msg, sepIdx + 1))
    return {
        event = event,
        data = data,
        sender = sender
    }
end

-- Local persistence storage for offline caching & local mail state
function emailCore.saveLocalMail(userEmail, emailList)
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
