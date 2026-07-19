-- Program_Files/StoreManager/main.lua
-- Store Manager POS Application for LevelOS

shell.run("LevelOS/startup/lUtils")

local w, h = term.getSize()

-- Colors
local bgCol = colors.gray
local barCol = colors.blue
local textCol = colors.white
local cardCol = colors.lightGray
local activeCol = colors.lightBlue
local inactiveCol = colors.black
local btnCol = colors.green
local btnTextCol = colors.white
local errorCol = colors.red

-- State Variables
local dbPath = "AppData/StoreManager/items.lconf"
local items = {}
local cart = {}      -- maps item_name -> qty
local page = 1
local itemsPerPage = 8
local editMode = false
local activeField = nil -- "seller", "buyer", "priceQty", "priceItem"
local statusMsg = "Status: Ready"

-- Input Values
local sellerName = "Merchant"
local buyerName = "Customer"
local priceQty = "0"
local priceItem = "Diamond"

-- Modal State (for Add/Edit Item dialogs)
local modal = nil -- nil, "add", "edit"
local editItemIndex = nil -- index in items list when editing
local modalItemName = ""
local modalPriceQty = "1"
local modalPriceItem = "Diamond"
local modalActiveField = nil -- "name", "qty", "item"

-- Ensure directories exist and load database
local function loadDatabase()
    if not fs.exists("AppData") then fs.makeDir("AppData") end
    if not fs.exists("AppData/StoreManager") then fs.makeDir("AppData/StoreManager") end
    
    if fs.exists(dbPath) then
        local f = fs.open(dbPath, "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if type(data) == "table" then
            items = data
            return
        end
    end
    
    -- Default Items Database
    items = {
        { name = "Diamond Sword", priceQty = 3, priceItem = "Diamond" },
        { name = "Enchanted Apple", priceQty = 8, priceItem = "Gold Ingot" },
        { name = "Golden Carrot", priceQty = 2, priceItem = "Gold Ingot" },
        { name = "Iron Ingot", priceQty = 4, priceItem = "Coal" },
        { name = "Potion of Healing", priceQty = 1, priceItem = "Emerald" },
        { name = "Diamond", priceQty = 2, priceItem = "Emerald" },
        { name = "Emerald", priceQty = 1, priceItem = "Gold Ingot" },
        { name = "Steak", priceQty = 1, priceItem = "Coal" }
    }
    local f = fs.open(dbPath, "w")
    f.write(textutils.serialize(items))
    f.close()
end

local function saveDatabase()
    local f = fs.open(dbPath, "w")
    f.write(textutils.serialize(items))
    f.close()
end

-- Helper: Auto calculate price based on items in cart
local function autoCalcPrice()
    local total = 0
    local currency = nil
    local match = true
    
    for itemName, qty in pairs(cart) do
        -- Find item in database to get its price
        for _, item in ipairs(items) do
            if item.name == itemName then
                total = total + (item.priceQty * qty)
                if not currency then
                    currency = item.priceItem
                elseif currency ~= item.priceItem then
                    match = false
                end
                break
            end
        end
    end
    
    priceQty = tostring(total)
    if currency and match then
        priceItem = currency
    end
end

-- Clear Cart Function
local function clearCart()
    cart = {}
    priceQty = "0"
    statusMsg = "Cart cleared"
end

-- Draw utilities
local function drawButton(x, y, width, height, text, bg, fg)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    for i = 0, height - 1 do
        term.setCursorPos(x, y + i)
        term.write(string.rep(" ", width))
    end
    local tx = x + math.floor((width - #text) / 2)
    local ty = y + math.floor(height / 2)
    term.setCursorPos(tx, ty)
    term.write(text)
end

local function drawInputBox(x, y, width, label, val, active)
    term.setCursorPos(x, y)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.lightGray)
    term.write(label)
    
    term.setCursorPos(x, y + 1)
    if active then
        term.setBackgroundColor(activeCol)
        term.setTextColor(colors.white)
    else
        term.setBackgroundColor(inactiveCol)
        term.setTextColor(colors.white)
    end
    
    local displayVal = val
    if #displayVal > width - 2 then
        displayVal = displayVal:sub(#displayVal - width + 3)
    end
    term.write(" " .. displayVal .. string.rep(" ", width - #displayVal - 2) .. " ")
end

-- Render GUI
local function drawUI()
    -- Clear and draw base bg
    term.setBackgroundColor(bgCol)
    term.setTextColor(textCol)
    term.clear()
    
    -- Border
    term.setTextColor(colors.lightGray)
    lUtils.border(1, 1, w, h, nil, 3)
    
    -- Title Bar
    drawButton(2, 2, w - 2, 1, " Store Manager POS", barCol, colors.white)
    
    -- Separator
    for cy = 3, h - 2 do
        term.setCursorPos(25, cy)
        term.setBackgroundColor(bgCol)
        term.setTextColor(colors.lightGray)
        term.write("\149")
    end
    
    -- LEFT PANEL (Cart & Transaction Info)
    term.setCursorPos(3, 4)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.yellow)
    term.write("CART ITEMS")
    
    -- Cart List
    local cy = 5
    local cartEmpty = true
    -- Sort keys for consistent display
    local sortedCart = {}
    for name, qty in pairs(cart) do
        table.insert(sortedCart, { name = name, qty = qty })
    end
    table.sort(sortedCart, function(a, b) return a.name < b.name end)
    
    for i, entry in ipairs(sortedCart) do
        if cy <= 9 then
            term.setCursorPos(3, cy)
            term.setBackgroundColor(bgCol)
            term.setTextColor(textCol)
            term.write(string.format("%dx %s", entry.qty, entry.name:sub(1, 18)))
            cy = cy + 1
            cartEmpty = false
        end
    end
    if cartEmpty then
        term.setCursorPos(3, 5)
        term.setBackgroundColor(bgCol)
        term.setTextColor(colors.lightGray)
        term.write("(Cart is empty)")
    end
    
    -- Horizontal Line in left panel
    term.setCursorPos(2, 10)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", 23))
    
    -- Input Fields
    drawInputBox(3, 11, 21, "By (Seller):", sellerName, activeField == "seller")
    drawInputBox(3, 13, 21, "To (Buyer):", buyerName, activeField == "buyer")
    
    -- Price qty/item input fields side by side
    term.setCursorPos(3, 15)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.lightGray)
    term.write("Price Paid:")
    
    -- Price Amount
    if activeField == "priceQty" then
        term.setBackgroundColor(activeCol)
    else
        term.setBackgroundColor(inactiveCol)
    end
    term.setCursorPos(3, 16)
    term.write(" " .. priceQty .. string.rep(" ", 4 - #priceQty) .. " ")
    
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.lightGray)
    term.write(" x ")
    
    -- Price Item
    if activeField == "priceItem" then
        term.setBackgroundColor(activeCol)
    else
        term.setBackgroundColor(inactiveCol)
    end
    term.setTextColor(colors.white)
    local displayCurrency = priceItem
    if #displayCurrency > 11 then displayCurrency = displayCurrency:sub(1, 11) end
    term.write(" " .. displayCurrency .. string.rep(" ", 11 - #displayCurrency) .. " ")
    
    -- Left panel buttons
    drawButton(3, 18, 12, 1, "[ PRINT ]", colors.lime, colors.black)
    drawButton(16, 18, 8, 1, "[CLEAR]", colors.red, colors.white)
    
    -- RIGHT PANEL (Quick Items Grid)
    term.setCursorPos(27, 4)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.yellow)
    term.write("QUICK ITEMS")
    
    -- [+ Add] button
    drawButton(44, 4, 6, 1, "+ Add", colors.blue, colors.white)
    
    -- Grid display of quick items
    local startIdx = (page - 1) * itemsPerPage + 1
    local endIdx = math.min(#items, page * itemsPerPage)
    
    local gx, gy = 27, 6
    for idx = startIdx, endIdx do
        local item = items[idx]
        local btnBg = editMode and colors.orange or colors.cyan
        local btnFg = editMode and colors.black or colors.black
        
        -- Draw item block
        term.setBackgroundColor(btnBg)
        term.setTextColor(btnFg)
        term.setCursorPos(gx, gy)
        term.write(string.sub(item.name .. string.rep(" ", 11), 1, 11))
        term.setCursorPos(gx, gy + 1)
        term.write(string.sub(string.format("%dx %s", item.priceQty, item.priceItem) .. string.rep(" ", 11), 1, 11))
        
        -- Layout arithmetic
        gx = gx + 12
        if gx > 40 then
            gx = 27
            gy = gy + 3
        end
    end
    
    -- Paging buttons at bottom of grid
    if page > 1 then
        drawButton(27, 18, 6, 1, "<<", colors.lightGray, colors.black)
    end
    term.setCursorPos(35, 18)
    term.setBackgroundColor(bgCol)
    term.setTextColor(textCol)
    term.write(string.format("Page %d/%d", page, math.max(1, math.ceil(#items / itemsPerPage))))
    if endIdx < #items then
        drawButton(45, 18, 6, 1, ">>", colors.lightGray, colors.black)
    end
    
    -- Edit Mode toggle
    local modeText = editMode and "Edit Mode: [ ON ]" or "Edit Mode: [ OFF ]"
    local modeBg = editMode and colors.orange or colors.black
    local modeFg = editMode and colors.black or colors.white
    drawButton(27, 16, 23, 1, modeText, modeBg, modeFg)
    
    -- Draw Status Bar at very bottom
    drawButton(2, h - 1, w - 2, 1, " " .. statusMsg, colors.black, colors.white)
    
    -- DRAW MODAL (if active)
    if modal then
        -- Backdrop shadow
        term.setBackgroundColor(colors.black)
        for my = 5, 15 do
            term.setCursorPos(8, my)
            term.write(string.rep(" ", 36))
        end
        
        -- Modal Border & Window
        term.setTextColor(colors.white)
        lUtils.border(8, 5, 35, 11, nil, 3)
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        term.setCursorPos(9, 6)
        term.write(string.rep(" ", 33))
        term.setCursorPos(10, 6)
        term.write(modal == "add" and "Add New Quick Item" or "Edit Quick Item")
        
        -- Draw close "X" in modal
        term.setCursorPos(40, 6)
        term.write("\215")
        
        -- Form Fields
        drawInputBox(10, 8, 31, "Item Name:", modalItemName, modalActiveField == "name")
        
        -- Default Price quantity / item type
        term.setCursorPos(10, 11)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.write("Default Price:")
        
        -- Modal Qty Field
        if modalActiveField == "qty" then
            term.setBackgroundColor(activeCol)
        else
            term.setBackgroundColor(inactiveCol)
        end
        term.setTextColor(colors.white)
        term.setCursorPos(10, 12)
        term.write(" " .. modalPriceQty .. string.rep(" ", 4 - #modalPriceQty) .. " ")
        
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.write(" x ")
        
        -- Modal Currency/Item Field
        if modalActiveField == "item" then
            term.setBackgroundColor(activeCol)
        else
            term.setBackgroundColor(inactiveCol)
        end
        term.setTextColor(colors.white)
        term.write(" " .. modalPriceItem .. string.rep(" ", 19 - #modalPriceItem) .. " ")
        
        -- Action Buttons
        drawButton(10, 14, 10, 1, "Save", colors.green, colors.white)
        drawButton(22, 14, 10, 1, "Cancel", colors.gray, colors.white)
        if modal == "edit" then
            drawButton(34, 14, 7, 1, "Delete", colors.red, colors.white)
        end
    end
end

-- Add transaction receipt to log file
local function saveReceipt()
    local dateStr = os.date("%d/%m")
    
    -- Format receipt contents
    local lines = {}
    table.insert(lines, string.format("RECEIPT %s %s-%s", dateStr, sellerName, buyerName))
    table.insert(lines, "")
    table.insert(lines, "Sale of:")
    table.insert(lines, "")
    
    -- List items in cart
    local sortedCart = {}
    for name, qty in pairs(cart) do
        table.insert(sortedCart, { name = name, qty = qty })
    end
    table.sort(sortedCart, function(a, b) return a.name < b.name end)
    
    for _, entry in ipairs(sortedCart) do
        table.insert(lines, string.format("%dx %s", entry.qty, entry.name))
    end
    table.insert(lines, "")
    table.insert(lines, "By: " .. sellerName)
    table.insert(lines, "To: " .. buyerName)
    table.insert(lines, "Price:")
    table.insert(lines, "")
    table.insert(lines, string.format("%sx %s", priceQty, priceItem))
    
    local receiptText = table.concat(lines, "\n")
    
    -- Append to transactions file
    local exists = fs.exists("transactions")
    local f = fs.open("transactions", "a")
    if not exists then
        f.write("transactions:\n\n")
    else
        f.write("\n\n")
    end
    f.write(receiptText)
    f.close()
    
    -- Print to peripheral printer if available
    local printed = false
    local printer = peripheral.find("printer")
    if printer then
        local ok, err = pcall(function()
            printer.newPage()
            printer.write("Receipt - Store Manager POS")
            local px, py = printer.getCursorPos()
            printer.setCursorPos(1, py + 2)
            for _, line in ipairs(lines) do
                printer.write(line)
                px, py = printer.getCursorPos()
                printer.setCursorPos(1, py + 1)
            end
            printer.endPage()
        end)
        if ok then
            printed = true
        else
            statusMsg = "Printer error: " .. tostring(err)
        end
    end
    
    if printed then
        lUtils.popup("Success", "Receipt saved and printed successfully!", 29, 9, {"OK"})
        statusMsg = "Saved to transactions & Printed"
    else
        lUtils.popup("Success", "Receipt saved to transactions file!", 29, 9, {"OK"})
        statusMsg = "Saved to transactions file"
    end
    
    clearCart()
end

-- Event Handling
loadDatabase()
drawUI()

while true do
    local e = {os.pullEvent()}
    local eventName = e[1]
    
    if eventName == "term_resize" then
        w, h = term.getSize()
        drawUI()
        
    elseif eventName == "mouse_click" and e[2] == 1 then
        local cx, cy = e[3], e[4]
        
        -- Modal Clicks
        if modal then
            -- Click on Modal close button
            if cy == 6 and cx == 40 then
                modal = nil
                drawUI()
            -- Input Field selection in modal
            elseif cy >= 9 and cy <= 10 and cx >= 10 and cx <= 40 then
                modalActiveField = "name"
                drawUI()
            elseif cy == 12 and cx >= 10 and cx <= 15 then
                modalActiveField = "qty"
                drawUI()
            elseif cy == 12 and cx >= 19 and cx <= 39 then
                modalActiveField = "item"
                drawUI()
            -- Action buttons in modal
            elseif cy == 14 then
                if cx >= 10 and cx <= 19 then -- Save
                    if #modalItemName > 0 and tonumber(modalPriceQty) then
                        if modal == "add" then
                            table.insert(items, {
                                name = modalItemName,
                                priceQty = tonumber(modalPriceQty),
                                priceItem = modalPriceItem
                            })
                            statusMsg = "Added item: " .. modalItemName
                        else
                            items[editItemIndex] = {
                                name = modalItemName,
                                priceQty = tonumber(modalPriceQty),
                                priceItem = modalPriceItem
                            }
                            statusMsg = "Updated item: " .. modalItemName
                        end
                        saveDatabase()
                        modal = nil
                    else
                        statusMsg = "Error: Invalid inputs"
                    end
                    drawUI()
                elseif cx >= 22 and cx <= 31 then -- Cancel
                    modal = nil
                    drawUI()
                elseif modal == "edit" and cx >= 34 and cx <= 40 then -- Delete
                    table.remove(items, editItemIndex)
                    saveDatabase()
                    modal = nil
                    statusMsg = "Deleted item"
                    drawUI()
                end
            end
            
        else
            -- Main Clicks
            
            -- Close button (Header top right)
            if cy == 2 and cx >= w - 4 and cx <= w - 1 then
                break
            end
            
            -- Click on input boxes
            if cy >= 11 and cy <= 12 and cx >= 3 and cx <= 23 then
                activeField = "seller"
                drawUI()
            elseif cy >= 13 and cy <= 14 and cx >= 3 and cx <= 23 then
                activeField = "buyer"
                drawUI()
            elseif cy == 16 and cx >= 3 and cx <= 8 then
                activeField = "priceQty"
                drawUI()
            elseif cy == 16 and cx >= 12 and cx <= 23 then
                activeField = "priceItem"
                drawUI()
            
            -- Action buttons
            elseif cy == 18 and cx >= 3 and cx <= 14 then -- PRINT
                local cartEmpty = true
                for _ in pairs(cart) do cartEmpty = false break end
                
                if cartEmpty then
                    lUtils.popup("POS Error", "Cannot print an empty receipt!", 29, 9, {"OK"})
                elseif #sellerName == 0 or #buyerName == 0 then
                    lUtils.popup("POS Error", "Seller and Buyer names are required!", 29, 9, {"OK"})
                else
                    saveReceipt()
                end
                drawUI()
            elseif cy == 18 and cx >= 16 and cx <= 23 then -- CLEAR
                clearCart()
                drawUI()
                
            -- Quick Items section
            elseif cy == 4 and cx >= 44 and cx <= 49 then -- Add Quick Item
                modal = "add"
                modalItemName = ""
                modalPriceQty = "1"
                modalPriceItem = "Diamond"
                modalActiveField = "name"
                drawUI()
            elseif cy == 16 and cx >= 27 and cx <= 49 then -- Edit Mode Toggle
                editMode = not editMode
                drawUI()
            elseif cy == 18 and cx >= 27 and cx <= 32 then -- Prev Page
                if page > 1 then
                    page = page - 1
                    drawUI()
                end
            elseif cy == 18 and cx >= 45 and cx <= 50 then -- Next Page
                if page * itemsPerPage < #items then
                    page = page + 1
                    drawUI()
                end
            else
                -- Click on Quick Items Grid
                local startIdx = (page - 1) * itemsPerPage + 1
                local endIdx = math.min(#items, page * itemsPerPage)
                
                local gx, gy = 27, 6
                for idx = startIdx, endIdx do
                    if cx >= gx and cx <= gx + 11 and cy >= gy and cy <= gy + 1 then
                        if editMode then
                            -- Edit Item Modal
                            modal = "edit"
                            editItemIndex = idx
                            local item = items[idx]
                            modalItemName = item.name
                            modalPriceQty = tostring(item.priceQty)
                            modalPriceItem = item.priceItem
                            modalActiveField = "name"
                        else
                            -- Add item to cart
                            local item = items[idx]
                            cart[item.name] = (cart[item.name] or 0) + 1
                            autoCalcPrice()
                            statusMsg = "Added 1x " .. item.name
                        end
                        drawUI()
                        break
                    end
                    
                    gx = gx + 12
                    if gx > 40 then
                        gx = 27
                        gy = gy + 3
                    end
                end
            end
        end
        
    elseif eventName == "char" then
        local ch = e[2]
        if modal then
            if modalActiveField == "name" then
                modalItemName = modalItemName .. ch
                drawUI()
            elseif modalActiveField == "qty" then
                if tonumber(ch) then
                    modalPriceQty = modalPriceQty .. ch
                    drawUI()
                end
            elseif modalActiveField == "item" then
                modalPriceItem = modalPriceItem .. ch
                drawUI()
            end
        else
            if activeField == "seller" then
                sellerName = sellerName .. ch
                drawUI()
            elseif activeField == "buyer" then
                buyerName = buyerName .. ch
                drawUI()
            elseif activeField == "priceQty" then
                if tonumber(ch) then
                    priceQty = priceQty .. ch
                    drawUI()
                end
            elseif activeField == "priceItem" then
                priceItem = priceItem .. ch
                drawUI()
            end
        end
        
    elseif eventName == "key" then
        local k = e[2]
        if k == keys.backspace then
            if modal then
                if modalActiveField == "name" then
                    modalItemName = modalItemName:sub(1, #modalItemName - 1)
                    drawUI()
                elseif modalActiveField == "qty" then
                    modalPriceQty = modalPriceQty:sub(1, #modalPriceQty - 1)
                    drawUI()
                elseif modalActiveField == "item" then
                    modalPriceItem = modalPriceItem:sub(1, #modalPriceItem - 1)
                    drawUI()
                end
            else
                if activeField == "seller" then
                    sellerName = sellerName:sub(1, #sellerName - 1)
                    drawUI()
                elseif activeField == "buyer" then
                    buyerName = buyerName:sub(1, #buyerName - 1)
                    drawUI()
                elseif activeField == "priceQty" then
                    priceQty = priceQty:sub(1, #priceQty - 1)
                    drawUI()
                elseif activeField == "priceItem" then
                    priceItem = priceItem:sub(1, #priceItem - 1)
                    drawUI()
                end
            end
        elseif k == keys.enter then
            if modal then
                modalActiveField = nil
                drawUI()
            else
                activeField = nil
                drawUI()
            end
        elseif k == keys.tab then
            -- Tab cycling for fields
            if modal then
                if modalActiveField == "name" then
                    modalActiveField = "qty"
                elseif modalActiveField == "qty" then
                    modalActiveField = "item"
                else
                    modalActiveField = "name"
                end
            else
                if activeField == "seller" then
                    activeField = "buyer"
                elseif activeField == "buyer" then
                    activeField = "priceQty"
                elseif activeField == "priceQty" then
                    activeField = "priceItem"
                else
                    activeField = "seller"
                end
            end
            drawUI()
        end
    end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
