
local math = math

local function lerp(min, max, v) return (v * (max - min)) + min end
local function unlerp(min, max, v) return (v - min) / (max - min) end
local function wrap(min, max, v)
  local df = max - min
  while v < min do v = v + df end
  while v > max do v = v - df end
  return v
end

local function clamp(min, max, v)
  return math.min(math.max(min, v), max)
end

local function round(n)
  return n > 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
end

local function sign(v)
  if     v < 0 then return -1
  elseif v > 0 then return 1
  else   return 0
  end
end

return {
  lerp = lerp,
  unlerp = unlerp,
  wrap = wrap,
  clamp = clamp,
  round = round,
  sign = sign,
}
