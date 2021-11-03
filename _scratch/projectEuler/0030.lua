local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- can't simply iterate with five loops (though this does work for the 4th pwr version)
-- because answer may have 6 digits...

local ans = {}
local pwr = 5
local max = pwr * (9^pwr)

for i = 2, max, 1 do
    local is, s2 = tostring(i), 0
    for j = 1, #is, 1 do s2 = s2 + (tonumber(is:sub(j,j))^pwr) end

    if s2 == i then table.insert(ans, s2) end
end

local sum = 0
for _, v in ipairs(ans) do sum = sum + v end

print(sum)
print(systemTime() - t)

print(inspect(ans))

t = systemTime()

ans = {}

for i = 2, max, 1 do
    local i2, s2 = i, 0
    repeat
        local q, r = i2 // 10, i2 % 10
        i2 = q
        s2 = s2 + r^pwr
    until q == 0

    if s2 == i then table.insert(ans, s2) end
end

local sum = 0
for _, v in ipairs(ans) do sum = sum + v end
print(sum)
print(systemTime() - t)

print(inspect(ans))

