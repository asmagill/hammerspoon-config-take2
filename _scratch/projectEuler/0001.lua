local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local a = 0 ; for i = 3, 999, 1 do if (i % 3) == 0 or (i % 5 == 0) then a = a + i end end ; print(a)

print(systemTime() - t)
