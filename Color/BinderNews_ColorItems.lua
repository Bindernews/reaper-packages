-- Load my own libraries
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "../?.lua"

local U = require("bn.util")

local item = reaper.GetSelectedMediaItem(0, 0)
if item == nil then return end
local take = reaper.GetMediaItemTake(item, 0)
local scolor
local ncolor = reaper.GetDisplayedMediaItemColor2(item, take)
if ncolor == 0 then
  ncolor = reaper.GetThemeColor("col_mi_bg")
end
scolor = {reaper.ColorFromNative(ncolor)}

local ColorPicker = require("Color/BinderNews_ColorPicker")
ColorPicker.Show{
  x = 200,
  y = 200,
  color = scolor,
  scale = 1.0,
  after = function(ok, color)
    if ok then
      reaper.Undo_BeginBlock2(0)
      ncolor = reaper.ColorToNative(color[1], color[2], color[3]) | 0x1000000
      local itemCount = reaper.CountSelectedMediaItems(0)
      for i=0,itemCount-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", ncolor)
      end
      reaper.Undo_EndBlock2(0, "Set item colors", 0)
      reaper.UpdateArrange()
    end
  end,
}


