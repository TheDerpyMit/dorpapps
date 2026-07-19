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
s.var = {}\
os.sleep(0.5)\
s.var.input = self.lines\
s.var.iBox = self",
    name = "setinput",
    id = 0,
  },
  [ "Go.lua" ] = {
    content = "self.color = colors.lightGray\
--lUtils.shapescape.renderSlide(shapescape.getSlide())\
self.render()\
local s = shapescape.getSlide()\
local tags = s.var.input[1]\
local r = http.get(\"http://th-us1.terohost.com:25616/search?tags=\".. textutils.urlEncode(tags)..\"&limit=1&pid=1\")\
if not r then\
    error(\"No connection\")\
end\
local res = r.readAll()\
_G.debugres = res\
--local url = res:match(\"preview_url\\=\\\"(%S-)\\\"\")\
local url = lUtils.getField(res,\"preview_url\")\
if not url then\
    lUtils.popup(\"Error\",\"No results!\",27,9,{\"OK\"})\
    return\
end\
-- get sample_width and sample_height then resize\
--local w,h = res:match(\"preview_width\\=\\\"(%S-)\\\"\"),res:match(\"preview_height\\=\\\"(%S-)\\\"\")\
local w,h = lUtils.getField(res,\"preview_width\"),lUtils.getField(res,\"preview_height\")\
w,h = tonumber(w),tonumber(h)\
--[[local i = http.get(url).readAll()\
local image,err = http.post(\"http://img-resize.com/resize\",\"height=\"..tostring(({term.getSize()})[2]/3)..\"&op=fixedWidth&input=\".. textutils.urlEncode(i)..\";type=image/\".. lUtils.getFileType(url):sub(2,4)..\"\")\
if not image then\
    lUtils.popup(\"Error\",err,27,11,{\"OK\"})\
    return\
end\
http.post(\"https://www.level.eu5.net/pImage.php\",\"content=\".. textutils.urlEncode(image.readAll()),{Cookie=lOS.userID})\
local img = http.get(\"http://tojuroku.switchcraft.pw/?url=\".. textutils.urlEncode(\"https://www.level.eu5.net/image\")).readAll()]]\
s.var.sizes = {}\
local url2 = lUtils.getField(res,\"sample_url\")\
local url3 = lUtils.getField(res,\"file_url\")\
table.insert(s.var.sizes,{url=url,width=w,height=h})\
if url2 then\
\9local w2,h2 = lUtils.getField(res,\"sample_width\"),lUtils.getField(res,\"sample_height\")\
\9w2,h2 = tonumber(w2),tonumber(h2)\
\9table.insert(s.var.sizes,{url=url2,width=w2,height=h2})\
end\
if url3 then\
\9local w3,h3 = lUtils.getField(res,\"preview_width\"),lUtils.getField(res,\"preview_height\")\
\9w3,h3 = tonumber(w3),tonumber(h3)\
\9table.insert(s.var.sizes,{url=url3,width=w3,height=h3})\
end\
s.var.search = tags\
s.var.index = 1\
self.color = colors.lime\
self.render()\
-- sample cant be json",
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
\9gpuDisplay = gpu.autoDetectAndCreateDisplay()\
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
    if e[1] == \"key\" and (e[2] == keys.right or (e[2] == keys.left and s.var.index > 1)) then\
    \9if e[2] == keys.right then\
    \9\9s.var.index = s.var.index+1\
    \9else\
    \9\9s.var.index = s.var.index-1\
    \9end\
    \9local url = \"http://th-us1.terohost.com:25616/search?tags=\".. textutils.urlEncode(s.var.search)..\"&limit=1&pid=\"..s.var.index\
    \9local res\
    \9if cache[url] then\
    \9\9res = cache[url]\
    \9else\
    \9\9local r = http.get(url)\
    \9\9if r then\
    \9\9\9res = r.readAll()\
    \9\9end\
    \9end\
    \9if res then\
    \9\9cache[url] = res\
\9\9\9s.var.gpu_jpeg = nil\
\9\9\9s.var.rendered_gpu = nil\
\9\9\9local url = lUtils.getField(res,\"preview_url\")\
\9\9\9s.var.sizes = {}\
\9\9\9local url2 = lUtils.getField(res,\"sample_url\")\
\9\9\9local url3 = lUtils.getField(res,\"file_url\")\
\9\9\9table.insert(s.var.sizes,{url=url,width=w,height=h})\
\9\9\9if url2 then\
\9\9\9\9local w2,h2 = lUtils.getField(res,\"sample_width\"),lUtils.getField(res,\"sample_height\")\
\9\9\9\9w2,h2 = tonumber(w2),tonumber(h2)\
\9\9\9\9table.insert(s.var.sizes,{url=url2,width=w2,height=h2})\
\9\9\9end\
\9\9\9if url3 then\
\9\9\9\9local w3,h3 = lUtils.getField(res,\"preview_width\"),lUtils.getField(res,\"preview_height\")\
\9\9\9\9w3,h3 = tonumber(w3),tonumber(h3)\
\9\9\9\9table.insert(s.var.sizes,{url=url3,width=w3,height=h3})\
\9\9\9end\
\9\9end\
\9end\
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
    if s.var.sizes and not s.var.gpu_jpeg and gpu then\
    \9local url = s.var.sizes[1].url\
    \9s.var.sizes = nil\
    \9_G.debugurl = url\
    \9LevelOS.setTitle(url)\
    \9local oterm = term.current()\
    \9term.redirect(s.win)\
    \9term.setBackgroundColor(colors.white)\
    \9term.setTextColor(colors.black)\
    \9term.clear()\
    \9lUtils.centerText(\"Downloading...\")\
    \9term.redirect(oterm)\
    \9local r, e = http.post(\
\9\9\9\9\"http://th-us1.terohost.com:25616/convert\",\
\9\9\9\9textutils.serializeJSON({\
\9\9\9\9\9url = url,\
\9\9\9\9\9format = \"directgpu\",\
\9\9\9\9}),\
\9\9\9\9{\
\9\9\9\9\9[\"Content-Type\"] = \"application/json\",\
\9\9\9\9},\
\9\9\9\9true\
\9\9\9)\
    \9\9if r then\
    \9\9\9local code = r.getResponseCode()\
    \9\9\9local hdrs = r.getResponseHeaders()\
    \9\9\9if code == 200 and hdrs[\"x-img-w\"] and hdrs[\"x-img-h\"] then\
    \9\9\9\9s.var.gpu_w = tonumber(hdrs[\"x-img-w\"])\
    \9\9\9\9s.var.gpu_h = tonumber(hdrs[\"x-img-h\"])\
    \9\9\9\9s.var.gpu_jpeg = r.readAll()\
    \9\9\9else\
    \9\9\9\9local errMsg = r.readAll()\
    \9\9\9\9if not _G.lUtils then shell.run(\"LevelOS/startup/lUtils\") end\
    \9\9\9\9_G.lUtils.popup(\"Gelbooru Error\", \"Image conversion failed!\\n\\nServer code: \" .. tostring(code) .. \"\\nResponse: \" .. string.sub(errMsg or \"\", 1, 60), 32, 10, {\"OK\"})\
    \9\9\9end\
    \9\9\9r.close()\
    \9\9else\
    \9\9\9if not _G.lUtils then shell.run(\"LevelOS/startup/lUtils\") end\
    \9\9\9_G.lUtils.popup(\"Gelbooru Error\", \"Failed to connect to image conversion server:\\n\" .. tostring(e), 32, 9, {\"OK\"})\
    \9\9end\
    \9s.var.rendered_gpu = nil\
\9end\
\9if s.var.gpu_jpeg and not s.var.rendered_gpu then\
\9\9s.var.rendered_gpu = true\
\9\9local oterm = term.current()\
\9\9term.redirect(oterm)\
\9\9term.setCursorPos(1,1)\
\9\9term.setBackgroundColor(colors.white)\
\9\9term.setTextColor(colors.black)\
\9\9term.clearLine()\
\9\9term.write(\"Image on DirectGPU display\")\
\9\9local info = gpu.getDisplayInfo(gpuDisplay)\
\9\9local dw,dh = info.pixelWidth, info.pixelHeight\
\9\9local iw,ih = s.var.gpu_w, s.var.gpu_h\
\9\9local scale = math.min(dw/iw, dh/ih, 1)\
\9\9local tw,th = math.floor(iw*scale), math.floor(ih*scale)\
\9\9local ox,oy = math.floor((dw-tw)/2), math.floor((dh-th)/2)\
\9\9gpu.clear(gpuDisplay, 0, 0, 0)\
\9\9gpu.loadJPEGRegion(gpuDisplay, s.var.gpu_jpeg, ox, oy, tw, th)\
\9\9gpu.updateDisplay(gpuDisplay)\
\9\9term.redirect(oterm)\
\9end\
    if not s.var.iBox.state then\
        \
    end\
    os.sleep(0.05)\
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