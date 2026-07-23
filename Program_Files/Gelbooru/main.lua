local tArgs = {...}
if tArgs[1] ~= "load" then
    local dgpu = peripheral.find("directgpu")
    local monitor = peripheral.find("monitor")
    local bottomModem = (peripheral.getType("bottom") == "modem")
    
    if not dgpu or not monitor or not bottomModem then
        if not _G.lUtils then shell.run("LevelOS/startup/lUtils") end
        _G.lUtils.popup(
            "Gelbooru Error",
            "Hardware missing!\n\nThis app requires a directgpu\nand a monitor connected via a\nwired modem on the bottom side.",
            34, 11, {"OK"}
        )
        return
    end
end

local assets = {
  setinput = {
    content = "local s = shapescape.getSlide()\
if not s.var then s.var = {} end\
s.var.input = self.lines\
s.var.iBox = self",
    name = "setinput",
    id = 0,
  },
  [ "Go.lua" ] = {
    content = "self.color = colors.lightGray\
self.render()\
local s = shapescape.getSlide()\
local tags = s.var.input[1] or \"\"\
tags = tags:match(\"^%s*(.-)%s*$\") or tags\
s.var.gpu_jpeg = nil\
s.var.rendered_gpu = nil\
if tags:sub(1,4) == \"http\" then\
\ts.var.sizes = { { url = tags, width = 500, height = 500 } }\
\ts.var.search = tags\
\ts.var.index = 1\
\tself.color = colors.lime\
\tself.render()\
\treturn\
end\
local imgUrl, w, h\
local r2 = http.get(\"http://th-us1.terohost.com:25616/search?tags=\".. textutils.urlEncode(tags)..\"&limit=1&pid=1\")\
if r2 then\
\tlocal res = r2.readAll()\
\tr2.close()\
\timgUrl = lUtils.getField(res,\"sample_url\") or lUtils.getField(res,\"file_url\") or lUtils.getField(res,\"preview_url\")\
\tw = tonumber(lUtils.getField(res,\"sample_width\") or lUtils.getField(res,\"preview_width\")) or 500\
\th = tonumber(lUtils.getField(res,\"sample_height\") or lUtils.getField(res,\"preview_height\")) or 500\
end\
if not imgUrl then\
\tlocal gUrl = \"https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1&limit=1&pid=0&tags=\" .. textutils.urlEncode(tags)\
\tlocal r = http.get(gUrl, {[\"User-Agent\"] = \"Mozilla/5.0 (Windows NT 10.0; Win64; x64)\"})\
\tif r then\
\t\tlocal body = r.readAll()\
\t\tr.close()\
\t\tlocal data = textutils.unserializeJSON(body)\
\t\tif data then\
\t\t\tlocal posts = data.post or data.posts\
\t\t\tlocal post = posts and (posts[1] or (posts.file_url and posts))\
\t\t\tif post then\
\t\t\t\timgUrl = post.sample_url\
\t\t\t\tif not imgUrl or imgUrl == \"\" or imgUrl:match(\"%.webm\") or imgUrl:match(\"%.mp4\") then imgUrl = post.file_url end\
\t\t\t\tif not imgUrl or imgUrl == \"\" or imgUrl:match(\"%.webm\") or imgUrl:match(\"%.mp4\") then imgUrl = post.preview_url end\
\t\t\t\tw, h = tonumber(post.sample_width or post.width) or 500, tonumber(post.sample_height or post.height) or 500\
\t\t\tend\
\t\tend\
\tend\
end\
if not imgUrl then\
\tlUtils.popup(\"Error\",\"No results!\",27,9,{\"OK\"})\
\treturn\
end\
s.var.sizes = { { url = imgUrl, width = w, height = h } }\
s.var.search = tags\
s.var.index = 1\
self.color = colors.lime\
self.render()",
    name = "Go.lua",
    id = 1,
  },
  [ "render.lua" ] = {
    content = "local function myFunction()\
os.sleep(1)\
local s = shapescape.getSlide()\
local win\
local drag\
local sizes\
local size\
local lastdrag = os.epoch(\"utc\")\
local cache = {}\
local tID\
\
local gpu = peripheral.find(\"directgpu\")\
local gpuDisplay\
if gpu then\
\tpcall(function() gpuDisplay = gpu.autoDetectAndCreateDisplay() end)\
end\
\
local function setPalette(palette)\
\9for i=0,15 do\
\9\9if palette[i] then\
\9\9\9term.setPaletteColor(2^i, unpack(palette[i]))\
\9\9end\
\9end\
end\
\
local function getHex(color)\
\9local r,g,b = term.getPaletteColor(color)\
\9return string.format(\"#%02X%02X%02X\", r*255, g*255, b*255)\
end\
\
while true do\
    local e = {os.pullEvent()}\
    local width,height = term.getSize()\
    if win then\
        if e[1] == \"mouse_click\" and e[3] >= self.x1 and e[4] >= self.y1 and e[3] <= self.x2 and e[4] <= self.y2 then\
            local x1,y1 = win.getPosition()\
            drag = {x=e[3],y=e[4],ox=x1,oy=y1}\
        elseif ((e[1] == \"mouse_drag\") or e[1] == \"mouse_up\" or (e[1] == \"timer\" and e[2] == tID)) and drag then\
        \9if e[1]:find(\"mouse\") then\
            \9drag.posX,drag.posY = drag.ox+(e[3]-drag.x),drag.oy+(e[4]-drag.y)\
            end\
            if e[1] == \"mouse_up\" or e[1] == \"timer\" then\
            \9win.reposition(drag.posX,drag.posY)\
            \9term.clear()\
            \9win.redraw()\
            end\
            if e[1] == \"mouse_up\" then\
            \9if tID then\
            \9\9os.cancelTimer(tID)\
            \9end\
            \9drag = nil\
            \9tID = nil\
            elseif e[1] == \"mouse_drag\" then\
            \9if not tID then\
            \9\9tID = os.startTimer(0.1)\
            \9end\
            elseif e[1] == \"timer\" then\
            \9tID = os.startTimer(0.1)\
            end\
        end\
        --[[term.setCursorPos(1,1)\
        term.setBackgroundColor(colors.black)\
        term.setTextColor(colors.white)\
        if drag then\
            for k,v in pairs(drag) do\
                term.write(k..\"=\"..v..\",\")\
            end\
            term.write(\"  \")\
        else\
            term.write(\"Not dragging  \")\
        end\
        write(\"\\nWindow pos: \"..table.concat({win.getPosition()},\",\")..\", size: \"..table.concat({win.getSize()},\",\"))]]\
    else\
        --[[term.setCursorPos(1,math.ceil(height/2))\
        lUtils.centerText(\"No image loaded\")\
        os.sleep(1)\
        term.clear()\
        os.sleep(1)]]\
    end\
    if e[1] == \"key\" and (e[2] == keys.right or (e[2] == keys.left and s.var.index > 1)) and s.var.search and (s.var.search:sub(1,4) ~= \"http\") then\
    \tif e[2] == keys.right then\
    \t\ts.var.index = s.var.index + 1\
    \telse\
    \t\ts.var.index = s.var.index - 1\
    \tend\
    \tlocal imgUrl, w, h\
    \tlocal gUrl = \"https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1&limit=1&pid=\" .. tostring(s.var.index - 1) .. \"&tags=\" .. textutils.urlEncode(s.var.search)\
    \tlocal r = http.get(gUrl, {[\"User-Agent\"] = \"Mozilla/5.0 (Windows NT 10.0; Win64; x64)\"})\
    \tif r then\
    \t\tlocal body = r.readAll()\
    \t\tr.close()\
    \t\tlocal data = textutils.unserializeJSON(body)\
    \t\tif data then\
    \t\t\tlocal posts = data.post or data.posts\
    \t\t\tlocal post = posts and (posts[1] or (posts.file_url and posts))\
    \t\t\tif post then\
    \t\t\t\timgUrl = post.sample_url\
    \t\t\t\tif not imgUrl or imgUrl == \"\" or imgUrl:match(\"%.webm\") or imgUrl:match(\"%.mp4\") then imgUrl = post.file_url end\
    \t\t\t\tif not imgUrl or imgUrl == \"\" or imgUrl:match(\"%.webm\") or imgUrl:match(\"%.mp4\") then imgUrl = post.preview_url end\
    \t\t\t\tw, h = tonumber(post.sample_width or post.width) or 500, tonumber(post.sample_height or post.height) or 500\
    \t\t\tend\
    \t\tend\
    \tend\
    \tif not imgUrl then\
    \t\tlocal tUrl = \"http://th-us1.terohost.com:25616/search?tags=\".. textutils.urlEncode(s.var.search)..\"&limit=1&pid=\"..s.var.index\
    \t\tlocal r2 = http.get(tUrl)\
    \t\tif r2 then\
    \t\t\tlocal res = r2.readAll()\
    \t\t\tr2.close()\
    \t\t\timgUrl = lUtils.getField(res,\"sample_url\") or lUtils.getField(res,\"file_url\") or lUtils.getField(res,\"preview_url\")\
    \t\t\tw = tonumber(lUtils.getField(res,\"sample_width\") or lUtils.getField(res,\"preview_width\")) or 500\
    \t\t\th = tonumber(lUtils.getField(res,\"sample_height\") or lUtils.getField(res,\"preview_height\")) or 500\
    \t\tend\
    \tend\
    \tif imgUrl then\
    \t\ts.var.gpu_jpeg = nil\
    \t\ts.var.rendered_gpu = nil\
    \t\ts.var.sizes = { { url = imgUrl, width = w, height = h } }\
    \tend\
    end\
    if not gpu then\
    \9local oterm = term.current()\
    \9term.redirect(s.win)\
    \9term.setBackgroundColor(colors.white)\
    \9term.setTextColor(colors.black)\
    \9term.clear()\
    \9local msg = {\
    \9\9\"DirectGPU not found\",\
    \9\9\"\",\
    \9\9\"Place a DirectGPU block next to\",\
    \9\9\"a monitor and connect it via\",\
    \9\9\"wired modem to this computer.\",\
    \9\9\"\",\
    \9\9\"Recipe: Iron-Gold-Iron, Redstone-\",\
    \9\9\"Computer-Redstone, Iron-Redstone-\",\
    \9\9\"Iron\",\
    \9\9\"\",\
    \9\9\"Restart the app once connected.\",\
    \9}\
    \9for i=1,#msg do\
    \9\9term.setCursorPos(2,2+i)\
    \9\9term.write(msg[i])\
    \9end\
    \9term.redirect(oterm)\
\9end\
    if s.var.sizes and gpu then\
    \tlocal imgObj = s.var.sizes[1]\
    \tlocal url = imgObj and imgObj.url\
    \tif url then\
    \t\ts.var.current_url = url\
    \t\ts.var.sizes = nil\
    \t\ts.var.gpu_jpeg = nil\
    \t\ts.var.rendered_gpu = nil\
    \t\tLevelOS.setTitle(\"Gelbooru\")\
    \t\tlocal oterm = term.current()\
    \t\tterm.redirect(s.win)\
    \t\tterm.setBackgroundColor(colors.white)\
    \t\tterm.setTextColor(colors.black)\
    \t\tterm.clear()\
    \t\tlUtils.centerText(\"Loading image...\")\
    \t\tlocal shortUrl = #url > 32 and (url:sub(1, 29) .. \"...\") or url\
    \t\tterm.setCursorPos(1, 3)\
    \t\tlUtils.centerText(shortUrl)\
    \t\tterm.redirect(oterm)\
    \t\tlocal response = http.get(url, {[\"User-Agent\"] = \"Mozilla/5.0 (Windows NT 10.0; Win64; x64)\"}, true)\
    \t\tif response then\
    \t\t\tif response.getResponseCode() == 200 then\
    \t\t\t\tlocal data = response.readAll()\
    \t\t\t\tif data and #data > 100 then\
    \t\t\t\t\ts.var.gpu_jpeg = data\
    \t\t\t\tend\
    \t\t\tend\
    \t\t\tresponse.close()\
    \t\tend\
    \t\tif not s.var.gpu_jpeg then\
    \t\t\tlocal r2 = http.post(\
\t\t\t\t\"http://th-us1.terohost.com:25616/convert\",\
\t\t\t\ttextutils.serializeJSON({ url = url, format = \"directgpu\" }),\
\t\t\t\t{ [\"Content-Type\"] = \"application/json\" },\
\t\t\t\ttrue\
\t\t\t)\
    \t\t\tif r2 then\
    \t\t\t\tif r2.getResponseCode() == 200 then\
    \t\t\t\t\tlocal data2 = r2.readAll()\
    \t\t\t\t\tif data2 and #data2 > 100 then\
    \t\t\t\t\t\ts.var.gpu_jpeg = data2\
    \t\t\t\t\tend\
    \t\t\t\tend\
    \t\t\t\tr2.close()\
    \t\t\tend\
    \t\t--------- debug log output for directgpu status ------------\
    \t\tend\
    \t\tif not s.var.gpu_jpeg then\
    \t\t\tlocal oterm2 = term.current()\
    \t\t\tterm.redirect(s.win)\
    \t\t\tterm.setBackgroundColor(colors.black)\
    \t\t\tterm.setTextColor(colors.white)\
    \t\t\tterm.clear()\
    \t\t\tterm.setCursorPos(1,1)\
    \t\t\tterm.write(\"Failed to load image.\")\
    \t\t\tterm.redirect(oterm2)\
    \t\t\tif not _G.lUtils then shell.run(\"LevelOS/startup/lUtils\") end\
    \t\t\t_G.lUtils.popup(\"Gelbooru Error\", \"Failed to fetch image URL.\", 32, 9, {\"OK\"})\
    \t\tend\
    \t\ts.var.rendered_gpu = nil\
    \tend\
\tend\
\tif s.var.gpu_jpeg and not s.var.rendered_gpu then\
\t\ts.var.rendered_gpu = true\
\t\tlocal oterm = term.current()\
\t\tterm.redirect(oterm)\
\t\tterm.setCursorPos(1,1)\
\t\tterm.setBackgroundColor(colors.white)\
\t\tterm.setTextColor(colors.black)\
\t\tterm.clearLine()\
\t\tlocal dispUrl = s.var.current_url or \"\"\
\t\tif #dispUrl > 25 then dispUrl = dispUrl:sub(1, 22) .. \"...\" end\
\t\tterm.write(\"DirectGPU: \" .. (dispUrl ~= \"\" and dispUrl or \"Image loaded\"))\
\t\tif not gpuDisplay or gpuDisplay == -1 then\
\t\t\tpcall(function() gpuDisplay = gpu.autoDetectAndCreateDisplayWithResolution(2) end)\
\t\t\tif not gpuDisplay or gpuDisplay == -1 then\
\t\t\t\tpcall(function() gpuDisplay = gpu.autoDetectAndCreateDisplay() end)\
\t\t\tend\
\t\tend\
\t\tif gpuDisplay and gpuDisplay ~= -1 then\
\t\t\tlocal info = gpu.getDisplayInfo(gpuDisplay)\
\t\t\tlocal w = (info and info.pixelWidth and info.pixelWidth > 0) and info.pixelWidth or 300\
\t\t\tlocal h = (info and info.pixelHeight and info.pixelHeight > 0) and info.pixelHeight or 300\
\t\t\tgpu.clear(gpuDisplay, 0, 0, 0)\
\t\t\tlocal ok, err = pcall(gpu.loadJPEGRegion, gpuDisplay, s.var.gpu_jpeg, 0, 0, w, h)\
\t\t\tif ok then\
\t\t\t\tgpu.updateDisplay(gpuDisplay)\
\t\t\telse\
\t\t\t\tif not _G.lUtils then shell.run(\"LevelOS/startup/lUtils\") end\
\t\t\t\t_G.lUtils.popup(\"Gelbooru Error\", \"Failed to load image: \" .. tostring(err), 32, 10, {\"OK\"})\
\t\t\tend\
\t\telse\
\t\t\tif not _G.lUtils then shell.run(\"LevelOS/startup/lUtils\") end\
\t\t\t_G.lUtils.popup(\"Gelbooru Error\", \"DirectGPU display not detected!\", 32, 9, {\"OK\"})\
\t\tend\
\t\tterm.redirect(oterm)\
\tend\
    if not s.var.iBox.state then\
        \
    end\
end\
end\
\
local oterm = term.current()\
local ok,err = pcall(myFunction)\
if not ok then\
\9_G.ohnoanerror = err\
\9term.redirect(oterm)\
\9lUtils.popup(\"Error\", err, 31, 11, {\"OK\"})\
end",
    name = "render.lua",
    id = 2,
  },
}

