local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local bigint = require("_scratch.projectEuler._bigint")

local memoFib = { [0] = bigint(0), bigint(1) }
fibonacci = function(n)
    local qty = #memoFib
    while n > qty do
        table.insert(memoFib, memoFib[qty] + memoFib[qty - 1])
        qty = qty + 1
    end
    return memoFib[n]
end

local index = 0
repeat
    index = index + 1
    num = fibonacci(index)
until #num >= 1000

print(index, num)
print(systemTime() - t)
