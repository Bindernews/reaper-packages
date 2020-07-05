local reaper, gfx, string, table = reaper, gfx, string, table

--debug_mode = true

-- Load the Scythe library
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then reaper.MB("Couldn't load the Scythe library.", "Whoops!", 0) return end
loadfile(libPath .. "scythe.lua")()

local Math = require("public.math")
local Color = require("public.color")
local String = require("public.string")

-- Load my own libraries
do
  local info = debug.getinfo(1,'S');
  local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
  package.path = package.path .. ";" .. script_path .. "../?.lua"
end

local Box = require("bn.box")
local bmath = require("bn.bmath")
local bgx = require("bn.bgx")
local bcolor = require("bn.color")
local lerp,unlerp,hslToRgb,rgbToHsl = 
  bmath.lerp, bmath.unlerp, bcolor.hslToRgb, bcolor.rgbToHsl


-----------------
-- Pre-Defines --
-----------------

local PI2 = math.pi * 2
local EXT_STATE_PATH = "bn-color-picker"

-- Tables
local state, ui = {}, {}

-- Debug print: _=dm and Msg("debug message here")
-- We pre-define local _ to make this easier.
local dm,_ = debug_mode or false
local function Msg(str) reaper.ShowConsoleMsg(tostring(str) .. "\n") end

--------------------
-- Helper Classes --
--------------------

-- Button class
local Button = {
  draw = function(self, mouse)
    -- Can use custom drawing and/or regular drawing
    local b = self.b
    if self._draw then
      self:_draw(mouse)
    end
    if self.img then
      local src = self.src
      gfx.blit(self.img, 1, 0, src.x, src.y, src.w, src.h, b.x, b.y, b.w, b.h, 0, 0)
    end
    if self.gradient then
      bgx.gradRect(b, table.unpack(self.gradient))
    end
    if self.text then
      Color.set(self.color)
      bgx.str(b, self.text, self.flags)
    end
    if self.border then
      Color.set(self.border)
      bgx.rect(b, false)
    end
    
    -- Draw highlight if mouse over
    if b:contains(mouse.x, mouse.y) then
      if self.status then
        state.status = self.status
      end
      Color.set(self.hlColor)
      bgx.rect(b:clone():pad(self.hlPad), false)
    end
  end,
}
setmetatable(Button, {
  __call = function(self, b, opts)
    local o = {
      b = b,
      img = opts.img,
      src = opts.src,
      text = opts.text,
      flags = opts.flags,
      exec = opts.exec,
      color = opts.color,
      status = opts.status,
      _draw = opts.draw,
      gradient = opts.gradient,
      border = opts.border,
      hlColor = opts.hlColor or "btnHighlight",
      hlPad = opts.hlPad or ui.btnPad,
    }
    for k,v in pairs(opts.data or {}) do
      o[k] = v
    end
    return setmetatable(o, { __index = self })
  end,
})

-------------------------
-- Define state and ui --
-------------------------

state = {
  mode = "circle", -- Values: "circle", "box",
  snap = true,
  mouse = {x = 0, y = 0, lb = false, rb = false, clickL = false, clickR = false, 
    vwheel = 0, hwheel = 0 },
  hue = 0,  -- hue
  sat = 0,  -- saturation
  lum = 0.5, -- lightness / luminosity
  ok = false, -- did we exit successfully?
  done = false, -- are we done?
  -- List of `ui.recentColorsCount` most recent colors (RGB)
  recentColors = {},
  -- List of favorite colors
  favoriteColors = {},
  -- Current status message
  status = "",
  
  -- Convenience function for setting HSL values
  setHSL = function(self, h, s, l)
    self.hue, self.sat, self.lum = h, s, l
  end
}

-- Here we add custom colors
Color.addColorsFromRgba{
  bgColor = {60, 69, 75},
  btnHighlight = {51, 152, 135},
  lineColor1 = {64, 72, 78},
  numBg = {152, 22, 22}, --{234, 53, 49},
}

