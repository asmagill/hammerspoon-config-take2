local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local d = function(n)
    local max = math.sqrt(n)
    local sum = 0
    for i = 1, max, 1 do
        if n % i == 0 then
            sum = sum + i
            if i ~= max and i ~= 1 then sum = sum + (n // i) end
        end
    end
    return sum
end

local dTable = {}

for i = 2, 9999, 1 do dTable[i] = d(i) end

amicableNumbers = {}

local sum = 0
for k,v in pairs(dTable) do
    if dTable[v] == k and v ~= k then
        sum = sum + k
        table.insert(amicableNumbers, k)
    end
end

print(sum)

print(systemTime() - t)
