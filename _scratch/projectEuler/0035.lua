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

buildSieve(1000000)

print(systemTime() - t)
t = systemTime()

-- local rotateNumber = function(n)
--     local ans = {}
--     local seenPatterns = {}
--     local nAsString = tostring(n)
--     seenPatterns[nAsString] = true
--     table.insert(ans, n)
--     for i = 2, #nAsString, 1 do
--         nAsString = nAsString:sub(2) .. nAsString:sub(1,1)
--         if not seenPatterns[nAsString] then
--             table.insert(ans, tonumber(nAsString))
--             seenPatterns[nAsString] = true
--         end
--     end
--     return ans
-- end

-- faster to check while rotating -- halves the time (not counting the time to build the sieve)

local rotateAndCheck = function(n)
    local ans = {}
    local seenPatterns = {}
    local nAsString = tostring(n)
    seenPatterns[nAsString] = true
    table.insert(ans, n)
    for i = 2, #nAsString, 1 do
        nAsString = nAsString:sub(2) .. nAsString:sub(1,1)
        if not seenPatterns[nAsString] then
            local asNumber = tonumber(nAsString)
            if isPrime[asNumber] then
                table.insert(ans, asNumber)
                seenPatterns[nAsString] = true
            else
                ans = nil
                break
            end
        end
    end
    return ans
end

local seenPrimes = {}
local count = 0

for _, v in ipairs(sievedPrimes) do
    if not seenPrimes[v] then
--         local possibles = rotateNumber(v)
--         local arePrimes = true
--         for _, v2 in ipairs(possibles) do
--             arePrimes = isPrime[v2]
--             if not arePrimes then break end
--         end
--         if arePrimes then
--             count = count + #possibles
--             for _, v2 in ipairs(possibles) do seenPrimes[v2] = true end
--             print(inspect(possibles))
--         end
        local cPrimes = rotateAndCheck(v)
        if cPrimes then
            count = count + #cPrimes
            for _, v2 in ipairs(cPrimes) do seenPrimes[v2] = true end
            print(inspect(cPrimes))
        end
    end
    if v > 500000 then break end -- they will have already been seen as a rotated prime
end

print(count)
print(systemTime() - t)
