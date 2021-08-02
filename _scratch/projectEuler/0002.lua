local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local m, n = 1, 2
local sumOfEvens = 0
local max = 4000000

while n <= max do
    if n % 2 == 0 then sumOfEvens = sumOfEvens + n end
    m, n = n, m + n
end
print(sumOfEvens)

print(systemTime() - t)
