local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- approx 30 seconds, give or take...
--
-- local count = 1 -- start at 1 for the 2£ coin
-- local target = 200
--
-- -- 1p, 2p, 5p, 10p, 20p, 50p, £1
--
-- for a = 0, 2, 1 do                            --  1£
--     for b = 0, 4, 1 do                        -- 50p
--         for c = 0, 10, 1 do                   -- 20p
--             for d = 0, 20, 1 do               -- 10p
--                 for e = 0, 40, 1 do           --  5p
--                     for f = 0, 100, 1 do      --  2p
--                         for g = 0, 200, 1 do  --  1p
--                             local current = a * 100 + b * 50 + c * 20 + d * 10 + e * 5 + f * 2 + g
--                             if current == target then
-- --                                 print(a, b, c, d, e, f, g)
--                                 count = count + 1
--                                 break
--                             elseif current > target then
--                                 break
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- end
--
-- print(count)

-- Recursion, working backwards from target
-- Could probably speed up by removing recursion, but it's already < 1s
local coinValues = { 200, 100, 50, 20, 10, 5, 2, 1 }
local target     = 200
local count      = 0

local findpossible
findpossible = function(money, maxCoinPosition)
    maxCoinPosition = maxCoinPosition or 1
    local sum = 0
    if maxCoinPosition == 8 then return 1 end -- for 1p only, there is only 1 solution -- all are 200p
    for i = maxCoinPosition, 8, 1 do
--         print(money, i, coinValues[i])
        local remainder = money - coinValues[i]
        if remainder == 0 then
            sum = sum + 1
        elseif remainder > 0 then -- we still need more coins...
            sum = sum + findpossible(remainder, i) -- find solutions for remainder
        end
    end
    return sum
end

print(findpossible(target))

print(systemTime() - t)
