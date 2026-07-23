-- Program_Files/Gelbooru/main.lua
-- Gelbooru Viewer for LevelOS & DirectGPU
-- Native LevelOS application with DirectGPU RGB rendering support

if not _G.lUtils then shell.run("LevelOS/startup/lUtils") end

local tArgs = { ... }
if tArgs[1] == "load" then
    return { name = "Gelbooru Viewer", version = "2.0" }
end

-- Check required hardware peripherals
local gpu = peripheral.find("directgpu")

if not gpu then
    _G.lUtils.popup(
        "Gelbooru Error",
        "DirectGPU Peripheral Missing!\n\nThis app requires a DirectGPU block connected to this computer.",
        36, 10, { "OK" }
    )
    return
end

-- Initialize DirectGPU Display
local gpuDisplay
local function initDisplay()
    if gpu then
        local ok, id = pcall(gpu.autoDetectAndCreateDisplayWithResolution, 2)
        if ok and id and id ~= -1 then
            gpuDisplay = id
        else
            local ok2, id2 = pcall(gpu.autoDetectAndCreateDisplay)
            if ok2 and id2 and id2 ~= -1 then
                gpuDisplay = id2
            end
        end
    end
    return gpuDisplay
end

initDisplay()

-- UI State
local w, h = term.getSize()
local bgCol = colors.gray
local headerCol = colors.blue
local btnCol = colors.lightGray
local btnActiveCol = colors.lime
local textCol = colors.white

local currentSearch = ""
local inputBuffer = ""
local inputActive = false
local currentPage = 1
local currentImageIndex = 1
local cachedPosts = {}
local statusText = "Ready. Enter tags or image URL."
local isDownloading = false

local API_KEY = "d790b8a1e13723b22232bf0be7cc6a5c12f242aedec876a8e92c9521bd7d70426c093187bb925b7f7b9fea060152e18c247efeaf7221e32c8af121a00c1e66db"
local USER_ID = "2018376"

-- Helper to safely extract fields from XML proxy response
local function extractField(str, field)
    if not str then return nil end
    if _G.lUtils and _G.lUtils.getField then
        local val = _G.lUtils.getField(str, field)
        if val and val ~= "" then return val end
    end
    local val = str:match(field .. "%s*=%s*\"([^\"]+)\"")
    if not val then val = str:match(field .. "%s*=%s*'([^']+)'") end
    if not val then val = str:match(field .. "%s*=%s*(%S+)") end
    return val
end

