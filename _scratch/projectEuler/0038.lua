local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local isPanDigital = function(num)
    num = tostring(num)
    return (#num == 9) and
           num:match("1") and
           num:match("2") and
           num:match("3") and
           num:match("4") and
           num:match("5") and
           num:match("6") and
           num:match("7") and
           num:match("8") and
           num:match("9")
end

-- find max N for n .. 2n as our upper bound

local maxN = 0
repeat
    maxN = maxN + 1
    local tN = 2 * maxN
    local ans = (maxN * 10 ^ (math.floor(math.log(tN, 10)) + 1)) + tN
until math.floor(math.log(ans, 10)) > 8
print(systemTime() - t, maxN)

local n = maxN
local answers = {}

repeat
    local i, working, ans = 2, n, 0
    while (n > 1) and (i < 10) and (working < 1000000000) do
        ans = working
        local temp = i * n
        working = (ans * 10 ^ (math.floor(math.log(temp, 10)) + 1 )) + temp
        i = i + 1
    end
    ans = math.tointeger(ans)
--     print(n, i - 1, ans)
    if isPanDigital(ans) then table.insert(answers, ans) end

    n = n - 1
until n == 0

table.sort(answers)
print(answers[#answers])
print(systemTime() - t)

