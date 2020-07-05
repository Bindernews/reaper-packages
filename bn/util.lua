local reaper, string = reaper, string

local U = {}

function U.msg(msg) reaper.ShowConsoleMsg(tostring(msg) .. "\n") end
function U.msgfmt(msg, ...) reaper.ShowConsoleMsg(string.format(msg, ...) .. "\n") end

return U
