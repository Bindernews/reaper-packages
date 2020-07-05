

local T = {
  concat = table.concat,
  insert = table.insert,
  move = table.move,
  pack = table.pack,
  remove = table.remove,
  sort = table.sort,
  unpack = table.unpack,
}

function T.clone(t, fields, metatable)
  fields, metatable = (fields or true), (metatable or false)
  -- output
  local o = {}
  -- Clone only fields in the table
  if type(fields) == "table" then
    for i,k in ipairs(fields) do
      o[k] = t[k]
    end
  else
    -- Clone all fields
    for k,v in pairs(t) do
      o[k] = v
    end
  end
  -- Update the metatable of our result
  if type(metatable) == "table" then
    setmetatable(o, metatable)
  elseif metatable then
    setmetatable(o, getmetatable(t))
  end
  return o
end
