local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local triangle = function(n) return (n + 1) * n / 2 end

local factorCount = function(n)
    if n == 1 then return 1 end
    local ans = 0
    local max = math.sqrt(n)

    for i = 1, max, 1 do
        if n % i == 0 then ans = ans + ((i == max) and 1 or 2) end
    end
    return ans
end

local i, ans = 0, 0

while ans < 501 do
    i = i + 1
    ans = factorCount(triangle(i))
end

print(i, triangle(i), ans)

print(systemTime() - t)
