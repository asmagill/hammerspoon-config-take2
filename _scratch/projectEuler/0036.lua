local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local maxBits = 0 ; while (1 << maxBits) ~= 0 do maxBits = maxBits + 1 end
local tobits = function(num)
    local bits = (math.floor(math.log(num,2) / 8) + 1) * 8
    if bits == -(1/0) then bits = 8 end     -- when num == 0
    if bits ~= bits then bits = maxBits end -- when num < 0
    local value = ""
    for i = (bits - 1), 0, -1 do
        value = value..tostring((num >> i) & 0x1)
    end

    while #value > 1 and value:sub(1,1) == "0" do value = value:sub(2) end
    return value
end

local isPalindrome = function(n)
    local asString = tostring(n)
    local isP, i, j = true, 1, #asString

    while isP and i < j do
        isP = asString:sub(i,i) == asString:sub(j,j)
        i = i + 1
        j = j - 1
    end

    return isP
end

local sum = 0

for i = 1, 1000000, 2 do
    if isPalindrome(i) then
        local inBinary = tobits(i)
        if isPalindrome(inBinary) then
            print(i, inBinary)
            sum = sum + i
        end
    end
end
print(sum)

print(systemTime() - t)
