local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- local sievedPrimes = {}
-- local isPrime = {}

sievedPrimes = {}
isPrime = {}

local buildSieve = function(max_size)
    -- force a freeing of used memory
    sievedPrimes, isPrime = {}, {} ; collectgarbage() ; collectgarbage() ;
    for i = 2, max_size, 1 do isPrime[i] = true end

    local p = 2
    while p * p <= max_size do
        if isPrime[p] then
            local i = p * p
            while i <= max_size do
                isPrime[i] = false
                i = i + p
            end
        end
        p = p + 1
    end

    for p = 2, max_size, 1 do
        if isPrime[p] then table.insert(sievedPrimes, p) end
    end
end

buildSieve(1000000)

print(systemTime() - t)
t = systemTime()

local sum = 0
for i = #sievedPrimes, 1, -1 do
    local num = sievedPrimes[i]
    if num < 8 then break end

    local isTruncatable = true
    while isTruncatable and num > 0 do
        num = num // 10
        if num ~= 0 then isTruncatable = isPrime[num] end
    end

    if isTruncatable then
        num = sievedPrimes[i]
        while isTruncatable and num > 0 do
            num = tonumber(tostring(num):sub(2)) or 0
            if num ~= 0 then isTruncatable = isPrime[num] end
        end
    end

    if isTruncatable then
        num = sievedPrimes[i]
        print(num)
        sum = sum + num
    end
end
print(sum)

print(systemTime() - t)
