local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local idx = { 1, 10, 100, 1000, 10000, 100000, 1000000 }
local d = {}

local curInt = 0
local curLen = 0

local i = 1


while i <= #idx do
    local curIntAsString = tostring(curInt)
    if curLen >= idx[i] then
        local s = curLen - idx[i] + 1
        d[i] = math.tointeger(curIntAsString:sub(s,s))
        i = i + 1
    end
    curInt = curInt + 1
    curLen = curLen + #curIntAsString
end

local ans = 1
for i = 1, #d, 1 do ans = ans * d[i] end
print(ans)
print(systemTime() - t)
