local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local sievedPrimes = {}
local buildSieve = function(max_size)
    -- force a freeing of used memory
    sievedPrimes = nil ; collectgarbage() ; collectgarbage() ;
    local isPrime = {}
    for i = 1, max_size, 1 do isPrime[i] = true end

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

    sievedPrimes = {}
    for p = 2, max_size, 1 do
        if isPrime[p] then table.insert(sievedPrimes, p) end
    end
    -- force a freeing of used memory
    isPrime = nil ; collectgarbage() ; collectgarbage()
end

NthPrimeSieve = function(n)
    if #sievedPrimes < n then
    -- see https://en.wikipedia.org/wiki/Prime_number_theorem#Approximations_for_the_nth_prime_number
        if n < 6 then
            buildSieve(11)
        else
            buildSieve(n*(math.log(n)+math.log(math.log(n))))
        end
    end
    return sievedPrimes[n]
end

sumOfPrimes = function(max)
    buildSieve(max)
    local s = 0
    for _, v in ipairs(sievedPrimes) do
        if v < max then s = s + v else break end
    end
    return s
end

print(sumOfPrimes(2000000))

print(systemTime() - t)
