local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local bigint = require("_scratch.projectEuler._bigint")

-- this avoids the need to support multiplication (for this particular problem)
-- and is significantly faster to boot
local cache = {}
newBigIntForPowerOf2 = function(n)
    if cache[n] then return cache[n] end

    local ans = bigint(1)

    if n > 0 then
        ans = newBigIntForPowerOf2(n - 1) + newBigIntForPowerOf2(n - 1)
    end

    cache[n] = ans
    return ans
end

insane = newBigIntForPowerOf2(1000)
sum = 0
for _, v in ipairs(insane) do sum = sum + v end

print(sum)
print(systemTime() - t)
print(insane)

-- multiplication is slower
t = systemTime()

local nowWithMultiplication = function(n)
    local ans = bigint(1)

    for i = 1, n, 1 do
        ans = ans * 2
    end
    return ans
end

insane2 = nowWithMultiplication(1000)
sum = 0
for _, v in ipairs(insane) do sum = sum + v end

print(sum)
print(systemTime() - t)
print(insane2)

print(insane == insane2)
