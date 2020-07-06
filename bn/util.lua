local reaper, string = reaper, string



local U = {}

function U.msg(msg) reaper.ShowConsoleMsg(tostring(msg) .. "\n") end
function U.msgfmt(msg, ...) reaper.ShowConsoleMsg(string.format(msg, ...) .. "\n") end


function U.setconfig(project, section, key, value)
  local sec, k2 = tostring(section), tostring(key)
  if project == -1 then
    if value == nil then
      reaper.DeleteExtState(sec, k2, true)
    else
      reaper.SetExtState(sec, k2, tostring(value), true)
    end
  else
    reaper.SetProjExtState(project, sec, k2, value)
  end
end

function U.getconfig(project, section, key, default)
  local sec, k2 = tostring(section), tostring(key)
  local ok,v
  if project == -1 then
    ok, v = reaper.GetExtState(sec, k2)
  else
    ok, v = reaper.GetProjExtState(project, sec, k2)
  end
  if not ok then
    return default
  else
    return v
  end
end

--- Returns the first value of the parameters that isn't nil.
-- This makes it easier to use default parameters that are falsy.
function U.firstOf(...)
  local count = select("#", ...)
  for i = 1,count do
    local v = select(i, ...)
    if item ~= nil then
      return item
    end
  end
end

return U
