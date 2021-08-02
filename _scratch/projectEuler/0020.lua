local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local bigint = require("_scratch.projectEuler._bigint")

factorial = function(n)
    local ans = bigint(1)
    for i = 2, n, 1 do ans = ans * bigint(i) end
    return ans
end

answer = factorial(100)

local sum = 0
for _, v in ipairs(answer) do
    sum = sum + v
end
print(sum)

print(systemTime() - t)
