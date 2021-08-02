local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

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

local max, a, b = 0, 0, 0
for i = 100, 999, 1 do
    for j = 100, 999, 1 do
        local prod = i * j
        if prod > max and isPalindrome(prod) then max, a, b = prod, i, j end
    end
end

print(max, a, b)

print(systemTime() - t)
