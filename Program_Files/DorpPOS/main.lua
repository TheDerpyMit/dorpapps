-- Program_Files/DorpPOS/main.lua
-- DorpPOS Application for LevelOS
-- A polished POS system following LevelOS UI conventions

shell.run("LevelOS/startup/lUtils")

-- ─────────────────────────────────────────
-- Database & Persistence
-- ─────────────────────────────────────────
local dbPath      = "AppData/DorpPOS/items.lconf"
local configPath  = "AppData/DorpPOS/config.lconf"

local items  = {}   -- { name, priceQty, priceItem }
local config = { merchantName = "Merchant", firstRun = true }

local function ensureDirs()
    if not fs.exists("AppData") then fs.makeDir("AppData") end
    -- Migrate old data if present
    if fs.exists("AppData/StoreManager") and not fs.exists("AppData/DorpPOS") then
        fs.copy("AppData/StoreManager", "AppData/DorpPOS")
    end
    if not fs.exists("AppData/DorpPOS") then fs.makeDir("AppData/DorpPOS") end
end

local function loadDatabase()
    ensureDirs()
    if fs.exists(dbPath) then
        local f = fs.open(dbPath, "r")
        local d = textutils.unserialize(f.readAll())
        f.close()
        if type(d) == "table" then items = d end
    else
        items = {
            { name = "Diamond Sword",     priceQty = 3, priceItem = "Diamond"    },
            { name = "Enchanted Apple",   priceQty = 8, priceItem = "Gold Ingot" },
            { name = "Golden Carrot",     priceQty = 2, priceItem = "Gold Ingot" },
            { name = "Iron Ingot",        priceQty = 4, priceItem = "Coal"       },
            { name = "Potion of Healing", priceQty = 1, priceItem = "Emerald"    },
            { name = "Diamond",           priceQty = 2, priceItem = "Emerald"    },
            { name = "Emerald",           priceQty = 1, priceItem = "Gold Ingot" },
            { name = "Steak",             priceQty = 1, priceItem = "Coal"       },
        }
        local f = fs.open(dbPath, "w") f.write(textutils.serialize(items)) f.close()
    end
end

local function saveDatabase()
    ensureDirs()
    local f = fs.open(dbPath, "w") f.write(textutils.serialize(items)) f.close()
end

local function loadConfig()
    ensureDirs()
    if fs.exists(configPath) then
        local f = fs.open(configPath, "r")
        local d = textutils.unserialize(f.readAll())
        f.close()
        if type(d) == "table" then config = d end
    end
end

local function saveConfig()
    ensureDirs()
    local f = fs.open(configPath, "w") f.write(textutils.serialize(config)) f.close()
end

-- ─────────────────────────────────────────
-- State
-- ─────────────────────────────────────────
local w, h          = term.getSize()
local cart          = {}   -- map item_name -> qty
local sellerName    = ""
local buyerName     = ""
local priceQty      = "0"
local priceItem     = "Diamond"
local activeField   = nil  -- "seller"|"buyer"
local priceScroll   = 1
local editMode      = false
local page          = 1
local ITEMS_PER_ROW = 2
local ROWS_PER_PAGE = 4
local ITEMS_PER_PAGE= ITEMS_PER_ROW * ROWS_PER_PAGE
local statusMsg     = "Ready"
local unsaved       = false  -- dirty flag for config/items

-- Menu bar button regions
local menuBtns = {
    { label = "File", x = 0, w = 0, options = { "Save Settings" }                       },
    { label = "Info", x = 0, w = 0, options = { "How to Use" }                           },
}

-- ─────────────────────────────────────────
-- Helper: clamp strings for display
-- ─────────────────────────────────────────
local function clamp(s, maxLen)
    if #s > maxLen then return s:sub(1, maxLen - 1) .. "\187" end
    return s
end

local priceOverridden = false

-- ─────────────────────────────────────────
-- Auto price calculation from cart
-- ─────────────────────────────────────────
local function autoCalcPrice()
    if priceOverridden then return end
    
    local totals = {}
    local firstCurrency = nil
    for name, qty in pairs(cart) do
        for _, item in ipairs(items) do
            if item.name == name then
                totals[item.priceItem] = (totals[item.priceItem] or 0) + item.priceQty * qty
                if not firstCurrency then firstCurrency = item.priceItem end
                break
            end
        end
    end
    
    if firstCurrency then
        priceItem = firstCurrency
        priceQty = tostring(totals[firstCurrency] or 0)
    else
        priceQty = "0"
    end
end

local function clearCart()
    cart = {}
    priceQty = "0"
    priceOverridden = false
    statusMsg = "Cart cleared"
end

-- ─────────────────────────────────────────
-- Drawing helpers
-- ─────────────────────────────────────────
local function fill(x, y, width, bg)
    term.setCursorPos(x, y)
    term.setBackgroundColor(bg)
    term.write(string.rep(" ", width))
end

local function label(x, y, txt, fg, bg)
    term.setCursorPos(x, y)
    term.setBackgroundColor(bg or colors.gray)
    term.setTextColor(fg or colors.white)
    term.write(txt)
end

