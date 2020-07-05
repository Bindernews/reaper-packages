-- Load my own libraries
do
  local info = debug.getinfo(1,'S');
  local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
  package.path = package.path .. ";" .. script_path .. "../?.lua"
end



function Msg(msg) reaper.ShowConsoleMsg(tostring(msg) .. "\n") end

local trackCount = reaper.CountSelectedTracks2(0, false)
if trackCount == 0 then
  return
end

local scolor = {118, 118, 137}
local tr = reaper.GetSelectedTrack2(0, 0, false)
local trackColorN = reaper.GetTrackColor(tr)
if trackColorN == 0 then
  trackColorN = reaper.GetThemeColor("col_seltrack2")
end
scolor = {reaper.ColorFromNative(trackColorN)}

local ColorPicker = require("Color/BinderNews_ColorPicker")
ColorPicker.Show{
  x = 200,
  -- default window Y, may be nil
  y = 200,
  -- default color
  color = scolor,
  -- window scale, default is 1.0
  scale = 1.0,
  -- Function called on accept, color is {r,g,b}
  after = function(ok, color)
    if ok then
      -- User may have changed the selected tracks while in the UI
      -- so we get the new number of selected tracks here.
      reaper.Undo_BeginBlock2(0)
      local nativeColor = reaper.ColorToNative(color[1], color[2], color[3]) | 0x1000000
      trackCount = reaper.CountSelectedTracks2(0, false)
      for i=0,trackCount-1 do
        local tr = reaper.GetSelectedTrack2(0, i, false)
        reaper.SetTrackColor(tr, nativeColor)
      end
      reaper.Undo_EndBlock2(0, "Set track colors", 0)
      reaper.UpdateArrange()
    end
  end,
}
