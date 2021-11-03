local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local numProd, denProd = 1, 1

for a = 1, 9, 1 do
    for b = 1, 9, 1 do
        for c = 1, 9, 1 do
            local num = a * 10 + b
            local den = b * 10 + c
            local ans = num / den
            if ans < 1 and ans == a / c then
                numProd, denProd = numProd * a, denProd * c
                print(string.format("%d / %d", num, den))
            end
        end
    end
end

print("-------")
print(string.format("%d / %d", numProd, denProd))
print(string.format("%7d", denProd / numProd))

print(systemTime() - t)
