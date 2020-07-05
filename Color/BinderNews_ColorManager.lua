-- Load my own libraries
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "../?.lua"

local U = require("bn.util")

if not reaper.BR_Win32_WritePrivateProfileString then
  reaper.MB("This script requires the SWS extension", "Error", 0)
  return
end

--- Convert an array of bytes to a string that can be written using
-- BR_Win32_WritePrivateProfileString.
-- @param ar Table of bytes
local function bytesToProfileString(ar)
  local t, sum, b = {}, 0, 0
  for i = 1,#ar do
    b = ar[i]
    t[#t+1] = string.format("%02X", b)
    sum = sum + b
  end
  sum = sum % 256
  t[#t+1] = string.format("%02X", sum)
  return table.concat(t)
end


-- Read Reaper's custom colors
local ok, custcolors = reaper.BR_Win32_GetPrivateProfileString("REAPER", "custcolors", "", reaper.get_ini_file())
--U.msg(custcolors)
if not ok then
  reaper.MB("Failed to read custom colors", "Error", 0)
  return
end

local len = custcolors:len() - 1
local colors = {}
for i = 1,(8*16),8 do
  table.insert(colors, custcolors:sub(i, i + 6))
end
colors = table.concat(colors, ",")

local ColorPicker = require("Color/BinderNews_ColorPicker")
ColorPicker.Show{
  x = 200,
  y = 200,
  scale = 1.0,
  favoriteColors = colors,
  after = function(ok, color)
    if ok then
      local function addI(t, v) t[#t+1] = math.floor((v * 255) + 0.5) end
      local favColors = ColorPicker.GetFavoriteColors()
      local ar = {}
      for i = 1,#favColors do
        local r,g,b,a = table.unpack(favColors[i])
        -- They all show up black unless alpha is 0
        a = 0
        addI(ar, r)
        addI(ar, g)
        addI(ar, b)
        addI(ar, a)
      end
      -- Now double it to get 16 colors
      --[[local arLen = #ar
      for i = 1,arLen do
        ar[i + arLen] = ar[i]
      end]]--
      local custcolors = bytesToProfileString(ar)
      --U.msg(custcolors)
      reaper.BR_Win32_WritePrivateProfileString("REAPER", "custcolors", custcolors, reaper.get_ini_file())
    end
  end,
}



