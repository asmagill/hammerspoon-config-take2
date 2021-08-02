local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local sievedPrimes = {}
local isPrime = {}

local isPrimeLookup = function(n, allowNegative)
    local ans = isPrime[n]
    if allowNegative then n = math.abs(n) end
    if n > 0 and ans == nil then
        error(string.format("prime sieve not large enough; need at least %d", n))
    else
        return ans
    end
end

local buildSieve = function(max_size)
    -- force a freeing of used memory
    sievedPrimes, isPrime = {}, {} ; collectgarbage() ; collectgarbage() ;
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

    for p = 2, max_size, 1 do
        if isPrime[p] then table.insert(sievedPrimes, p) end
    end
end

buildSieve(50000)
print(systemTime() - t)

-- return (x - 1) for n^2 + an + b == prime for n = [0...x]
--
-- So by definition, since n=0 is possible, b *must* be prime itself
lengthOfPrimeSequence = function(a, b)
    if not isPrimeLookup(b) then return 0 end

    local f = function(n) return math.tointeger(n^2) + a * n + b end

    local n = 0

    while isPrimeLookup(f(n)) do n = n + 1 end
    return n
end

local maxLength, maxA, maxB = 0, 0, 0

for a = -999, 999, 1 do
    for b = -1000, 1000, 1 do
        local length = lengthOfPrimeSequence(a, b)
        if length > maxLength then
            maxLength, maxA, maxB = length, a, b
        end
    end
end

print(maxLength, maxA, maxB, maxA * maxB)

print(systemTime() - t)
