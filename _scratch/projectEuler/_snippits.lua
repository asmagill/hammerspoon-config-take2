-- Random code snippits developed while considering/solving problems for
-- ProjectEuler.net that seem worth holding on to in some form for potential
-- future use

local inspect = require("hs.inspect")

-- returns the n'th fibonacci number, memoizing calculations to speed up
-- future queries
local memoFib = { [0] = 0, 1 }
fibonacci = function(n)
    local qty = #memoFib
    while n > qty do
        table.insert(memoFib, memoFib[qty] + memoFib[qty - 1])
        qty = qty + 1
    end
    return memoFib[n]
end


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

factors = function(n, proper)
    local ans = {}
    local max = math.sqrt(n)

    for i = 1, max, 1 do
        if n % i == 0 then
            table.insert(ans, i)
            if i ~= max and not (proper and i == 1) then table.insert(ans, n // i) end
        end
    end

    local asStr = inspect(ans)
    return setmetatable(ans, { __tostring = function(_) return asStr end })
end

isPalindrome = function(n)
    local asString = tostring(n)
    local isP, i, j = true, 1, #asString

    while isP and i < j do
        isP = asString:sub(i,i) == asString:sub(j,j)
        i = i + 1
        j = j - 1
    end

    return isP
end

-- Slower than a Sieve of Eratosthenes, but that requires having at least an idea of the
-- largest prime *value* that you might be looking for. Uses memoization so subsequent calls
-- will be faster,
-- FWIW, this took (just) under a second to determine that NthPrime(10001) == 104743
--
-- Moral of the story, unless memory is at a premium, the Sieve is notably faster, even
-- if you have to occasionally rebuild it larger because you miscalculated the maximum
-- value you might want to check...
local primes = { 2, 3 }
NthPrime = function(n)
    local candidate = primes[#primes]
    while #primes < n do
        candidate = candidate + 2 -- no reason to bother with even numbers
        local isP = true
        local sqrtOfCandidate = math.sqrt(candidate)
        for i = 2, #primes, 1 do
            if primes[i] > sqrtOfCandidate then break end
            if candidate % primes[i] == 0 then isP = false ; break end
        end
        if isP then table.insert(primes, candidate) end
    end

    return primes[n]
end

-- this uses the Sieve... it took well under a second to find NthPrimeSieve(10001)
--
-- https://www.geeksforgeeks.org/program-to-find-the-nth-prime-number/ and
-- https://en.wikipedia.org/wiki/Prime_number_theorem#Approximations_for_the_nth_prime_number
--
--  The following will take approx  26.7 seconds to build sieve for 1 millionth prime.
--
-- Sieve is only rebuilt if subsequent calls have a larger `n` -- make your largest call first
-- for fastest results later...
--
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

