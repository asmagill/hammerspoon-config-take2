local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local MAX = 28123

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

abundantNumbers = {}
sums = {}

local idx = 12

while true do
    local ans = d(idx)
    if ans > idx then
        if idx + 12 > MAX then break end
        table.insert(abundantNumbers, idx)
    end
    idx = idx + 1
end

print(systemTime() - t)

-- not sure this can be optimized more or not... it's the slowest part taking almost
-- 20 seconds, but not below about assignment... small, but noticable
for i = 1, #abundantNumbers, 1 do
    local n = abundantNumbers[i]
    for j = i, #abundantNumbers, 1 do
        local possible = n + abundantNumbers[j]
        if possible <= MAX then
            -- apparently assignment, if it is already assigned is
            -- expensive, this shaves 1.5 seconds off
            if not sums[possible] then sums[possible] = true end
        else
            break
        end
    end
end

print(systemTime() - t)

wantedSum = 0
for i = 1, MAX, 1 do
    if not sums[i] then
        wantedSum = wantedSum + i
    end
end

print(wantedSum)

print(systemTime() - t)
