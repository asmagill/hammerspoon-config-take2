local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- find sizes that *could* contain all nine digits in m * n = p form

-- local patterns = {}
--
-- for mDigits = 1, 9, 1 do
--     for nDigits = 1, 9, 1 do
--       local pDigits = mDigits + nDigits - 1 -- the smallest it could be
--       local totalDigits = mDigits + nDigits + pDigits
--       if totalDigits == 9 or totalDigits == 8 then
--           table.insert(patterns, { mDigits, nDigits })
--       end
--     end
-- end
--
-- print(inspect(patterns))

-- possible # of digits for multiplicand and multiplier are
-- { 1, 4 }, { 2, 3 }, { 3, 2}, and { 4. 1 }
-- We only need to check the first two since the others would just duplicate results

local check = function(asString)
    local answer = not (asString:match("0"))
    if answer then
        for i = 1, 9, 1 do
            local count = 0
            for c in asString:gmatch(tostring(i)) do count = count + 1 end
            answer = (count == 1)
            if not answer then break end
        end
    end
    return answer
end
--
-- local products = {}
--
-- for _,v in ipairs(patterns) do
local products = {}

for a = 1, 9, 1 do
    for b = 1, 9, 1 do
        if b ~= a then
            for c = 1, 9, 1 do
                if c ~= a and c ~= b then
                    for d = 1, 9, 1 do
                        if d ~= a and d ~= b and d ~= c then
                            for e = 1, 9, 1 do
                                if e ~= a and e ~= b and e ~= c and e ~= d then
                                    -- 1, 4
                                    local multiplicand = a
                                    local multiplier = b + c * 10 + d * 100 + e * 1000
                                    local product = multiplicand * multiplier
                                    local asString = string.format("%d x %d = %d", multiplicand, multiplier, product)
                                    if check(asString) then
--                                         print(asString)
                                        products[product] = true
                                    end

                                    -- 2, 3
                                    multiplicand = a + b * 10
                                    multiplier = c + d * 10 + e * 100
                                    product = multiplicand * multiplier
                                    asString = string.format("%d x %d = %d", multiplicand, multiplier, product)
                                    if check(asString) then
--                                         print(asString)
                                        products[product] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local sum = 0
for k, _ in pairs(products) do sum = sum + k end

print(sum)
print(systemTime() - t)

