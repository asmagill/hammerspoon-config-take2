local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local maxN = 1000
local answers = {}
for i = 1, 1000, 1 do answers[i] = {} end

for a = 1, maxN, 1 do
    for b = 1, maxN, 1 do
        local c = math.tointeger(math.sqrt(a ^ 2 + b ^ 2))
        if c then
            local p = a + b + c
            if p <= 1000 then
                table.insert(answers[p], { a, b, c })
            end
        end
    end
end

table.sort(answers, function(a, b) return #a < #b end)

local ans = answers[#answers][1]
print(ans[1] + ans[2] + ans[3])
print(systemTime() - t)
