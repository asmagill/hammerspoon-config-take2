local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

factorial = function(n)
    local prod = 1
    while n > 1 do
        prod = prod * n
        n = n - 1
    end
    return prod
end

local factorials = {}
for i = 0, 9, 1 do factorials[i] = factorial(i) end

curiousNumber = function(n)
    local asString = tostring(n)
    local factSum = 0
    for i = 1, #asString, 1 do
        local digit = tonumber(asString:sub(i,i))
        factSum = factSum + factorials[digit]
    end
    return n > 2 and factSum == n
end

local sum = 0

-- factorials[9] * 8 is a 7 digit number, so *any* 8 digit number is too large
local limit = factorials[9] * 7

for i = 10, limit, 1 do
    if curiousNumber(i) then
        print(i)
        sum = sum + i
    end
end
print(sum)

print(systemTime() - t)
