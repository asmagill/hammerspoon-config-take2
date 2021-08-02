local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

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

-- https://www.geeksforgeeks.org/program-to-find-the-nth-prime-number/ and
-- https://en.wikipedia.org/wiki/Prime_number_theorem#Approximations_for_the_nth_prime_number
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

print("Without Sieve: ", NthPrime(10001))
local t2 = systemTime()
print(t2 - t1)

print("With Sieve:    ", NthPrimeSieve(10001))
print(systemTime() - t2)
