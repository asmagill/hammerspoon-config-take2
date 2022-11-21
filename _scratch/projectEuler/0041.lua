local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local sievedPrimes = {}
local isPrime = {}

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

local isPanDigital = function(num)
    local numAsString = tostring(num)
    local size = #numAsString

    local answer = true
    local i = 1
    while i <= size and answer do
        answer = numAsString:match(tostring(i))
        i = i + 1
    end

    return answer and true or false
end

-- -- this is the annoying part because it takes 2776.5327889919 seconds to build...
-- -- (only on 8GB machine? Try when new laptop comes in to see if it was a paging issue)
-- buildSieve(987654321) -- and yes, I did this first... read forum for speedup below

-- 9...1 will be divisible by 3
-- 8...1 will be divisible by 3
-- so start with 7 digits (reduces sieve build time to 2 seconds... go figure)
buildSieve(7654321)
print(systemTime() - t)

for i = #sievedPrimes, 1, -1 do
    if isPanDigital(sievedPrimes[i]) then
        print(sievedPrimes[i])
        break
    end
end

print(systemTime() - t)
