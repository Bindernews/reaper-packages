-- Load my own libraries
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

if not reaper.BR_Win32_WritePrivateProfileString then
  reaper.MB("This script requires the SWS extension", "Error", 0)
  return
end

local ColorPicker = loadfile(script_path.."/../Color/BinderNews_ColorPicker.lua")()
ColorPicker.Show{
  x = 200,
  y = 200,
  scale = 1.0,
  useSWS = true,
  after = function(ok, color) end,
}
