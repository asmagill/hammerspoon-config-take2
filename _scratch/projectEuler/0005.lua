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

smallest = function(n)
    local ansPrimeCounts = { }
    for i = n, 2, -1 do
        local ps = primeFactors(i)
        local myPrimeCounts = {}
        for _, v in ipairs(ps) do
            myPrimeCounts[v] = (myPrimeCounts[v] or 0) + 1
        end
        for k, v in pairs(myPrimeCounts) do
            ansPrimeCounts[k] = math.max(ansPrimeCounts[k] or 0, v)
        end
    end
    local ans = 1
    for k, v in pairs(ansPrimeCounts) do ans = ans * k ^ v end
    return ans
end

print(smallest(10))
print(smallest(20))

print(systemTime() - t)
