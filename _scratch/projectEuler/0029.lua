local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local c = {}
for a = 2, 100, 1 do
    for b = 2, 100, 1 do
        c[a^b] = true
    end
end

local k, v = next(c)
local count = 0

while k do
    count = count + 1
    k, v = next(c, k)
end

print(count)

print(systemTime() - t)
