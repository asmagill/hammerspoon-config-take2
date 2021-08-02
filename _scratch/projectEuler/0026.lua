local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

--
-- Over an hour, but at least my bigint library now does a *passable* division...
--
-- bigint = require("_scratch.projectEuler._bigint")
--
-- findRepeatingDecimalForUnitFractionOf = function(d)
--     if d == 1 then return nil end
--
--     local mods, pwr, ans = {}, bigint(1), nil
--     local dB = bigint(d)
--
--     while true do
--         local div, mod = pwr:div(dB)
--         local found = false
--         for i = 1, #mods, 1 do
--             if mod == mods[i] then
--                 found = true
--                 local temp = tostring(div)
--                 while #temp < #mods do temp = "0" .. temp end
--                 ans = temp:sub(i)
--                 if ans == "0" then
--                     ans = nil
--                 end
--                 break
--             end
--         end
--         if found then
--             break
--         else
--             table.insert(mods, mod)
--         end
--         pwr = pwr * 10
--     end
--
--     return ans
-- end
--
-- local maxLength, maxD, maxSequence = 0, 0, ""
--
-- for d = 2, 999, 1 do
--     local ans = findRepeatingDecimalForUnitFractionOf(d)
--     coroutine.applicationYield()
--     if ans then
-- --         print(string.format("1/%d pattern: %s", d, ans))
--         local ml = #ans
--         if ml > maxLength then
--             maxLength, maxD, maxSequence = ml, d, ans
--         end
--     end
-- end
--
-- print(maxLength, maxD, maxSequence)

lengthOfRepeatingDecimalFor = function(a, b)
    -- take absolute value so this can work for any fraction, even
    -- ones with negative numerators or denominators
    a, b = math.abs(a), math.abs(b)

    -- multiply fraction by 10 to get next decimal as integer
    -- mod by denominator to get next numerator
    --
    --           a                 (10a % b)
    -- e.g.   10 -  = floor(10a) + ---------
    --           b                     b
    --
    -- when fractional numerator equals a numerator we've already seen,
    -- the repeating has ended.
    --
    -- if fractional numerator reaches 0, then it doesn't repeat

    -- https://en.wikipedia.org/wiki/Repeating_decimal could probably suggest some
    -- other approaches, but this is fast enough for the problem

    local numerators, idx = { a }, 0

    repeat
        a = (a * 10) % b
        for i, v in ipairs(numerators) do
            if v == a then
                idx = i
                break
            end
        end
        if idx == 0 then
            table.insert(numerators, a)
        else
            break
        end
    until a == 0

    return (a == 0) and 0 or (#numerators + 1 - idx)
end

local maxLength, maxD = 0, 0

for d = 2, 999, 1 do
    local length = lengthOfRepeatingDecimalFor(1, d)
    if length > maxLength then
        maxLength, maxD = length, d
    end
end

print(maxLength, maxD)

print(systemTime() - t)
