local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local sum, offset = 0, 0
for i = 1, 1001, 2 do
    local UR = math.tointeger(i^2)
    sum = sum + UR
    if i > 1 then
        local UL = UR - offset
        local LL = UL - offset
        local LR = LL - offset
        sum = sum + UL + LL + LR
    end
    offset = offset + 2
end

print(sum)

print(systemTime() - t)
