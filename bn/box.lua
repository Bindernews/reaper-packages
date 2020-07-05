
local bmath = require("bn.bmath")
local lerp, unlerp = bmath.lerp, bmath.unlerp

-- Simple rectangle class
local Box = {
  type = "Box",
  
  L = function(self) return self.x end,
  R = function(self) return self.x + self.w end,
  T = function(self) return self.y end,
  B = function(self) return self.y + self.h end,
  CX = function(self) return self.x + (self.w / 2) end,
  CY = function(self) return self.y + (self.h / 2) end,
  alter = function(self, dx, dy, dw, dh)
    self.x,self.y = self.x + dx, self.y + dy
    self.w,self.h = self.w + (dw or 0), self.h + (dh or 0)
    return self
  end,
  pad = function(self, dx, dy, dw, dh)
    local px, py = dx, (dy or dx)
    local pw, ph = (dw or px), (dh or py)
    return self:alter(-px, -py, px + pw, py + ph)
  end,
  set = function(self, x, y, w, h)
    self.x,self.y,self.w,self.h = x,y,w,h
    return self
  end,
  setPos = function(self, x, y)
    self.x,self.y = x,y
    return self
  end,
  setSize = function(self, w, h) return self:resize(w, h) end,
  floor = function(self) return self:apply(math.floor) end,
  ceil = function(self) return self:apply(math.ceil) end,
  round = function(self) return self:apply(bmath.round) end,
  apply = function(self, op)
    self.x, self.y, self.w, self.h = op(self.x), op(self.y), op(self.w), op(self.h)
    return self
  end,
  cellX = function(self, index, count, numCells)
    local sz = self.w / numCells
    return self:set(self.x + (index * sz), self.y, sz * count, self.h)
  end,
  cellY = function(self, index, count, numCells)
    local sz = self.h / numCells
    return self:set(self.x, self.y + (index * sz), self.w, sz * count)
  end,
  frac = function(self, fX, fY)
    local szW = math.abs(self.w * fX)
    local szH = math.abs(self.h * fY)
    if fX < 0 then
      self.x = self:R() - szW
    end
    if fY < 0 then
      self.y = self:B() - szH
    end
    self.w = szW
    self.h = szH
    return self
  end,
  lerp = function(self, vX, vY)
    return lerp(self.x, self.x + self.w, vX), lerp(self.y, self.y + self.h, vY)
  end,
  unlerp = function(self, vX, vY)
    return unlerp(self.x, self.x + self.w, vX), unlerp(self.y, self.y + self.h, vY)
  end,
  unlerpIn = function(self, vX, vY)
    return unlerp(self.x + 1, self.x + self.w - 1, vX), unlerp(self.y + 1, self.y + self.h - 1, vY)
  end,
  unpack = function(self)
    return self.x,self.y,self.w,self.h
  end,
  contains = function(self, x, y)
    return (self.x <= x) and (self.y <= y)
      and (x <= self.x + self.w) and (y <= self.y + self.h)
  end,
  clone = function(self)
    return setmetatable({ x = self.x, y = self.y, w = self.w, h = self.h }, getmetatable(self))
  end,
}
Box.__index = Box
-- Constructor
function Box.new(x, y, w, h)
  -- May also specify existing tables as params
  if type(x) == "table" then
    local t = x
    if t.x then
      x,y,w,h = t.x,t.y,t.w,t.h
    else
      x,y,w,h = table.unpack(t)
    end
  end
  return setmetatable({ x = x, y = y, w = w, h = h or w }, Box)
end

function Box:inside(x, y, w, h)
  self.x, self.y = self.x + x, self.y + y
  self.w, self.h = w, (h or w)
  return self
end

function Box:resize(nw, nh)
  if nw < 0 then self.x = self:R() + nw end
  if nh < 0 then self.y = self:B() + nh end
  self.w, self.h = math.abs(nw), math.abs(nh)
  return self
end

--- Set the right and bottom values of the box.
-- @param r Right value or nil to leave unchanged
-- @param b Bottom value or nil to leave unchanged
-- @return self
function Box:setRB(r, b)
  if r ~= nil then self.w = r - self.x end
  if b ~= nil then self.h = r - self.y end
  return self
end

return setmetatable(Box, {
  __call = function(self, ...) return self.new(...) end
})
