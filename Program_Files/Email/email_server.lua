-- Program_Files/Email/email_server.lua
-- Central Rednet Email Server for LevelOS & ComputerCraft

local emailCore = require("Program_Files/Email/email_core")

print("==========================================")
print("LevelOS Rednet Email Server Starting...")

emailCore.initRednet()
rednet.host(emailCore.protocol, emailCore.hostname)
print("Hosting protocol '" .. emailCore.protocol .. "' as '" .. emailCore.hostname .. "'")

local serverStorage = "User/ServerEmailData/emails.json"
local allEmails = {}

local function loadStorage()
    if fs.exists(serverStorage) then
        local f = fs.open(serverStorage, "r")
        if f then
            local content = f.readAll()
            f.close()
            allEmails = textutils.unserializeJSON(content) or {}
        end
    end
end

local function saveStorage()
    local dir = "User/ServerEmailData"
    if not fs.exists(dir) then fs.makeDir(dir) end
    local f = fs.open(serverStorage, "w")
    if f then
        f.write(textutils.serializeJSON(allEmails))
        f.close()
    end
end

loadStorage()
print("Loaded " .. #allEmails .. " stored messages.")
print("Server running. Press Ctrl+T to stop.")

while true do
    sleep(0)
    local evt = { os.pullEvent("rednet_message") }
    local parsed = emailCore.parseMessage(evt)
    if parsed then
        print("[" .. os.date("%R") .. "] Event: " .. tostring(parsed.event) .. " from ID " .. tostring(parsed.sender))
        
        if parsed.event == "newemail" and parsed.data then
            table.insert(allEmails, parsed.data)
            saveStorage()
            print("  New mail to " .. tostring(parsed.data.to) .. ": " .. tostring(parsed.data.subject))
            -- Broadcast / Forward new email to network
            rednet.broadcast("newemail|" .. textutils.serialise(parsed.data), emailCore.protocol)
            
        elseif parsed.event == "list" and parsed.data then
            local user = parsed.data.sender or parsed.data.user
            local userMail = {}
            for _, msg in ipairs(allEmails) do
                if msg.to == user or msg.from == user or msg.to == "all@tuah" then
                    table.insert(userMail, msg)
                end
            end
            emailCore.send("list", userMail, parsed.sender)
            print("  Sent " .. #userMail .. " emails to " .. tostring(user))
        end
    end
end
