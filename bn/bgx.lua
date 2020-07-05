local gfx,math = gfx,math

local bmath = require("bn.bmath")

local bgx = {}

function bgx.circle(x, y, r, thickness)
  x,y = math.floor(x), math.floor(y)
  local r0,r1 = r - (thickness / 2), r + (thickness / 2)
  for i = r0,r1,0.5 do
    gfx.circle(x, y, i)
  end
end

function bgx.rect(box, filled, thickness)
  if thickness == nil then thickness = 1 end
  --reaper.ShowConsoleMsg("spam")
  if thickness <= 1 or filled then
    gfx.rect(box.x, box.y, box.w, box.h, filled)
  else
    local t, ht = thickness, thickness / 2
    gfx.rect(box.x - ht, box.y - ht, box.w + ht, t, true)
    gfx.rect(box.x - ht, box:B() - ht, box.w + ht, t, true)
    gfx.rect(box.x - ht, box.y - ht, t, box.h + ht, true)
    gfx.rect(box:R() - ht, box.y - ht, t, box.h + ht, true)
  end
end

function bgx.str(box, msg, flags)
  gfx.x,gfx.y = box.x,box.y
  gfx.drawstr(msg, flags, box:R(), box:B())
end

function bgx.gradRect(box, color0, color1, vertical)
  local size
  if vertical then
    size = box.h
  else
    size = box.w
  end
  local function calcD(index)
    return (color1[index] - color0[index]) / size
  end
  local r,g,b,a = table.unpack(color0)
  a = a or 1
  local dr,dg,db = calcD(1), calcD(2), calcD(3)
  
  if vertical then
    gfx.gradrect(box.x, box.y, box.w, box.h, r,g,b,a, 0,0,0,0, dr,dg,db,0)
  else
    gfx.gradrect(box.x, box.y, box.w, box.h, r,g,b,a, dr,dg,db,0, 0,0,0,0)
  end
end

--- Draw a rounded rectangle, optionally filled
-- Adapted from Scythe's GFX.roundRect
--
-- @param box Where to draw the rectangle
-- @param r Corner radius
-- @param antialias Use antialiasing or not
-- @param fill Fill the rectangle or not
function bgx.roundRect(box, r, antialias, fill)
  local x,y,w,h = box:unpack()
  local aa = antialias or true
  fill = fill or false
  
  if not fill then
    gfx.roundrect(x, y, w, h, r, aa)
  else
    --x,y,w,h = bmath.round(x), bmath.round(y), bmath.round(w), bmath.round(h)
    if h >= 2 * r then
    
      -- Corners
      gfx.circle(x + r, y + r, r, 1, aa)            -- top-left
      gfx.circle(x + w - r, y + r, r, 1, aa)        -- top-right
      gfx.circle(x + w - r, y + h - r, r , 1, aa)   -- bottom-right
      gfx.circle(x + r, y + h - r, r, 1, aa)        -- bottom-left

      -- Ends
      gfx.rect(x, y + r, r, h - r * 2)
      gfx.rect(x + w - r, y + r, r + 1, h - r * 2)

      -- Body + sides
      gfx.rect(x + r, y, w - r * 2, h + 1)

    else

      r = (h / 2 - 1)

      -- Ends
      gfx.circle(x + r, y + r, r, 1, aa)
      gfx.circle(x + w - r, y + r, r, 1, aa)

      -- Body
      gfx.rect(x + r, y, w - (r * 2), h)

    end

  end
end

bgx.BOLD = string.byte("b")
bgx.ITALIC = string.byte("i")
bgx.UNDERLINE = string.byte("u")

function bgx.setFont(fontId, names, size, flag)
  if names == nil then
    gfx.setfont(fontId)
  else
    if type(names) == "string" then names = {names} end
    for i = 1,#names do
      gfx.setfont(fontId, names[i], size, flag or 0)
      local _,name = gfx.getfont()
      if name == names[i] then
        return i
      end
    end
    return -1
  end
end

function bgx.updateMouse(oldMouse)
  oldMouse = oldMouse or {}
  local ms = {
    x = gfx.mouse_x,
    y = gfx.mouse_y,
    lb = (gfx.mouse_cap &  1) > 0,
    rb = (gfx.mouse_cap &  2) > 0,
    mb = (gfx.mouse_cap & 64) > 0,
    wheelV = gfx.mouse_wheel / 120,
    wheelH = gfx.mouse_hwheel / 120,
  }
  ms.clickL = ms.lb and not oldMouse.lb
  ms.clickR = ms.rb and not oldMouse.rb
  ms.clickM = ms.mb and not oldMouse.mb
  ms.moved = (ms.x ~= oldMouse.x) and (ms.y ~= oldMouse.y)
  
  -- Reset wheel values
  gfx.mouse_wheel, gfx.mouse_hwheel = 0,0
  
  return ms
end

return bgx