-- Helper to fetch search results (Direct Gelbooru API first with Proxy fallback)
local function searchGelbooru(tags, page)
    sleep(0)
    page = page or 1
    tags = tags:match("^%s*(.-)%s*$") or tags
    if tags == "" then return nil end

    -- 1. Direct Gelbooru API with API Key & User ID
    local gUrl = "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1&api_key=" .. API_KEY .. "&user_id=" .. USER_ID .. "&limit=20&pid=" .. tostring(page - 1) .. "&tags=" .. textutils.urlEncode(tags)
    local r = http.get(gUrl, { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" })
    if r then
        local body = r.readAll()
        r.close()
        local data = textutils.unserializeJSON(body)
        if data then
            local posts = data.post or data.posts
            if posts then
                local list = posts[1] and posts or { posts }
                local parsed = {}
                for _, p in ipairs(list) do
                    local imgUrl = p.sample_url
                    if not imgUrl or imgUrl == "" or imgUrl:match("%.webm") or imgUrl:match("%.mp4") then imgUrl = p.file_url end
                    if not imgUrl or imgUrl == "" or imgUrl:match("%.webm") or imgUrl:match("%.mp4") then imgUrl = p.preview_url end
                    if imgUrl and imgUrl ~= "" then
                        table.insert(parsed, {
                            url = imgUrl,
                            width = tonumber(p.sample_width or p.width) or 500,
                            height = tonumber(p.sample_height or p.height) or 500,
                        })
                    end
                end
                if #parsed > 0 then return parsed end
            end
        end
    end

    sleep(0)
    -- 2. Fallback to Terohost Proxy Search
    local tUrl = "http://th-us1.terohost.com:25616/search?tags=" .. textutils.urlEncode(tags) .. "&limit=20&pid=" .. tostring(page)
    local r2 = http.get(tUrl)
    if r2 then
        local body2 = r2.readAll()
        r2.close()
        if body2 and body2 ~= "" then
            local results = {}
            for postBlock in body2:gmatch("<post[^>]+>") do
                local sampleUrl = extractField(postBlock, "sample_url") or extractField(postBlock, "file_url") or extractField(postBlock, "preview_url")
                if sampleUrl then
                    local sw = tonumber(extractField(postBlock, "sample_width") or extractField(postBlock, "preview_width")) or 500
                    local sh = tonumber(extractField(postBlock, "sample_height") or extractField(postBlock, "preview_height")) or 500
                    table.insert(results, { url = sampleUrl, width = sw, height = sh })
                end
            end
            if #results > 0 then return results end
        end
    end

    return nil
end

-- Helper to fetch binary JPEG data (Direct GET with Server Converter fallback)
local function fetchImageBytes(url)
    if not url then return nil end
    sleep(0)
    
    -- Stage 1: Direct binary fetch
    local r = http.get(url, { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }, true)
    if r then
        if r.getResponseCode() == 200 then
            local data = r.readAll()
            r.close()
            if data and #data > 100 then
                return data
            end
        else
            r.close()
        end
    end

    sleep(0)
    -- Stage 2: Converter Proxy
    local r2 = http.post(
        "http://th-us1.terohost.com:25616/convert",
        textutils.serializeJSON({ url = url, format = "directgpu" }),
        { ["Content-Type"] = "application/json" },
        true
    )
    if r2 then
        if r2.getResponseCode() == 200 then
            local data2 = r2.readAll()
            r2.close()
            if data2 and #data2 > 100 then
                return data2
            end
        else
            r2.close()
        end
    end

    return nil
end

-- Render image data onto DirectGPU display
local function renderToDirectGPU(jpegData)
    if not jpegData then return false end
    sleep(0)
    initDisplay()
    if not gpuDisplay or gpuDisplay == -1 then return false end

    local info = gpu.getDisplayInfo(gpuDisplay)
    local dw = (info and info.pixelWidth and info.pixelWidth > 0) and info.pixelWidth or 300
    local dh = (info and info.pixelHeight and info.pixelHeight > 0) and info.pixelHeight or 300

    gpu.clear(gpuDisplay, 0, 0, 0)
    local ok, err = pcall(gpu.loadJPEGRegion, gpuDisplay, jpegData, 0, 0, dw, dh)
    if ok then
        gpu.updateDisplay(gpuDisplay)
        return true
    end
    return false
end

-- UI Drawing Function
local function drawUI()
    term.setBackgroundColor(bgCol)
    term.setTextColor(textCol)
    term.clear()

    -- Title Bar
    term.setCursorPos(1, 1)
    term.setBackgroundColor(headerCol)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("Gelbooru DirectGPU Viewer")

    -- Search Bar Label
    term.setCursorPos(2, 3)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.lightGray)
    term.write("Search / URL:")

    -- Input Box
    term.setCursorPos(2, 4)
    if inputActive then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
    end
    local inputDisplay = inputBuffer
    local maxLen = w - 12
    if #inputDisplay > maxLen then
        inputDisplay = inputDisplay:sub(#inputDisplay - maxLen + 1)
    end
    term.write(" " .. inputDisplay .. string.rep(" ", maxLen - #inputDisplay) .. " ")

    -- "Go" Button
    term.setCursorPos(w - 7, 4)
    term.setBackgroundColor(btnActiveCol)
    term.setTextColor(colors.black)
    term.write(" [Go] ")

    -- Navigation Bar (Prev / Next buttons)
    term.setCursorPos(2, 6)
    term.setBackgroundColor(btnCol)
    term.setTextColor(colors.black)
    term.write(" [< Prev] ")

    term.setCursorPos(14, 6)
    term.setBackgroundColor(btnCol)
    term.setTextColor(colors.black)
    term.write(" [Next >] ")

    -- Page / Post Info
    term.setCursorPos(26, 6)
    term.setBackgroundColor(bgCol)
    term.setTextColor(colors.yellow)
    term.write(string.format("Post %d/%d", currentImageIndex, math.max(1, #cachedPosts)))

    -- Status Bar
    term.setCursorPos(2, 8)
    term.setTextColor(colors.lightGray)
    term.write("Status: ")
    term.setTextColor(isDownloading and colors.yellow or colors.lime)
    term.write(statusText)

    -- Instructions
    term.setCursorPos(2, h - 1)
    term.setTextColor(colors.lightGray)
    term.write("Press Enter/Go to search. Arrow keys: Prev/Next.")
end

-- Load and render active post
local function loadActiveImage()
    local targetUrl
    if inputBuffer:sub(1, 4) == "http" then
        targetUrl = inputBuffer
    elseif cachedPosts and cachedPosts[currentImageIndex] then
        targetUrl = cachedPosts[currentImageIndex].url
    end

    if not targetUrl then
        statusText = "No image URL available."
        drawUI()
        return
    end

    isDownloading = true
    statusText = "Downloading image..."
    drawUI()
    sleep(0)

    local shortUrl = #targetUrl > 25 and (targetUrl:sub(1, 22) .. "...") or targetUrl
    local data = fetchImageBytes(targetUrl)
    sleep(0)
    isDownloading = false

    if data then
        local ok = renderToDirectGPU(data)
        sleep(0)
        if ok then
            statusText = "Displayed: " .. shortUrl
        else
            statusText = "Failed to render on DirectGPU."
            drawUI()
            _G.lUtils.popup("Gelbooru Error", "Failed to render image on DirectGPU display.", 34, 9, { "OK" })
        end
    else
        statusText = "Failed to fetch image."
        drawUI()
        _G.lUtils.popup("Gelbooru Error", "Failed to fetch image from URL:\n" .. shortUrl, 34, 9, { "OK" })
    end
    drawUI()
end

-- Main Event Loop
drawUI()

while true do
    local e = { os.pullEvent() }
    local eventType = e[1]

    if eventType == "mouse_click" then
        local mx, my = e[3], e[4]

        -- Clicked Input Box
        if my == 4 and mx >= 2 and mx <= (w - 9) then
            inputActive = true
            drawUI()
        else
            if inputActive then
                inputActive = false
                drawUI()
            end
        end

        -- Clicked "Go" Button
        if my == 4 and mx >= (w - 8) and mx <= w then
            inputActive = false
            currentSearch = inputBuffer
            if inputBuffer:sub(1, 4) == "http" then
                cachedPosts = { { url = inputBuffer } }
                currentImageIndex = 1
                loadActiveImage()
            else
                statusText = "Searching..."
                drawUI()
                currentPage = 1
                currentImageIndex = 1
                cachedPosts = searchGelbooru(currentSearch, currentPage) or {}
                if #cachedPosts > 0 then
                    loadActiveImage()
                else
                    statusText = "No results found."
                    drawUI()
                    _G.lUtils.popup("Gelbooru", "No results found for tags:\n" .. currentSearch, 32, 9, { "OK" })
                end
            end
        end

        -- Clicked "Prev" Button
        if my == 6 and mx >= 2 and mx <= 11 then
            if currentImageIndex > 1 then
                currentImageIndex = currentImageIndex - 1
                loadActiveImage()
            elseif currentPage > 1 then
                currentPage = currentPage - 1
                cachedPosts = searchGelbooru(currentSearch, currentPage) or {}
                currentImageIndex = #cachedPosts
                if #cachedPosts > 0 then loadActiveImage() end
            end
        end

        -- Clicked "Next" Button
        if my == 6 and mx >= 14 and mx <= 23 then
            if currentImageIndex < #cachedPosts then
                currentImageIndex = currentImageIndex + 1
                loadActiveImage()
            else
                currentPage = currentPage + 1
                local newPosts = searchGelbooru(currentSearch, currentPage)
                if newPosts and #newPosts > 0 then
                    cachedPosts = newPosts
                    currentImageIndex = 1
                    loadActiveImage()
                else
                    statusText = "End of search results."
                    drawUI()
                end
            end
        end

    elseif eventType == "char" and inputActive then
        inputBuffer = inputBuffer .. e[2]
        drawUI()

    elseif eventType == "key" then
        local key = e[2]
        if inputActive then
            if key == keys.backspace then
                inputBuffer = inputBuffer:sub(1, #inputBuffer - 1)
                drawUI()
            elseif key == keys.enter then
                inputActive = false
                currentSearch = inputBuffer
                if inputBuffer:sub(1, 4) == "http" then
                    cachedPosts = { { url = inputBuffer } }
                    currentImageIndex = 1
                    loadActiveImage()
                else
                    statusText = "Searching..."
                    drawUI()
                    currentPage = 1
                    currentImageIndex = 1
                    cachedPosts = searchGelbooru(currentSearch, currentPage) or {}
                    if #cachedPosts > 0 then
                        loadActiveImage()
                    else
                        statusText = "No results found."
                        drawUI()
                        _G.lUtils.popup("Gelbooru", "No results found for tags:\n" .. currentSearch, 32, 9, { "OK" })
                    end
                end
            end
        else
            -- Navigation Keys when not typing in text box
            if key == keys.left then
                if currentImageIndex > 1 then
                    currentImageIndex = currentImageIndex - 1
                    loadActiveImage()
                end
            elseif key == keys.right then
                if currentImageIndex < #cachedPosts then
                    currentImageIndex = currentImageIndex + 1
                    loadActiveImage()
                end
            end
        end
    end
end