local function saveColorList(colors, count, defaultColor)
  local cls = {}
  for i = 1,count do
    cls[#cls + 1] = Color.toHex(table.unpack(colors[i]))
  end
  while #cls < count do
    cls[#cls + 1] = defaultColor
  end
  return table.concat(cls, ",")
end

local function loadColorList(s, count, defaultColor)
  local colors = {}
  if s ~= "" then
    -- Recent colors is a comma-separated list of RRGGBB values
    colors = String.split(s, ",")
  end
  local out = {}
  for i = 1,#colors do
    out[#out+1] = Color.fromHex(colors[i])
  end
  while #out < count do
    out[#out+1] = {table.unpack(defaultColor)}
  end
  return out
end

local function buildUI(scale)
  scale = bmath.clamp(0.5, 3, scale)
  local pad = 10 * scale
  local ui = {
    pad = pad,
    btnPad = 4,
    hueLines = 16,
    satLines = 6,
    w = bmath.round(382 * scale),
    h = bmath.round(610 * scale),
    scale = scale,
    -- How many recent colors do we show
    recentColorsCount = 8,
    -- How many favorite colors to show
    favoriteColorsCount = 16,
    -- Default corner radius
    cornerRad = pad / 2,
    -- Size of the selection circle
    selCircleSize = 6 * scale,
    selCircleThick = 2,
    -- Extra L/R padding for clicking on the luminosity slider
    lumSliderClickPad = (pad * 2),
    -- Pre-calculated size of the circle and graph. Increasing this will
    -- increase the quality of the images, at the cost of startup time.
    prepSize = 600,
    -- List of buttons
    buttons = {},
  }
  
  -- This is basically the layout of the GUI. Each object has a box delcaring its
  -- location. We calculate those boxes here.
  local b0 = Box(pad * 1.5, pad, 0, 0):setRB(ui.w - (pad * 1.5), ui.h - pad)
  local b1, b2, rows, cols
  -- Color picker box
  ui.cbox = Box(b0.x, (pad * 2.5) + 20, 300 * scale):round()
  -- Luminance picker box
  ui.lbox = Box(ui.cbox:R() + (pad * 3), ui.cbox:T(), 20 * scale, ui.cbox.h):round()
  
  -- Recent colors and favorite colors
  b1 = Box(b0.x, ui.cbox:B() + (pad * 1.5), 0, 50 * scale):setRB(ui.lbox:R(), nil) 
  ui.recColorArea = b1:clone():cellY(0, 1, 2)
  ui.favColorArea = b1:clone():cellY(1, 2, 2)
  
  cols = ui.recentColorsCount
  ui.recColors = {}
  for i = 1,cols do
    ui.recColors[i] = ui.recColorArea:clone()
      :cellX((i - 1), 1, cols):pad(-pad / 2):round()
  end
  
  -- N.B. Update these if you change ui.favoriteColorsCount
  rows = 2
  cols = 8
  ui.favColors = {}
  for j = 0,(rows-1) do
    b2 = ui.favColorArea:clone():cellY(j, 1, rows)
    for i = 1,cols do
      ui.favColors[(j * cols) + i] = b2:clone():cellX((i - 1), 1, cols):pad(-pad / 2):round()
    end
  end
  
  -- Current color
  b1 = Box(b0.x, ui.favColorArea:B() + (pad * 1.3), 100 * scale, 100 * scale):round()
  ui.currentBox = b1
  ui.currentBoxText = b1:clone():pad(-2 * pad, -3 * pad):round()
  -- HSL numbers
  b1 = Box(114 * scale, ui.currentBox.y, 150 * scale, 100 * scale)
  ui.hslBox = b1:clone():round()
  ui.hslBoxText = ui.hslBox:clone():frac(0.6, 1):round()
  ui.hslBoxVals = ui.hslBox:clone():frac(-0.4, 1):alter(pad, 0, -pad * 2, 0):round()
  -- RGB numbers
  ui.rgbBox = b1:alter(b1.w, 0):setSize(110 * scale, b1.h):round()
  ui.rgbBoxText = b1:clone():resize(50 * scale, b1.h):round()
  ui.rgbBoxVals = b1:clone():resize(-60 * scale, b1.h):alter(pad, 0, -pad * 2, 0):round()
  -- Top-left buttons
  b1 = Box(b0.x, pad, 16 * scale, 16 * scale)
  ui.btnCircleBox = b1:clone():round()
  b1:alter(b1.w + pad, 0)
  ui.btnSquareBox = b1:clone():round()
  b1:alter(b1.w + pad, 0, 20 * scale, 0)
  ui.btnSnapBox = b1:clone():round()
  -- Status box
  b1 = ui.btnCircleBox:clone():setRB(b0:R(), nil)
  ui.statusBox = b1:resize(-b0.w / 2, b1.h)
  -- Accept and Reset buttons
  b1 = Box(b0.x + (pad * 0.2), ui.currentBox:B() + (pad * 1.5), 60 * scale, 30 * scale)
  ui.okBtnBox = b1:clone():round()
  ui.resetBtnBox = b1:clone():setPos(ui.rgbBox:R() - (pad * 1.2) - b1.w, b1.y):round()
  -- Rescale button
  ui.rescaleBtnBox = b1:clone():set(b0:CX() - (b1.w / 2), b1.y, b1.w, b1.h)
  
  return ui
end

-----------------------
-- Drawing Functions --
-----------------------

local function drawSnapCircle(cx, cy, r)
  local gfx,math = gfx,math
  local ringF = 1 / ui.satLines
  
  Color.set("lineColor1")
  
  local r0 = (r * ringF) + 0.5
  local r1 = r - 0.5
  -- Hue lines
  for i = 1,ui.hueLines do
    local ang = ((i + 0.5) / 16) * PI2
    local c,s = math.cos(ang), math.sin(ang)
    gfx.line(cx + (c * r0), cy + (s * r0), cx + (c * r1), cy + (s * r1))
  end
  
  -- Sat rings
  for i = 1,ui.satLines do
    local cr = i * ringF * r
    gfx.circle(cx, cy, cr - 0.5, false, true)
    gfx.circle(cx, cy, cr, false, true)
  end
end

local function drawSnapGrid(b)
  -- Use the line color
  Color.set("lineColor1")
  -- Draw hue lines
  for i = 0,ui.hueLines do
    local x = b.x + ((i / ui.hueLines) * b.w)
    gfx.line(x, b:T(), x, b:B())
  end
  -- Draw sat lines
  for i = 0,ui.satLines do
    local y = lerp(b:T(), b:B(), i / ui.satLines)
    gfx.line(b:L(), y, b:R(), y)
  end
end

local function snapHueSat(h, s)
  local hStep,sStep = ui.hueLines, ui.satLines
  -- Because we offset hue in the UI, snapping it is easy
  h = bmath.round(h * hStep) / hStep
  if h == 1 then h = 0 end
  -- To snap saturation, we have to perform the offset ourselves
  -- We do this by basically doing floor(sat - half_step), rounding correctly, then
  -- adding back the half_step we took away earlier. This gives us vales between
  -- the grid lines instead of on them.
  local sOff = 1 / (sStep * 2)
  s = s - sOff
  s = bmath.clamp(0, 1 - (sOff * 2), s)
  s = bmath.round(s * (sStep)) / (sStep)
  s = s + sOff
  return h,s
end

local function offsetHue(h, negate)
  negate = negate or false
  local off = 1 / (ui.hueLines * 2)
  if negate then
    h = h + off
    if h > 1 then h = h - 1 end
  else
    h = h - off
    if h < 0 then h = h + 1 end
  end
  return h
end

--- Draw a box with a number and open an input prompt if the user right-clicks
local function colorNumBox(box, title, value, vmax, mouse)
  box:pad(0, -ui.pad / 2):floor()
  Color.set("numBg")
  bgx.roundRect(box, 5 * ui.scale, true, true)
  Color.set("black")
  bgx.roundRect(box, 5 * ui.scale, true, false)
  box:pad(-ui.pad / 2, 0):floor()
  Color.set("white")
  local ival = bmath.round(value * vmax)
  bgx.str(box, tostring(ival), 2+4)
  
  -- Handle mouse actions on this box
  if box:contains(mouse.x, mouse.y) then
    state.status = "Scroll or right-click"
    -- Right-click => open value entry dialog
    if mouse.clickR then
      local msg = ("%s (0 - %d)"):format(title, math.floor(vmax))
      local ok,ret = reaper.GetUserInputs(title, 1, msg, "")
      if ok then
        local nret = tonumber(ret)
        if nret == nil then
          reaper.MB("That isn't a number", "Error", 0)
          return
        end
        return bmath.clamp(0, 1, tonumber(ret) / vmax)
      end
    end
    -- Scroll => increment / decrement value
    if mouse.wheelV ~= 0 then
      ival = ival + bmath.sign(mouse.wheelV)
      return bmath.clamp(0, 1, ival / vmax)
    end
  end
  return nil
end

function Msg3f(a, b, c)
  --Msg(("%f, %f, %f"):format(a, b, c))
end

--- Call the state.after function. This ends the color picker.
local function callAfter()
  local s = state
  -- Done signals that we've called after and should exit the UI
  if not s.done then
    -- Convert color to RGB
    local r,g,b = hslToRgb(s.hue, s.sat, s.lum)
    
    -- Store our recent and favorite colors
    if s.ok then
      table.insert(s.recentColors, 1, {r,g,b})
      reaper.SetExtState(EXT_STATE_PATH, "recentColors",
        saveColorList(s.recentColors, ui.recentColorsCount, {1,1,1}), true)
      reaper.SetExtState(EXT_STATE_PATH, "favoriteColors",
        saveColorList(s.favoriteColors, ui.favoriteColorsCount, {1,1,1}), true)
    end
    
    -- Convert to RGB-255 for after()
    local function toI(v) return math.floor((v*255)+0.5) end
    -- Finally, call after()
    s.after(s.ok, {toI(r), toI(g), toI(b)})
  end
  s.done = true
end

-----------------------
-- Main UI loop code --
-----------------------

local function uiLoop()
  local s, gfx = state, gfx
  local b1,b2 -- generic "Box" variables
  
  -- First, parse the mouse state so we can draw things properly
  local mouse = bgx.updateMouse(s.mouse)
  
  -- Process our threads
  for i = #s.threads,1,-1 do
    local co = s.threads[i]
    coroutine.resume(co)
    if coroutine.status(co) == "dead" then
      table.remove(s.threads, i)
    end
  end
  
  -- Draw the background
  Color.set("bgColor")
  gfx.rect(0, 0, gfx.w, gfx.h, true)
  
  -- Reset status message at the start of each frame
  s.status = ""

  -- Process all buttons
  for _,btn in ipairs(ui.buttons) do
    btn:draw(mouse)
    if (mouse.clickL or mouse.clickR) and btn.b:contains(mouse.x, mouse.y) then
      btn.exec(btn, mouse)
    end
  end
  
  -- Draw the color picker
  if s.mode == "circle" then
    -- Draw the main color picker and snap grid
    b1 = ui.cbox
    gfx.x, gfx.y = b1.x, b1.y
    gfx.blit(1, b1.w / ui.prepSize, 0)
    if s.snap then
      drawSnapCircle(b1.x + (b1.w / 2), b1.y + (b1.h / 2), b1.w / 2)
    end
    Color.set("black")
    bgx.circle(b1:CX(), b1:CY(), b1.w / 2, 1)
    
    -- Handle click
    if mouse.lb and b1:contains(mouse.x, mouse.y) then
      local ang,r = Math.cartToPolar(mouse.x, mouse.y, b1:CX(), b1:CY())
      if r <= b1.w / 2 then
        if ang < 0 then ang = ang + 2 end
        state.hue = ang / 2
        state.sat = r / (b1.w / 2)
      end
      if s.snap then
        s.hue,s.sat = snapHueSat(s.hue, s.sat)
      end
    end
    
    -- Draw selection circle
    Color.set("white")
    local cx,cy = Math.polarToCart(state.hue * 2, state.sat * b1.w / 2, b1:CX(), b1:CY())
    bgx.circle(cx, cy, ui.selCircleSize, ui.selCircleThick)
    
  elseif s.mode == "box" then
    -- Draw color picker and snap grid
    b1 = ui.cbox
    gfx.x,gfx.y = b1.x,b1.y
    gfx.blit(2, b1.w / ui.prepSize, 0)
    if s.snap then
      drawSnapGrid(b1)
    end
    Color.set("black")
    bgx.rect(b1, false, 2)
    
    
    -- Handle click
    if mouse.lb and b1:contains(mouse.x, mouse.y) then
      -- To correctly calculate the hue we have to offset backwards
      local hue,sat = b1:unlerp(mouse.x, mouse.y)
      state.hue, state.sat = offsetHue(hue), 1 - sat
      if s.snap then
        s.hue,s.sat = snapHueSat(s.hue, s.sat)
      end
    end
    
    -- Draw selection circle. Since we offset the hue when drawing
    -- we have to do the same here
    Color.set("white")
    local cx,cy = b1:lerp(offsetHue(state.hue, true), 1 - state.sat)
    bgx.circle(cx, cy, ui.selCircleSize, ui.selCircleThick)
    
  else
    _=dm and Msg("Invalid state " .. state.mode)
  end

  -- Draw the lightness scale
  do
    local color1 = {hslToRgb(s.hue, s.sat, 0.5)}
    b1 = ui.lbox
    b2 = b1:clone():setSize(b1.w, b1.h / 2)
    bgx.gradRect(b2, {1,1,1}, color1, true)
    b2:alter(0, b2.h)
    bgx.gradRect(b2, color1, {0,0,0}, true)
    -- Circle for lightness scale
    Color.set("black")
    --Msg(string.format("%f,%f,%f", gfx.r, gfx.g, gfx.b))
    local cx,cy = ui.lbox:lerp(0.5, 1 - s.lum)
    bgx.circle(cx, cy, ui.selCircleSize, ui.selCircleThick)
    bgx.rect(b1, false)
    
    -- Process lightness scale click. We expand the horizontal area to make it easier.
    b2 = b1:clone():pad(ui.lumSliderClickPad, 0)
    if mouse.lb and b2:contains(mouse.x, mouse.y) then
      local _,lum = b2:unlerp(b2:CX(), mouse.y)
      lum = 1 - lum
      s.lum = lum
    end
  end
  
  -- Draw the current color
  do
    local cr,cg,cb = hslToRgb(s.hue, s.sat, s.lum)
    gfx.set(cr, cg, cb)
    bgx.roundRect(ui.currentBox, ui.cornerRad, true, true)
    Color.set("black")
    bgx.roundRect(ui.currentBox, ui.cornerRad, true, false)
    --bgx.roundRect(ui.currentBoxText, ui.cornerRad, true, false)
    if s.sat == 0 then
      Color.set("black")
    else
      gfx.set(hslToRgb(s.hue, s.sat, bmath.wrap(0, 1, s.lum + 0.5)))
    end
    bgx.str(ui.currentBoxText, "Color", 1)
    bgx.str(ui.currentBoxText, "#" .. Color.toHex(cr, cg, cb), 1 + 8)
  end
  
  -- Draw HSL and RGB values
  Color.set("black")
  --bgx.roundRect(ui.rgbBox, ui.cornerRad, true, false)
  --bgx.roundRect(ui.hslBox, ui.cornerRad, true, false)
  do
    -- HSV Labels
    Color.set("white")
    b1 = ui.hslBoxText:clone():cellY(0, 1, 3)
    bgx.str(b1:alter(0,    0), "Hue", 2 + 4)
    bgx.str(b1:alter(0, b1.h), "Saturation", 2+4)
    bgx.str(b1:alter(0, b1.h), "Luminance", 2+4)
    
    -- HSV Values
    local nhue,nsat,nlum
    b1 = ui.hslBoxVals
    nhue = colorNumBox(b1:clone():cellY(0, 1, 3), "Hue", s.hue, 359, mouse)
    nsat = colorNumBox(b1:clone():cellY(1, 1, 3), "Saturation", s.sat, 240, mouse)
    nlum = colorNumBox(b1:clone():cellY(2, 1, 3), "Luminance", s.lum, 240, mouse)
    s.hue, s.sat, s.lum = nhue or s.hue, nsat or s.sat, nlum or s.lum
  end
  
  -- Draw RGB values
  do
    Color.set("white")
    b1 = ui.rgbBoxText:clone():cellY(0, 1, 3)
    bgx.str(b1:alter(0,    0), "Red", 2+4)
    bgx.str(b1:alter(0, b1.h), "Green", 2+4)
    bgx.str(b1:alter(0, b1.h), "Blue", 2+4)
    
    local r,g,b = hslToRgb(s.hue, s.sat, s.lum)
    local nr,ng,nb
    b1 = ui.rgbBoxVals
    nr = colorNumBox(b1:clone():cellY(0, 1, 3), "Red", r, 255, mouse)
    ng = colorNumBox(b1:clone():cellY(1, 1, 3), "Green", g, 255, mouse)
    nb = colorNumBox(b1:clone():cellY(2, 1, 3), "Blue", b, 255, mouse)
    if nr or ng or nb then
      nr, ng, nb = (nr or r), (ng or g), (nb or b)
      Msg3f(nr, ng, nb)
      s.hue, s.sat, s.lum = rgbToHsl(nr, ng, nb)
      Msg3f(s.hue, s.sat, s.lum)
      Msg3f(hslToRgb(s.hue, s.sat, s.lum))
    end
  end
  
  
  -- Status message. Drawn at the end to give all elements the chance
  -- to update the status. This is basically the last thing to be drawn.
  if s.status ~= "" then
    Color.set("white")
    bgx.str(ui.statusBox, s.status, 2 + 4)
  end
  
  -- Update current mouse state
  s.mouse = mouse
  -- Make sure we keep updating the UI
  gfx.update()
  -- Check to see if the UI is closed
  if gfx.getchar() == -1 then
    callAfter()
  end
  
  if not s.done then
    reaper.defer(uiLoop)
  end
end

-- Prepare the various background images
local function prepImages(w, h)
  local gfx, deg, sin, cos, atan = gfx, math.deg, math.sin, math.cos, math.atan
  local pi2 = math.pi * 2
  
  local function distF(rx, ry) return math.sqrt((rx * rx) + (ry * ry)) end
  
  -- First set images to the correct dimensions and fill them, so they at least
  -- appear while being prepared. Then process PART of the image each frame
  -- until the images are done. This makes it FEEL like the GUI loads faster.

  -- Fill the backgrounds with transparent pixels
  gfx.set(1,1,1,0)
  
  -- Circle
  gfx.setimgdim(1, w, h)
  gfx.dest = 1
  gfx.rect(0, 0, w, h, true)
  
  -- Box
  gfx.setimgdim(2, w, h)
  gfx.dest = 2
  gfx.rect(0, 0, w, h, true)
  
  -- Now we iteratively prepare rows of the image
  local ROWS_PER_CALL = math.floor(h / 2)
  local track = 0
  local prevDest = -1
  
  coroutine.yield()
  
  prevDest, gfx.dest = gfx.dest, 1
  gfx.set(1,1,1,1)
  -- Now draw the gradient
  local cx, cy = w / 2, h / 2
  for y=0,h do
    
    -- We only process part of the image each frame.
    -- 
    track = track + 1
    if track == ROWS_PER_CALL then
      track = 0
      gfx.dest = prevDest
      coroutine.yield()
      -- On resume
      prevDest, gfx.dest = gfx.dest, 1
    end
  
    for x=0,w do
      gfx.x,gfx.y = x,y
      local rx,ry = x - cx, y - cy
      local ang, dist = atan(ry, rx), distF(rx, ry)
      if dist > cx then
        gfx.a = 0
      else
        gfx.a = 1
        local h,s,l = (ang / pi2), (dist / cx), 0.5
        if h < 0 then h = h + 1 end
        local r,g,b = hslToRgb(h,s,l)
        gfx.setpixel(r,g,b)
      end
    end
  end
  
  gfx.dest = 2
  gfx.a = 1
  -- Now draw the gradient
  for y = 0,h do
  
    track = track + 1
    if track == ROWS_PER_CALL then
      track = 0
      gfx.dest = prevDest
      coroutine.yield()
      -- On resume
      prevDest, gfx.dest = gfx.dest, 2
      gfx.a = 1
    end
  
    for x = 0,w do
      gfx.x, gfx.y = x, y
      local r,g,b = hslToRgb(offsetHue(x / w), 1.0 - (y / h), 0.5)
      gfx.setpixel(r,g,b)
    end
  end
  
  -- Reset drawing dest
  gfx.dest = -1
end

--- Returns an array of {r,g,b} arrays in the range [0,1]
local function GetFavoriteColors()
  local fColors = reaper.GetExtState(EXT_STATE_PATH, "favoriteColors")
  return loadColorList(fColors, ui.favoriteColorsCount, {1,1,1})
end

--- Display the color picker.
local ShowColorPicker
ShowColorPicker = function(opts)
  opts = opts or {}
  -- Setup the UI
  ui = buildUI(opts.scale or 1)
  
  do
    -- Set starting state values
    local s = state
    local rgb = opts.color or {50, 50, 58}
    s.hue, s.sat, s.lum = rgbToHsl(rgb[1]/255, rgb[2]/255, rgb[3]/255)
    s.startColor = {s.hue, s.sat, s.lum}
    s.ok, s.done = false, false
    s.mode = opts.mode or "circle"
    s.snap = true
    s.after = opts.after or function() end
    s.threads = {}
    
    -- Here we load our recent and favorite colors
    local rColors = reaper.GetExtState(EXT_STATE_PATH, "recentColors")
    s.recentColors = loadColorList(rColors, ui.recentColorsCount, {1,1,1})
    -- Load favorite colors
    local scolors = opts.favoriteColors or reaper.GetExtState(EXT_STATE_PATH, "favoriteColors")
    s.favoriteColors = loadColorList(scolors, ui.favoriteColorsCount, {1,1,1})
  end
  
  local win_x, win_y = opts.x, opts.y
  if not (win_x and win_y) then
    -- Create a window so we can get the mouse x and y
    gfx.init("Basic", 0, 0, 0, 0, 0)
    win_x, win_y = (win_x or gfx.mouse_x), (win_y or gfx.mouse_y)
    gfx.quit()
  end
  
  -- Create our real window at the correct size and location
  gfx.init("Color Picker", ui.w, ui.h, 0, win_x, win_y)
  -- Prepare the color scale images
  table.insert(state.threads,
    coroutine.create(function() return prepImages(ui.prepSize, ui.prepSize) end))
  
  -- Set the default font
  --if bgx.setFont(1, "DejaVu Sans Mono", 14 * RSCALE)
  if bgx.setFont(1, "Arial", 16 * ui.scale, 0) == -1 then
    reaper.MB("Error", "Unable to set font", 0)
  end
  gfx.setfont(1)
  
  -- Prepare emergency exit call
  reaper.atexit(callAfter)
  
  -- Create our buttons
  local btnTop, btnBot, btnBorder = 
    Color.fromRgba(80, 80, 80), Color.fromRgba(50, 50, 50), Color.fromRgba(40, 40, 40)
  local btns = {}
  btns[1] = Button(ui.btnCircleBox, {
    img = 1,
    src = Box(0, 0, ui.prepSize),
    exec = function(self, mouse)
      if not mouse.clickL then return end
      state.mode = "circle"
    end,
  })
  btns[2] = Button(ui.btnSquareBox, {
    img = 2,
    src = Box(0, 0, ui.prepSize),
    exec = function(self, mouse)
      if not mouse.clickL then return end
      state.mode = "box"
    end,
  })
  btns[3] = Button(ui.btnSnapBox, {
    text = "Snap",
    flags = 0x1 | 0x4,
    color = "btnHighlight",
    exec = function(self, mouse)
      if not mouse.clickL then return end
      state.snap = not state.snap
      if state.snap then
        self.color = "btnHighlight"
      else
        self.color = {0, 0, 0}
      end
    end,
  })
  btns[4] = Button(ui.okBtnBox, {
    text = "Accept",
    flags = 1 | 4,
    color = "white",
    gradient = { btnTop, btnBot, true },
    border = btnBorder,
    exec = function(self, mouse)
      if not mouse.clickL then return end
      state.ok = true
      callAfter()
      gfx.quit()
    end,
  })
  btns[5] = Button(ui.resetBtnBox, {
    text = "Reset",
    flags = 1 | 4,
    color = "white",
    gradient = { btnTop, btnBot, true },
    border = btnBorder,
    exec = function(self, mouse)
      if not mouse.clickL then return end
      local s = state
      s.hue, s.sat, s.lum = table.unpack(s.startColor)
      -- Reload favorite colors
      local fColors = reaper.GetExtState(EXT_STATE_PATH, "favoriteColors")
      s.favoriteColors = loadColorList(fColors, ui.favoriteColorsCount, {1,1,1})
      -- Update favorite color buttons
      local btnL = ui.buttons
      for i = 1,#btnL do
        if btnL[i].btnI then
          local c = s.favoriteColors[btnL[i].btnI]
          btnL[i].gradient = {c, c, true}
        end
      end
    end,
  })
  btns[6] = Button(ui.rescaleBtnBox, {
    text = "Rescale",
    flags = 1 | 4,
    color = "white",
    gradient = { btnTop, btnBot, true },
    border = btnBorder,
    exec = function(self, mouse)
      if mouse.clickL then
        local ok, ret = reaper.GetUserInputs("Rescale", 1, "Scale (0.5 - 3)", "")
        local retn = tonumber(ret)
        if retn ~= nil then
          gfx.quit()
          opts.scale = bmath.clamp(0.5, 3, retn)
          ShowColorPicker(opts)
        end
      end
    end,
  })
  
  for i = 1,ui.recentColorsCount do
    local btnColor = state.recentColors[i]
    table.insert(ui.buttons, Button(ui.recColors[i], {
      gradient = { btnColor, btnColor, true },
      border = btnBorder,
      status = ("Recent color #%d"):format(i),
      exec = function(self, mouse)
        state:setHSL(rgbToHsl(table.unpack(btnColor)))
      end,
    }))
  end
  
  for i = 1,ui.favoriteColorsCount do
    local btnColor = state.favoriteColors[i]
    table.insert(ui.buttons, Button(ui.favColors[i], {
      gradient = { btnColor, btnColor, true },
      border = btnBorder,
      status = ("Favorite #%d (right-click to set)"):format(i),
      data = {
        btnI = i,
      },
      exec = function(self, mouse)
        if mouse.clickL then
          state:setHSL(rgbToHsl(table.unpack(self.gradient[1])))
        elseif mouse.clickR then
          local rgb = {hslToRgb(state.hue, state.sat, state.lum)}
          state.favoriteColors[self.btnI] = rgb
          self.gradient = { rgb, rgb, true }
        end
      end,
    }))
  end
  
  -- Add all buttons to the UI
  for _,btn in ipairs(btns) do table.insert(ui.buttons, btn) end
  
  -- Start the UI loop
  reaper.defer(uiLoop)
end

if debug_mode then
  ShowColorPicker{
    -- default window X, may be nil
    x = 200,
    -- default window Y, may be nil
    y = 200,
    -- default color
    color = {118, 118, 137},
    -- window scale, default is 1.0
    scale = 1.0,
    -- Function called on accept, color is {r,g,b}
    after = function(ok, color)
      local fmt = "Ok: %s | Selected color: %d %d %d\n"
      reaper.ShowConsoleMsg(fmt:format(tostring(ok), color[1], color[2], color[3]))
    end,
  }
end

return {
  Show = ShowColorPicker,
  GetFavoriteColors = GetFavoriteColors,
}

