local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- https://helloacm.com/efficient-prime-factorization-algorithm-integer-factorization/
primeFactors = function(n)
    local ans = {}
    while n % 2 == 0 do
        table.insert(ans, 2)
        n = n // 2
    end

    local i = 3
    while i * i <= n do
        while n % i == 0 do
            table.insert(ans, i)
            n = n // i
        end
        i = i + 2
    end

    if n > 2 then table.insert(ans, n) end

    local asString = inspect(ans)
    return setmetatable(ans, { __tostring = function(_) return asString end })
end

print(primeFactors(600851475143))

print(systemTime() - t)