local nAssets = {}
for key,value in pairs(assets) do nAssets[key] = value nAssets[assets[key].id] = assets[key] end
assets = nAssets
nAssets = nil

local slides = {
  {
    h = 19,
    w = 51,
    c = 1,
    objs = {
      {
        snap = {
          Top = "Snap bottom",
          Right = "Snap right",
          Left = "Snap left",
          Bottom = "Snap bottom",
        },
        ox2 = 0,
        x1 = 1,
        oy1 = 2,
        x2 = 51,
        y2 = 19,
        event = {
          update = {
            [ 2 ] = -1,
          },
          mouse_click = {
            [ 2 ] = -1,
          },
          mouse_up = {
            [ 2 ] = -1,
          },
          selected = {
            [ 2 ] = -1,
          },
          Initialize = {
            [ 2 ] = -1,
          },
          Coroutine = {
            [ 2 ] = -1,
          },
        },
        border = {
          color = 0,
          type = 1,
        },
        y1 = 17,
        color = 128,
        type = "rect",
        oy2 = 0,
      },
      {
        snap = {
          Top = "Snap bottom",
          Right = "Snap left",
          Left = "Snap left",
          Bottom = "Snap bottom",
        },
        txtcolor = 1,
        event = {
          update = {
            [ 2 ] = -1,
          },
          mouse_click = {
            [ 2 ] = -1,
          },
          mouse_up = {
            [ 2 ] = -1,
          },
          selected = {
            [ 2 ] = -1,
          },
          Initialize = {
            [ 2 ] = -1,
          },
          Coroutine = {
            [ 2 ] = -1,
          },
        },
        color = 128,
        txt = "Search:",
        x1 = 2,
        oy1 = 1,
        x2 = 8,
        y2 = 18,
        y1 = 18,
        border = {
          color = 0,
          type = 1,
        },
        type = "text",
        oy2 = 1,
        input = false,
      },
      {
        ox1 = 9,
        snap = {
          Top = "Snap bottom",
          Right = "Snap right",
          Left = "Snap right",
          Bottom = "Snap bottom",
        },
        ox2 = 2,
        border = {
          color = 128,
          type = 1,
        },
        oy1 = 2,
        x2 = 49,
        y2 = 19,
        event = {
          update = {
            [ 2 ] = -1,
          },
          mouse_click = {
            [ 2 ] = -1,
          },
          mouse_up = {
            [ 2 ] = 1,
          },
          selected = {
            [ 2 ] = -1,
          },
          Initialize = {
            [ 2 ] = -1,
          },
          Coroutine = {
            [ 2 ] = -1,
          },
        },
        x1 = 42,
        type = "rect",
        color = 32,
        oy2 = 0,
        y1 = 17,
      },
      {
        snap = {
          Top = "Snap bottom",
          Right = "Snap right",
          Left = "Snap right",
          Bottom = "Snap bottom",
        },
        txtcolor = 1,
        event = {
          update = {
            [ 2 ] = -1,
          },
          mouse_click = {
            [ 2 ] = -1,
          },
          mouse_up = {
            [ 2 ] = -1,
          },
          selected = {
            [ 2 ] = -1,
          },
          Initialize = {
            [ 2 ] = -1,
          },
          Coroutine = {
            [ 2 ] = -1,
          },
        },
        color = 32,
        ox1 = 6,
        border = {
          color = 0,
          type = 1,
        },
        ox2 = 5,
        x1 = 45,
        oy1 = 1,
        x2 = 46,
        oy2 = 1,
        y1 = 18,
        txt = "Go",
        type = "text",
        y2 = 18,
        input = false,
      },
      {
        snap = {
          Top = "Snap top",
          Right = "Snap right",
          Left = "Snap left",
          Bottom = "Snap bottom",
        },
        ox2 = 0,
        x1 = 1,
        y1 = 1,
        x2 = 51,
        y2 = 16,
        event = {
          update = {
            [ 2 ] = -1,
          },
          mouse_click = {
            [ 2 ] = -1,
          },
          mouse_up = {
            [ 2 ] = -1,
          },
          selected = {
            [ 2 ] = -1,
          },
          Initialize = {
            [ 2 ] = -1,
          },
          Coroutine = {
            [ 2 ] = 2,
          },
        },
        color = 32768,
        type = "window",
        oy2 = 3,
        border = {
          color = 0,
          type = 1,
        },
      },
      {
        rhistory = {},
        snap = {
          Top = "Snap bottom",
          Right = "Snap right",
          Left = "Snap left",
          Bottom = "Snap bottom",
        },
        border = {
          color = 128,
          type = 1,
        },
        history = {},
        event = {
          update = {
            [ 2 ] = -1,
          },
          mouse_click = {
            [ 2 ] = -1,
          },
          mouse_up = {
            [ 2 ] = -1,
          },
          selected = {
            [ 2 ] = -1,
          },
          Initialize = {
            [ 2 ] = -1,
          },
          Coroutine = {
            [ 2 ] = 0,
          },
        },
        txtcolor = 32768,
        scrollX = 0,
        scr = 0,
        color = 1,
        dLines = {
          "",
        },
        cursor = {
          y = 1,
          x = 1,
          a = 1,
        },
        input = false,
        txt = "",
        blit = {},
        opt = {
          minHeight = 3,
          overflow = "scroll",
          overflowX = "scroll",
          overflowY = "none",
          cursorColor = 32768,
          indentChar = " ",
          tabSize = 4,
          minWidth = 31,
        },
        changed = false,
        x1 = 10,
        oy1 = 2,
        x2 = 40,
        y2 = 19,
        y1 = 17,
        oy2 = 0,
        ox2 = 11,
        state = false,
        type = "input",
        ref = {
          1,
          1,
        },
        lines = {
          "",
        },
      },
    },
    x = 65,
    y = 21,
  },
  {
    h = 19,
    w = 51,
    c = 2,
    objs = {},
    x = 38,
    y = 13,
  },
}

for s=1,#slides do
	local slide = slides[s]
	for o=1,#slide.objs do
		local obj = slide.objs[o]
		for key,value in pairs(obj.event) do
			if assets[ value[2] ] then
				lUtils.shapescape.addScript(obj,value[2],key,assets,LevelOS,slides)
			else
				obj.event[key] = {function() end,-1}
			end
		end
	end
end

	local tArgs = {...}
if tArgs[1] and tArgs[1] == "load" then
	return {assets=assets,slides=slides}
end


return lUtils.shapescape.run(slides,...)