local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

collatzSequence = function(n)
    local ans = { n }

    while n ~= 1 do
        if n % 2 == 0 then
            n = n // 2
        else
            n = 3 * n + 1
        end
        table.insert(ans, n)
    end

    local seqStr = inspect(ans)
    return setmetatable(ans, { __tostring = function(_) return seqStr end })
end

-- memoization speeds the problem from 60 seconds to 10
local CSSRecord = {}
collatzSequenceSize = function(N)
    if CSSRecord[N] then return CSSRecord[N] end

    local n = N
    local size = 1

    while n ~= 1 do
        if n % 2 == 0 then
            n = n // 2
        else
            n = 3 * n + 1
        end

        if CSSRecord[n] then
            size = size + CSSRecord[n]
            break
        else
            size = size + 1
        end
    end

    CSSRecord[N] = size
    return size
end

local max, maxN = 0, 0

for i = 1, 999999, 1 do
    local size = collatzSequenceSize(i)
    if size > max then max, maxN = size, i end
end

print(max, maxN)

print(systemTime() - t)

print(collatzSequence(maxN))