-- Draw a 1-row themed button (LevelOS border style, layer 1)
local function flatBtn(x, y, w2, text, bg, fg, selected)
    local abg = selected and colors.lightGray or bg
    local afg = selected and colors.black or fg
    term.setCursorPos(x, y)
    term.setBackgroundColor(abg)
    term.setTextColor(afg)
    local display = string.rep(" ", math.floor((w2 - #text) / 2)) .. text
    display = display .. string.rep(" ", w2 - #display)
    term.write(display:sub(1, w2))
end

-- Draw a thick "card" item button (2 lines high) like a POS tile
local function itemBtn(x, y, bw, bh, name, price, isEdit, isSelected)
    local bg = isEdit and colors.orange or (isSelected and colors.lightGray or colors.blue)
    local fg = (isEdit or isSelected) and colors.black or colors.white
    local subFg = isEdit and colors.black or colors.lightGray
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    for row = 0, bh - 1 do
        term.setCursorPos(x, y + row)
        term.write(string.rep(" ", bw))
    end
    -- Name centred on line 1
    local nameLine = clamp(name, bw)
    term.setCursorPos(x + math.floor((bw - #nameLine) / 2), y)
    term.setTextColor(fg)
    term.write(nameLine)
    -- Price on line 2
    if bh >= 2 then
        term.setCursorPos(x + 1, y + 1)
        term.setTextColor(subFg)
        term.write(clamp(price, bw - 2))
    end
end

-- ─────────────────────────────────────────
-- Menu bar (row 1, LevelOS style)
-- ─────────────────────────────────────────
local function drawMenuBar()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local cx = 1
    for _, btn in ipairs(menuBtns) do
        btn.x = cx
        btn.w = #btn.label + 2
        term.setCursorPos(cx, 1)
        term.write(" " .. btn.label .. " ")
        cx = cx + btn.w
    end
    -- App title right-side
    local title = "DorpPOS"
    term.setCursorPos(w - #title, 1)
    term.setTextColor(colors.lightGray)
    term.write(title)
    -- Separator line (character 131)
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\131", w))
end

-- ─────────────────────────────────────────
-- Left panel: Cart & Transaction fields
-- ─────────────────────────────────────────
local DIVX = 24   -- x position of vertical separator

local function drawLeftPanel()
    -- Panel background fill
    for row = 3, h - 1 do
        fill(1, row, DIVX - 1, colors.gray)
    end

    -- Cart list
    local cartList = {}
    for n, q in pairs(cart) do table.insert(cartList, {n, q}) end
    table.sort(cartList, function(a2, b2) return a2[1] < b2[1] end)

    local maxRows = 5
    for i = 1, maxRows do
        local cy = 3 + i
        if cartList[i] then
            local entry = string.format("%dx %s", cartList[i][2], clamp(cartList[i][1], 16))
            label(2, cy, entry, colors.white, colors.gray)
        else
            label(2, cy, string.rep(" ", DIVX - 2), colors.gray, colors.gray)
        end
    end
    if #cartList == 0 then
        label(2, 4, "(Cart is empty)", colors.lightGray, colors.gray)
    end

    -- Divider
    term.setCursorPos(1, 9)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", DIVX - 1))

    -- Seller field (row 10)
    label(2, 10, "By: ", colors.lightGray, colors.gray)
    local activeS = activeField == "seller"
    term.setCursorPos(6, 10)
    term.setBackgroundColor(activeS and colors.blue or colors.black)
    term.setTextColor(colors.white)
    local dispS = sellerName
    local sW = DIVX - 8
    if #dispS > sW then dispS = dispS:sub(#dispS - (sW - 1)) end
    term.write(" " .. dispS .. string.rep(" ", sW - #dispS) .. " ")

    -- Buyer field (row 11)
    label(2, 11, "To: ", colors.lightGray, colors.gray)
    local activeB = activeField == "buyer"
    term.setCursorPos(6, 11)
    term.setBackgroundColor(activeB and colors.blue or colors.black)
    term.setTextColor(colors.white)
    local dispB = buyerName
    if #dispB > sW then dispB = dispB:sub(#dispB - (sW - 1)) end
    term.write(" " .. dispB .. string.rep(" ", sW - #dispB) .. " ")

    -- Divider
    term.setCursorPos(1, 12)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", DIVX - 1))

    -- Price row header (row 13)
    label(2, 13, "PRICE:", colors.yellow, colors.gray)
    local editBg = priceOverridden and colors.orange or colors.blue
    local editFg = priceOverridden and colors.black or colors.white
    flatBtn(DIVX - 8, 13, 6, "Edit", editBg, editFg)

    -- Dynamic Price list (scrollable, rows 14 to h - 4)
    local startY = 14
    local endY = h - 4
    local maxPriceLines = endY - startY + 1

    local priceLines = {}
    if priceOverridden then
        table.insert(priceLines, string.format("%sx %s", priceQty, priceItem))
    else
        local totals = {}
        local order = {}
        for name, qty in pairs(cart) do
            for _, item in ipairs(items) do
                if item.name == name then
                    if not totals[item.priceItem] then
                        table.insert(order, item.priceItem)
                    end
                    totals[item.priceItem] = (totals[item.priceItem] or 0) + item.priceQty * qty
                    break
                end
            end
        end
        table.sort(order)
        if #order == 0 then
            table.insert(priceLines, "0x " .. priceItem)
        else
            for _, cur in ipairs(order) do
                table.insert(priceLines, string.format("%dx %s", totals[cur], cur))
            end
        end
    end

    -- Clamp scroll state
    if priceScroll < 1 then priceScroll = 1 end
    if priceScroll > #priceLines - maxPriceLines + 1 then
        priceScroll = math.max(1, #priceLines - maxPriceLines + 1)
    end

    for i = 1, maxPriceLines do
        local lineY = startY + i - 1
        local idx = priceScroll + i - 1
        if priceLines[idx] then
            label(2, lineY, clamp(priceLines[idx], DIVX - 3), colors.white, colors.gray)
        else
            label(2, lineY, string.rep(" ", DIVX - 3), colors.gray, colors.gray)
        end
    end

    -- Draw scroll indicator or paging if there are more than maxPriceLines
    if #priceLines > maxPriceLines then
        if priceScroll > 1 then
            label(DIVX - 2, startY, "\24", colors.yellow, colors.gray)
        end
        if priceScroll + maxPriceLines - 1 < #priceLines then
            label(DIVX - 2, endY, "\25", colors.yellow, colors.gray)
        end
    end

    -- Divider at h - 3
    term.setCursorPos(1, h - 3)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.write(string.rep("\140", DIVX - 1))

    -- Action buttons: PRINT + CLEAR at h - 2
    local btnW = math.floor((DIVX - 3) / 2)
    flatBtn(2, h - 2, btnW, "PRINT", colors.lime, colors.black)
    flatBtn(2 + btnW + 1, h - 2, btnW, "CLEAR", colors.red, colors.white)

    -- Raised border around left panel (black outer bg makes this pop)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    lUtils.border(1, 3, DIVX - 1, h - 1, nil, 3)

    -- Blue section header strip inside the border (row 3, from x=2 to x=DIVX-2)
    term.setCursorPos(2, 3)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    local headerText = " CART"
    term.write(headerText .. string.rep(" ", (DIVX - 3) - #headerText))
end

-- ─────────────────────────────────────────
-- Right panel: Quick Items grid
-- ─────────────────────────────────────────
local GRID_X     = DIVX + 1
local GRID_W     = 0  -- computed in drawRightPanel
local BTN_W      = 0
local BTN_H      = 2
local BTN_GAP    = 1

local function drawRightPanel()
    GRID_W = w - DIVX
    BTN_W  = math.floor((GRID_W - BTN_GAP * (ITEMS_PER_ROW + 1)) / ITEMS_PER_ROW)

    -- Panel background
    for row = 3, h - 1 do
        fill(DIVX, row, w - DIVX + 1, colors.gray)
    end

    -- Edit mode toggle
    local editLabel = editMode and "[ Edit: ON ]" or "[ Edit: OFF ]"
    local editBg    = editMode and colors.orange or colors.gray
    local editFg    = editMode and colors.black or colors.lightGray
    flatBtn(DIVX + 2, 4, #editLabel, editLabel, editBg, editFg)

    -- Draw grid
    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local row_y = 6
    local col   = 0

    for idx = startIdx, math.min(#items, page * ITEMS_PER_PAGE) do
        local item     = items[idx]
        local bx       = DIVX + 1 + BTN_GAP + col * (BTN_W + BTN_GAP)
        local priceStr = string.format("%dx %s", item.priceQty, item.priceItem)
        itemBtn(bx, row_y, BTN_W, BTN_H, item.name, priceStr, editMode, false)

        col = col + 1
        if col >= ITEMS_PER_ROW then
            col = 0
            row_y = row_y + BTN_H + 1
        end
    end

    -- Paging bar
    local maxPage = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
    local pageStr = string.format(" Page %d/%d ", page, maxPage)

    term.setCursorPos(DIVX, h - 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write(string.rep(" ", GRID_W + 1))

    if page > 1 then
        term.setCursorPos(DIVX + 1, h - 1)
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
        term.write(" \17 ")
    end
    if page < maxPage then
        term.setCursorPos(w - 2, h - 1)
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
        term.write(" \16 ")
    end
    term.setCursorPos(DIVX + math.floor((GRID_W - #pageStr) / 2), h - 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write(pageStr)

    -- Raised border around right panel
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    lUtils.border(DIVX, 3, w, h - 1, nil, 3)

    -- Blue section header strip inside the border (row 3, from x=DIVX+1 to x=w-1)
    term.setCursorPos(DIVX + 1, 3)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    term.write(string.rep(" ", w - DIVX - 1))
    
    term.setCursorPos(DIVX + 2, 3)
    term.write("QUICK ITEMS")

    local addLabel  = "+ Add Item"
    local addX = w - #addLabel - 1
    term.setCursorPos(addX, 3)
    term.setBackgroundColor(colors.cyan)
    term.setTextColor(colors.black)
    term.write(addLabel)
end

-- ─────────────────────────────────────────
-- Status bar (bottom row)
-- ─────────────────────────────────────────
local function drawStatusBar()
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write(string.rep(" ", w))
    term.setCursorPos(1, h)
    term.write(" " .. clamp(statusMsg, w - 2))
end

-- ─────────────────────────────────────────
-- Full redraw
-- ─────────────────────────────────────────
local function drawUI()
    w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawMenuBar()
    drawLeftPanel()
    drawRightPanel()
    drawStatusBar()
end

-- ─────────────────────────────────────────
-- Grid hit-test: returns item index or nil
-- ─────────────────────────────────────────
local function getGridItem(cx, cy)
    GRID_W = w - DIVX
    BTN_W  = math.floor((GRID_W - BTN_GAP * (ITEMS_PER_ROW + 1)) / ITEMS_PER_ROW)
    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local row_y, col = 6, 0
    for idx = startIdx, math.min(#items, page * ITEMS_PER_PAGE) do
        local bx = DIVX + 1 + BTN_GAP + col * (BTN_W + BTN_GAP)
        if cx >= bx and cx <= bx + BTN_W - 1 and cy >= row_y and cy <= row_y + BTN_H - 1 then
            return idx
        end
        col = col + 1
        if col >= ITEMS_PER_ROW then col = 0; row_y = row_y + BTN_H + 1 end
    end
    return nil
end

-- ─────────────────────────────────────────
-- Modal: Custom Price editor
-- ─────────────────────────────────────────
local function showPriceEditModal()
    local mQty = priceQty
    local mItem = priceItem
    local function priceEditFn()
        local mw, mh = term.getSize()
        local function redraw(activeF)
            term.setBackgroundColor(colors.lightGray)
            term.clear()
            term.setTextColor(colors.black)
            lUtils.border(1, 1, mw, mh, nil, 3)
            
            label(2, 2, "Custom Quantity:", colors.black, colors.lightGray)
            term.setCursorPos(2, 3)
            term.setBackgroundColor(activeF == "qty" and colors.blue or colors.white)
            term.setTextColor(activeF == "qty" and colors.white or colors.black)
            term.write(" " .. clamp(mQty, mw - 4) .. string.rep(" ", mw - 4 - #mQty) .. " ")
            
            label(2, 5, "Custom Currency:", colors.black, colors.lightGray)
            term.setCursorPos(2, 6)
            term.setBackgroundColor(activeF == "item" and colors.blue or colors.white)
            term.setTextColor(activeF == "item" and colors.white or colors.black)
            term.write(" " .. clamp(mItem, mw - 4) .. string.rep(" ", mw - 4 - #mItem) .. " ")
            
            flatBtn(2, mh - 2, 8, "Save", colors.lime, colors.black)
            flatBtn(12, mh - 2, 8, "Cancel", colors.gray, colors.white)
            if priceOverridden then
                flatBtn(22, mh - 2, 8, "Reset", colors.red, colors.white)
            end
        end
        local activeF = "qty"
        redraw(activeF)
        while true do
            local e = {os.pullEvent()}
            if e[1] == "mouse_click" and e[2] == 1 then
                local cx2, cy2 = e[3], e[4]
                if cy2 == 3 then activeF = "qty"; redraw(activeF)
                elseif cy2 == 6 then activeF = "item"; redraw(activeF)
                elseif cy2 == mh - 2 then
                    if cx2 >= 2 and cx2 <= 9 then return "save", mQty, mItem
                    elseif cx2 >= 12 and cx2 <= 19 then return "cancel"
                    elseif priceOverridden and cx2 >= 22 and cx2 <= 29 then return "reset" end
                end
            elseif e[1] == "char" then
                if activeF == "qty" and tonumber(e[2]) then mQty = mQty .. e[2]
                elseif activeF == "item" then mItem = mItem .. e[2] end
                redraw(activeF)
            elseif e[1] == "key" then
                if e[2] == keys.backspace then
                    if activeF == "qty" then mQty = mQty:sub(1, -2)
                    elseif activeF == "item" then mItem = mItem:sub(1, -2) end
                    redraw(activeF)
                elseif e[2] == keys.tab then
                    activeF = (activeF == "qty") and "item" or "qty"
                    redraw(activeF)
                elseif e[2] == keys.enter then
                    return "save", mQty, mItem
                end
            end
        end
    end
    
    local mw2, mh2 = 32, 9
    local res, rQty, rItem = lUtils.openWin("Custom Price", priceEditFn, math.floor((w - mw2)/2), math.floor((h - mh2)/2), mw2, mh2, false, false)
    drawUI()
    if res == "save" and #rItem > 0 then
        priceQty = rQty
        priceItem = rItem
        priceOverridden = true
        statusMsg = "Custom price set"
    elseif res == "reset" then
        priceOverridden = false
        autoCalcPrice()
        statusMsg = "Price reset to automatic"
    end
end

-- ─────────────────────────────────────────
-- Modal: Add / Edit item
-- Fully draggable via lUtils.openWin
-- ─────────────────────────────────────────
local function showItemModal(existingItem, itemIdx)
    local mTitle   = existingItem and "Edit Item" or "Add New Item"
    local mName    = existingItem and existingItem.name    or ""
    local mQty     = existingItem and tostring(existingItem.priceQty) or "1"
    local mCur     = existingItem and existingItem.priceItem or "Diamond"
    local mDeleted = false

    local function modalFn()
        local mw, mh = term.getSize()
        local function redraw(activeF)
            term.setBackgroundColor(colors.lightGray)
            term.clear()
            
            -- Draw border around the modal window
            term.setTextColor(colors.black)
            lUtils.border(1, 1, mw, mh, nil, 3)

            -- Content
            label(2, 2, "Item Name:", colors.black, colors.lightGray)
            term.setCursorPos(2, 3)
            term.setBackgroundColor(activeF == "name" and colors.blue or colors.white)
            term.setTextColor(activeF == "name" and colors.white or colors.black)
            term.write(" " .. clamp(mName, mw - 4) .. string.rep(" ", mw - 4 - math.min(#mName, mw - 4)) .. " ")

            label(2, 5, "Default Price:", colors.black, colors.lightGray)
            -- Qty
            term.setCursorPos(2, 6)
            term.setBackgroundColor(activeF == "qty" and colors.blue or colors.white)
            term.setTextColor(activeF == "qty" and colors.white or colors.black)
            term.write(" " .. clamp(mQty, 5) .. string.rep(" ", 5 - math.min(#mQty, 5)) .. " ")
            
            term.setBackgroundColor(colors.lightGray)
            term.setTextColor(colors.black)
            term.write(" x ")
            
            term.setCursorPos(10, 6)
            term.setBackgroundColor(activeF == "cur" and colors.blue or colors.white)
            term.setTextColor(activeF == "cur" and colors.white or colors.black)
            local cw2 = mw - 11
            term.write(" " .. clamp(mCur, cw2) .. string.rep(" ", cw2 - math.min(#mCur, cw2)) .. " ")

            -- Buttons
            local saveBg = colors.lime
            local y8 = mh - 2
            flatBtn(2, y8, 8, "Save", saveBg, colors.black)
            flatBtn(12, y8, 8, "Cancel", colors.gray, colors.white)
            if existingItem then
                flatBtn(22, y8, 8, "Delete", colors.red, colors.white)
            end
        end

        local activeF = "name"
        redraw(activeF)

        while true do
            local e = {os.pullEvent()}
            if e[1] == "term_resize" then
                mw, mh = term.getSize()
                redraw(activeF)
            elseif e[1] == "mouse_click" and e[2] == 1 then
                local cx2, cy2 = e[3], e[4]
                local y8 = mh - 2
                if cy2 == 3 then
                    activeF = "name"; redraw(activeF)
                elseif cy2 == 6 and cx2 >= 2 and cx2 <= 8 then
                    activeF = "qty"; redraw(activeF)
                elseif cy2 == 6 and cx2 >= 12 then
                    activeF = "cur"; redraw(activeF)
                elseif cy2 == y8 then
                    if cx2 >= 2 and cx2 <= 9 then
                        -- Save
                        local qty = tonumber(mQty)
                        if #mName > 0 and qty and qty > 0 and #mCur > 0 then
                            return "save", mName, qty, mCur
                        end
                    elseif cx2 >= 12 and cx2 <= 19 then
                        return "cancel"
                    elseif existingItem and cx2 >= 22 and cx2 <= 29 then
                        return "delete"
                    end
                end
            elseif e[1] == "char" then
                if activeF == "name" then mName = mName .. e[2]
                elseif activeF == "qty" and tonumber(e[2]) then mQty = mQty .. e[2]
                elseif activeF == "cur" then mCur = mCur .. e[2]
                end
                redraw(activeF)
            elseif e[1] == "key" then
                if e[2] == keys.backspace then
                    if activeF == "name" then mName = mName:sub(1, -2)
                    elseif activeF == "qty" then mQty = mQty:sub(1, -2)
                    elseif activeF == "cur" then mCur = mCur:sub(1, -2)
                    end
                    redraw(activeF)
                elseif e[2] == keys.tab then
                    if activeF == "name" then activeF = "qty"
                    elseif activeF == "qty" then activeF = "cur"
                    else activeF = "name" end
                    redraw(activeF)
                elseif e[2] == keys.enter then
                    local qty = tonumber(mQty)
                    if #mName > 0 and qty and qty > 0 and #mCur > 0 then
                        return "save", mName, qty, mCur
                    end
                end
            end
        end
    end

    -- Calculate modal dimensions
    local mw2, mh2 = 32, 11
    local mx = math.floor((w - mw2) / 2)
    local my = math.floor((h - mh2) / 2)

    local result, rName, rQty, rCur = lUtils.openWin(mTitle, modalFn, mx, my, mw2, mh2, false, false)

    drawUI()  -- restore screen

    if result == "save" then
        if existingItem then
            items[itemIdx] = { name = rName, priceQty = rQty, priceItem = rCur }
            statusMsg = "Updated: " .. rName
        else
            table.insert(items, { name = rName, priceQty = rQty, priceItem = rCur })
            statusMsg = "Added: " .. rName
        end
        saveDatabase()
    elseif result == "delete" then
        table.remove(items, itemIdx)
        saveDatabase()
        statusMsg = "Deleted item"
    end
end

-- ─────────────────────────────────────────
-- Modal: Merchant name edit
-- ─────────────────────────────────────────
local function showSettingsModal()
    local mName  = config.merchantName
    local function settingsFn()
        local mw, mh = term.getSize()
        local function redraw()
            term.setBackgroundColor(colors.lightGray)
            term.clear()
            
            -- Draw border around the modal window
            term.setTextColor(colors.black)
            lUtils.border(1, 1, mw, mh, nil, 3)

            label(2, 2, "Merchant Name:", colors.black, colors.lightGray)
            term.setCursorPos(2, 3)
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
            local d = clamp(mName, mw - 4)
            term.write(" " .. d .. string.rep(" ", mw - 4 - #d) .. " ")
            label(2, 5, "Press Enter or click Save", colors.black, colors.lightGray)
            flatBtn(2, mh - 2, 8, "Save", colors.lime, colors.black)
            flatBtn(12, mh - 2, 8, "Cancel", colors.gray, colors.white)
        end
        redraw()
        while true do
            local e = {os.pullEvent()}
            if e[1] == "char" then mName = mName .. e[2]; redraw()
            elseif e[1] == "key" then
                if e[2] == keys.backspace then mName = mName:sub(1, -2); redraw()
                elseif e[2] == keys.enter then return "save", mName end
            elseif e[1] == "mouse_click" and e[2] == 1 then
                local mh2 = select(2, term.getSize())
                if e[4] == mh2 - 2 then
                    if e[3] >= 2 and e[3] <= 9 then return "save", mName
                    elseif e[3] >= 12 and e[3] <= 19 then return "cancel" end
                end
            elseif e[1] == "term_resize" then redraw()
            end
        end
    end

    local mw2, mh2 = 30, 9
    local result, rName = lUtils.openWin("Store Settings", settingsFn, math.floor((w - mw2) / 2), math.floor((h - mh2) / 2), mw2, mh2, false, false)

    drawUI()
    if result == "save" and #rName > 0 then
        config.merchantName = rName
        sellerName = rName
        saveConfig()
        statusMsg = "Settings saved"
    end
end

-- ─────────────────────────────────────────
-- Tutorial modal (first run / File > Info)
-- ─────────────────────────────────────────
local function showTutorial()
    local pages2 = {
        {
            title = "Welcome to DorpPOS!",
            text = {
                "This app lets you quickly",
                "build receipts and print them",
                "using a visual POS interface.",
                "",
                "Navigation: Use the menu bar",
                "at the top for File/Info.",
            }
        },
        {
            title = "Quick Items Grid",
            text = {
                "Click an item button to add",
                "it to your cart.",
                "",
                "Toggle Edit Mode to change",
                "prices or remove items.",
                "",
                "Click '+ Add Item' to create",
                "a new button.",
            }
        },
        {
            title = "Cart & Receipt",
            text = {
                "Fill in Seller and Buyer.",
                "The price auto-fills from",
                "your item defaults.",
                "",
                "Click PRINT to save to the",
                "/transactions file and send",
                "to a connected printer.",
            }
        },
        {
            title = "Receipt Format",
            text = {
                "RECEIPT DD/MM NAME1-NAME2",
                "",
                "Sale of:",
                "  Nx [item]",
                "",
                "By: NAME1 / To: NAME2",
                "Price: Nx [currency]",
            }
        },
    }

    local pg = 1
    local function tutFn()
        local mw, mh = term.getSize()
        local function redraw()
            term.setBackgroundColor(colors.lightGray)
            term.clear()
            
            -- Draw border around the modal window
            term.setTextColor(colors.black)
            lUtils.border(1, 1, mw, mh, nil, 3)

            local p = pages2[pg]
            
            -- Inset Title strip (drawn at y=2, width = mw-2)
            term.setCursorPos(2, 2)
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
            local titleLine = " " .. p.title
            term.write(titleLine .. string.rep(" ", mw - 2 - #titleLine))

            -- Text body (moved to y = 3 + i, background lightGray, text black)
            for i, ln in ipairs(p.text) do
                label(2, 3 + i, ln, colors.black, colors.lightGray)
            end

            -- Paging
            local pageStr2 = pg .. "/" .. #pages2
            label(mw - #pageStr2 - 1, mh - 2, pageStr2, colors.gray, colors.lightGray)
            if pg > 1 then flatBtn(2, mh - 2, 8, "\17 Prev", colors.gray, colors.white) end
            if pg < #pages2 then flatBtn(mw - 9, mh - 2, 9, "Next \16", colors.gray, colors.white) end
            flatBtn(math.floor(mw / 2) - 4, mh - 2, 8, "Close", colors.gray, colors.white)
        end
        redraw()
        local clickedRow = nil
        while true do
            local e = {os.pullEvent()}
            if e[1] == "term_resize" then
                mw, mh = term.getSize()
                redraw()
            elseif e[1] == "mouse_click" and e[2] == 1 then
                -- Record the row clicked; act on mouse_up to avoid leaving
                -- a dangling mouse_up event that lUtils.openWin mishandles
                clickedRow = e[4]
            elseif e[1] == "mouse_up" and e[2] == 1 then
                local mw2, mh2 = term.getSize()
                if clickedRow and clickedRow == mh2 - 2 and e[4] == mh2 - 2 then
                    if pg > 1 and e[3] >= 2 and e[3] <= 9 then
                        pg = pg - 1; redraw()
                    elseif pg < #pages2 and e[3] >= mw2 - 8 then
                        pg = pg + 1; redraw()
                    elseif e[3] >= math.floor(mw2 / 2) - 4 and e[3] <= math.floor(mw2 / 2) + 3 then
                        return  -- Close button
                    end
                end
                clickedRow = nil
            elseif e[1] == "key" and (e[2] == keys.enter or e[2] == keys.q) then
                return
            end
        end
    end

    local mw3, mh3 = 38, 14
    lUtils.openWin("How to Use DorpPOS", tutFn, math.floor((w - mw3) / 2), math.floor((h - mh3) / 2), mw3, mh3, false, false)
    drawUI()
end

local function printReceipt()
    local cartEmpty = true
    for _ in pairs(cart) do cartEmpty = false break end
    if cartEmpty then lUtils.popup("DorpPOS", "Cart is empty!", 27, 7, {"OK"}); drawUI(); return end
    if #sellerName == 0 or #buyerName == 0 then lUtils.popup("DorpPOS", "Seller and Buyer names are required!", 32, 7, {"OK"}); drawUI(); return end

    local dateStr = os.date and os.date("%d/%m") or "00/00"
    local lines2 = {
        "-------------------------",
        string.format("RECEIPT %s %s-%s", dateStr, sellerName, buyerName),
        "-------------------------",
        "Sale of:",
        "",
    }
    
    local sorted = {}
    for n, q in pairs(cart) do table.insert(sorted, {n, q}) end
    table.sort(sorted, function(a2, b2) return a2[1] < b2[1] end)
    for _, e2 in ipairs(sorted) do table.insert(lines2, string.format("%dx %s", e2[2], e2[1])) end
    
    table.insert(lines2, "")
    table.insert(lines2, "By: " .. sellerName)
    table.insert(lines2, "To: " .. buyerName)
    table.insert(lines2, "Price:")
    table.insert(lines2, "")
    
    if priceOverridden then
        table.insert(lines2, string.format("%sx %s", priceQty, priceItem))
    else
        -- Compute multi-currency totals
        local totals = {}
        local order = {}
        for name, qty in pairs(cart) do
            for _, item in ipairs(items) do
                if item.name == name then
                    if not totals[item.priceItem] then
                        table.insert(order, item.priceItem)
                    end
                    totals[item.priceItem] = (totals[item.priceItem] or 0) + item.priceQty * qty
                    break
                end
            end
        end
        table.sort(order)
        if #order == 0 then
            table.insert(lines2, "0x " .. priceItem)
        else
            for _, cur in ipairs(order) do
                table.insert(lines2, string.format("%dx %s", totals[cur], cur))
            end
        end
    end
    
    table.insert(lines2, "-------------------------")
    table.insert(lines2, "Thank you for your purchase")
    table.insert(lines2, "Powered by DorpPOS")
    table.insert(lines2, "-------------------------")

    -- Append to /transactions
    local existingFile = fs.exists("transactions")
    local tf = fs.open("transactions", "a")
    if not existingFile then tf.write("transactions:\n\n") else tf.write("\n\n") end
    tf.write(table.concat(lines2, "\n"))
    tf.close()

    -- Try printer with proper word-wrapping and paging
    local printed = false
    local printer = peripheral.find("printer")
    if printer then
        local ok = pcall(function()
            printer.newPage()
            printer.setPageTitle("Receipt - DorpPOS")
            local y = 1
            for _, line in ipairs(lines2) do
                local wrapped = lUtils.wordwrap(line, 25)
                for _, wl in ipairs(#wrapped > 0 and wrapped or {""}) do
                    if y > 21 then
                        printer.endPage()
                        printer.newPage()
                        y = 1
                    end
                    printer.setCursorPos(1, y)
                    printer.write(wl)
                    y = y + 1
                end
            end
            printer.endPage()
        end)
        if ok then printed = true end
    end

    clearCart()
    if printed then
        lUtils.popup("DorpPOS", "Receipt saved and printed!", 29, 7, {"OK"})
        statusMsg = "Receipt saved & printed"
    else
        lUtils.popup("DorpPOS", "Receipt saved to /transactions", 31, 7, {"OK"})
        statusMsg = "Receipt saved to /transactions"
    end
    drawUI()
end

-- ─────────────────────────────────────────
-- Handle a menu button click
-- ─────────────────────────────────────────
local function handleMenu(btn)
    local cy = 3
    term.setCursorPos(btn.x, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(" " .. btn.label .. " ")

    local ok, _, item = lUtils.clickmenu(btn.x, cy, 18, btn.options, true, nil, {bg = colors.gray, txt = colors.white, fg = colors.lightGray, selected = colors.blue})
    drawMenuBar()
    if not ok then return end

    if item == "Save Settings" then
        showSettingsModal()
    elseif item == "How to Use" then
        showTutorial()
    end
end

-- ─────────────────────────────────────────
-- Keyboard input routing
-- ─────────────────────────────────────────
local function handleChar(ch)
    if activeField == "seller" then sellerName = sellerName .. ch
    elseif activeField == "buyer" then buyerName = buyerName .. ch
    elseif activeField == "priceQty" and tonumber(ch) then 
        priceQty = priceQty .. ch
        priceOverridden = true
    elseif activeField == "priceItem" then 
        priceItem = priceItem .. ch
        priceOverridden = true
    else return false end
    return true
end

local function handleBackspace()
    if activeField == "seller" then sellerName = sellerName:sub(1, -2)
    elseif activeField == "buyer" then buyerName = buyerName:sub(1, -2)
    elseif activeField == "priceQty" then 
        priceQty = priceQty:sub(1, -2)
        priceOverridden = true
    elseif activeField == "priceItem" then 
        priceItem = priceItem:sub(1, -2)
        priceOverridden = true
    else return false end
    return true
end

local function handleTab()
    local cycle = {"seller", "buyer", "priceQty", "priceItem"}
    if not activeField then activeField = "seller"; return end
    for i, f in ipairs(cycle) do
        if f == activeField then activeField = cycle[i % #cycle + 1]; return end
    end
    activeField = "seller"
end

-- ─────────────────────────────────────────
-- Boot sequence
-- ─────────────────────────────────────────
loadConfig()
loadDatabase()
sellerName = config.merchantName

-- ─────────────────────────────────────────
-- Printer check
-- ─────────────────────────────────────────
do
    local printer = peripheral.find("printer")
    if not printer then
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        lUtils.popup(
            "DorpPOS",
            "No printer detected!\n\nDorpPOS needs a printer\nattached to work properly.\n\nPlease connect a printer and\nrelaunch the app.",
            36, 12, {"OK"}
        )
        return
    end
end

drawUI()

-- Show tutorial on first run
if config.firstRun then
    config.firstRun = false
    saveConfig()
    showTutorial()
end

-- ─────────────────────────────────────────
-- Main event loop
-- ─────────────────────────────────────────
while true do
    local e = {os.pullEvent()}

    if e[1] == "term_resize" then
        w, h = term.getSize()
        drawUI()

    elseif e[1] == "char" then
        if handleChar(e[2]) then drawUI() end

    elseif e[1] == "key" then
        local k = e[2]
        if k == keys.backspace then
            if handleBackspace() then drawUI() end
        elseif k == keys.tab then
            handleTab(); drawUI()
        elseif k == keys.enter then
            activeField = nil; drawUI()
        end

    elseif e[1] == "mouse_click" and e[2] == 1 then
        local cx, cy = e[3], e[4]

        -- ── Menu bar (row 1) ──
        if cy == 1 then
            for _, btn in ipairs(menuBtns) do
                if cx >= btn.x and cx < btn.x + btn.w then
                    handleMenu(btn)
                    drawUI()
                    break
                end
            end

        -- ── Left panel ──
        elseif cx < DIVX then
            -- Seller input (row 10)
            if cy == 10 and cx >= 6 then activeField = "seller"; drawUI()
            -- Buyer input (row 11)
            elseif cy == 11 and cx >= 6 then activeField = "buyer"; drawUI()
            -- Price Edit button (row 13)
            elseif cy == 13 and cx >= DIVX - 8 then
                showPriceEditModal()
            -- PRINT / CLEAR buttons (row h - 2)
            elseif cy == h - 2 then
                local btnW = math.floor((DIVX - 3) / 2)
                if cx >= 2 and cx < 2 + btnW then
                    activeField = nil
                    printReceipt()
                -- CLEAR button
                elseif cx >= 2 + btnW + 1 and cx < 2 + btnW + 1 + btnW then
                    clearCart()
                    autoCalcPrice()
                    statusMsg = "Cart cleared"
                    drawUI()
                end
            else
                activeField = nil; drawUI()
            end

        -- ── Right panel ──
        else
            -- Add Item button (row 3, right side)
            if cy == 3 then
                local addLabel = "+ Add Item"
                local hdrRight = w - #addLabel - 1
                if cx >= hdrRight then
                    showItemModal(nil, nil)
                    drawUI()
                end
            -- Edit mode toggle (row 4)
            elseif cy == 4 then
                editMode = not editMode
                statusMsg = editMode and "Edit Mode ON - click items to edit" or "Edit Mode OFF"
                drawUI()
            -- Paging row
            elseif cy == h - 1 then
                local maxPage = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
                if cx <= DIVX + 3 and page > 1 then page = page - 1; drawUI()
                elseif cx >= w - 2 and page < maxPage then page = page + 1; drawUI()
                end
            -- Grid click
            else
                local idx = getGridItem(cx, cy)
                if idx then
                    if editMode then
                        showItemModal(items[idx], idx)
                        drawUI()
                    else
                        local item = items[idx]
                        cart[item.name] = (cart[item.name] or 0) + 1
                        autoCalcPrice()
                        statusMsg = "Added 1x " .. item.name
                        drawUI()
                    end
                else
                    activeField = nil; drawUI()
                end
            end
        end

    elseif e[1] == "mouse_scroll" then
        if e[3] >= DIVX then
            local maxPage = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
            if e[2] == 1 and page < maxPage then page = page + 1; drawUI()
            elseif e[2] == -1 and page > 1 then page = page - 1; drawUI()
            end
        else
            -- Scroll left panel price list
            if e[2] == 1 then
                priceScroll = priceScroll + 1
                drawUI()
            elseif e[2] == -1 then
                priceScroll = priceScroll - 1
                drawUI()
            end
        end
    end
end
