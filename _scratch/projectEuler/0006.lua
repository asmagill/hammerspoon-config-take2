local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

sumOfSquares = function(n)
    local ans = 0
    for i = 1, n, 1 do
        ans = ans + i * i
    end
    return ans
end

squareOfSums = function(n)
    local term = (n + 1) * n / 2
    return term * term
end

a, b = squareOfSums(100), sumOfSquares(100)
print(a, b, a - b)

print(systemTime() - t)
