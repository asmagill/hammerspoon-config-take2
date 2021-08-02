local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()



print(systemTime() - t)
