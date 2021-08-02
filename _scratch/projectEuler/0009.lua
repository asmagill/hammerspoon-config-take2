local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- faster then my first solution (≈ 12 seconds; starting all three loops at 1
-- was 35+) but longer than I'd like... still, it solved the problem

local stop = false
for a = 1, 1000, 1 do
    for b = a, 1000, 1 do
        for c = b, 1000, 1 do
            local sum = a + b + c
            if sum == 1000 then
                if (a ^ 2) + (b ^ 2) == (c ^ 2) then
                    print(a, b, c, a * b * c)
                    stop = true
                    break
                end
            elseif sum > 1000 then
                break
            end
        end
        if stop then break end
    end
    if stop then break end
end

print(systemTime() - t)
