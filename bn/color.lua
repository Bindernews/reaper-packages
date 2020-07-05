
local Color = {}

function Color.hslToRgb(h, s, l)
  if s == 0 then return 1, 1, 1 end
  h = h*6
  local c = (1-math.abs(2*l-1))*s
  local x = (1-math.abs(h%2-1))*c
  local m,r,g,b = (l-.5*c), 0,0,0
  if h < 1     then r,g,b = c,x,0
  elseif h < 2 then r,g,b = x,c,0
  elseif h < 3 then r,g,b = 0,c,x
  elseif h < 4 then r,g,b = 0,x,c
  elseif h < 5 then r,g,b = x,0,c
  else              r,g,b = c,0,x
  end
  return r+m,g+m,b+m
end


function Color.rgbToHsl(r, g, b)
  local mx, mn = math.max(r,g,b), math.min(r,g,b)
  local df = mx - mn
  local h,s,l = 0,0,(mx+mn)/2
  if df == 0 then 
    return h,s,l
  else 
    s = df / (1 - math.abs(2*l-1))
  end
  if     r == mx then h = ((g-b)/df)%6
  elseif g == mx then h = ((b-r)/df)+2
  elseif b == mx then h = ((r-g)/df)+4
  end
  return h/6,s,l
end

return Color