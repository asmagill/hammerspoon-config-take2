local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local dict = {
    [   1] = "one",
    [   2] = "two",
    [   3] = "three",
    [   4] = "four",
    [   5] = "five",
    [   6] = "six",
    [   7] = "seven",
    [   8] = "eight",
    [   9] = "nine",
    [  10] = "ten",
    [  11] = "eleven",
    [  12] = "twelve",
    [  13] = "thirteen",
    [  14] = "fourteen",
    [  15] = "fifteen",
    [  16] = "sixteen",
    [  17] = "seventeen",
    [  18] = "eighteen",
    [  19] = "nineteen",
    [  20] = "twenty",
    [  30] = "thirty",
    [  40] = "forty",
    [  50] = "fifty",
    [  60] = "sixty",
    [  70] = "seventy",
    [  80] = "eighty",
    [  90] = "ninety",
}

numberToString = function(n)
    if dict[n] then return dict[n] end

    assert(math.type(n) == "integer" and n > 0 and n < 10000, "only valid for integers between 1 and 9999")

    local ans = ""
    local nAsStr = tostring(n)

    if #nAsStr == 4 then
        local digit = tonumber(nAsStr:sub(1,1))
        if digit > 0 then
            ans = ans .. ((#ans > 0) and " " or "") .. dict[digit] .. " thousand"
        end
        nAsStr = nAsStr:sub(2)
    end

    if #nAsStr == 3 then
        local digit = tonumber(nAsStr:sub(1,1))
        if digit > 0 then
            ans = ans .. ((#ans > 0) and " " or "") .. dict[digit] .. " hundred"
        end
        nAsStr = nAsStr:sub(2)
    end

    local ans2 = ""
    local digits = tonumber(nAsStr)

    if digits > 0 then
        if dict[digits] then
            ans2 = dict[digits]
        else
            local ones, tens = tonumber(nAsStr:sub(2,2)), tonumber(nAsStr:sub(1,1)) * 10
            ans2 = dict[tens] .. "-" .. dict[ones]
        end
    end

    if #ans > 0 and #ans2 > 0 then
        ans = ans .. " and " .. ans2
    elseif #ans2 > 0 then
        ans = ans2
    elseif #ans > 0 then -- no-op
    else
        error(string.format("broken for %d -- ans is '%s' and '%s'", n, ans, ans2))
    end

    return ans
end

local totalstring = ""
for i = 1, 1000, 1 do
    totalstring = totalstring .. numberToString(i):gsub("[ -]", "")
end

print(#totalstring)
print(systemTime() - t)
