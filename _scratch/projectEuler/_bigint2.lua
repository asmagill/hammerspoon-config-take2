-- BigInt library for use with projectEuler problems
--
-- This is a minimal implementation sufficient to answer the problems I've encountered
-- that require greater than the 64bit integers that Lua 5.4 supports.
--
-- This is neither complete nor optimized... but it works for my needs
--
-- Implemented:
--    addition of bigInts
--    subtraction of bigInts
--    multiplication of bigInts
--    comparisons: <, >, <=, >=, ==, ~=
--    exponentiation but exponent must be non-negative integer (i.e. not a bigInt itself)
--    unary minus
--    (integer) division - plausibly fast, considering, but still the slowest of all operations
--    modulus - plausibly fast, considering, but still the slowest of all operations
--
--    bigint:eq(y)
--        shortcut for `bX == bigint(y)` since the __eq mm only triggers if *both* arguments
--        are tables (unlike __lt and __le)
--    bigint:abs()
--    bigint:sgn()
--        return -1 if bigint is negative, 0 if zero, and 1 if positive
--  ? bigint:div(y)
--        shortcut for `bX // y, bX % y` since both are calculated at the same time
--        __(i)div and __mod return the single value expected; if you need both, use
--        this to prevent having to calculate it twice
--
-- I suspect I'll need to move to an array of 64bit ints that adds more as necessary
-- and represent numbers in binary to speed it up much faster and/or implement the
-- following...
--
--    bitwise and, or, xor, not
--    shift left, right
--
-- (and should probably move it into a compiled library at that point to take advantage of
-- compiler optimizations for bitwise operations if I want true speed or to formally add it
-- to Hammerspoon...)

local module = {}

local bigIntMT = { __name = "bigInt" }
bigIntMT.__index = bigIntMT

module.new = function(n)
    assert(type(n) == "string" or math.type(n) == "integer", string.format("expected string or integer; found %s (%s)", type(n), tostring(n)))

    if type(n) == "string" then
        for i = ((n:sub(1,1) == "-") and 2 or 1), #n, 1 do
            assert(tonumber(n:sub(i,i)), "string must contain only integers")
        end
    end

    local ans, nAsStr = setmetatable({}, bigIntMT), tostring(n)
    local negative = false

    if nAsStr:sub(1,1) == "-" then
        nAsStr = nAsStr:sub(2)
        negative = true
    end

    -- in case they gave us a string, strip leading 0's
    while nAsStr:sub(1,1) == "0" and #nAsStr > 1 do nAsStr = nAsStr:sub(2) end

    local byte, digit = 0, "0"
    repeat
        digit, nAsStr = nAsStr:sub(-1), nAsStr:sub(1, -2)
        byte = byte * 10 + tonumber(digit)
        if byte > 255 then
            table.insert(ans, byte % 256)
            byte = byte // 256
        end
    until nAsStr == ""
    if byte ~= 0 then table.insert(ans, byte) end

    if negative then ans = -ans end
    return ans
end

module.zero = module.new(0)

-- shorthand used within this file
local newBigInt  = module.new
local zeroBigInt = module.zero

-- in case it gets more complicated later, all duplication is done in one place
local _duplicate = function(n)
    local ans = {}

    local key, value = next(n)
    while key do
        ans[key] = value
        key, value = next(n, key)
    end

    return setmetatable(ans, getmetatable(n))
end

bigIntMT.abs = function(self)
    local ans = _duplicate(self)
    if ans < 0 then ans = -ans end
    return ans
end

bigIntMT.sgn = function(self)
    if #self == 1 and self[1] == 0 then
        return 0
    else
        return (self[#self] == 255) and -1 or 1
    end
end

-- Shorthand when comparing to non-bigint "number"
--   useful because == and ~= (unlike <, >, <=, and =>) won't call metamethod
--   unless *both* arguments are tables (or ud)... dumb, imho
bigIntMT.eq = function(self, other)
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
    return self == other
end

bigIntMT.__add = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local ans, carry = setmetatable({}, bigIntMT), 0
    local selfSign, otherSign = self[#self], other[#other]

    for i = 1, math.max(#self, #other), 1 do
        local a, b = self[i], other[i]
        if not a then a = selfSign end
        if not b then b = otherSign end
        local c = a + b + carry
        c, carry = c % 256, c // 256
        table.insert(ans, c)
    end
-- I think we throw away the carry, but need to test
--     if carry ~= 0 then table.insert(ans, 255) end

-- wrong for negative if high bytes are 255... I think we actually need to track number of
-- bytes that are "in use"
    while #ans > 2 and ans[#ans] == 255 and ans[#ans] == ans[#ans -1] do
        table.remove(ans)
    end
    while #ans > 2 and ans[#ans] == 0 and ans[#ans] == ans[#ans -1] do
        table.remove(ans)
    end

    if #ans == 2 and ans[1] == 0 and ans[2] == 0 then table.remove(ans) end

    return ans
end

bigIntMT.__bnot = function(self)
    local ans = _duplicate(self)
    for i = 1, #ans, 1 do ans[i] = (~ans[i]) & 255 end
    return ans
end

-- bigIntMT.__band = function(self, other)
--     if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
--     if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
-- end
--
-- bigIntMT.__bor = function(self, other)
--     if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
--     if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
-- end
--
-- bigIntMT.__bxor = function(self, other)
--     if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
--     if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
-- end

bigIntMT.__shl = function(self, shift)
    assert(getmetatable(self) == bigIntMT and math.type(shift) == "integer", "shift must be an integer")
    if shift < 0 then return self >> (-shift) end

    if #ans == 1 and ans[1] == 0 then
        return zeroBigInt
    end

    local ans = _duplicate(self)
    local idx, carry = 0, 0
    for i = 1, shft, 1 do
        while idx < #ans do
            idx = idx + 1
            local tmp = (ans[idx] << 1) + carry
            ans[idx] = tmp % 256
            carry = tmp // 256
        end
-- wrong when negative
        if carry == 1 then table.insert(ans, carry) end
    end
    return ans
end

bigIntMT.__shr = function(self, shift)
    assert(getmetatable(self) == bigIntMT and math.type(shift) == "integer", "shift must be an integer")
    if shift < 0 then return self << (-shift) end

    if #ans == 1 and ans[1] == 0 then
        return zeroBigInt
    end


end

bigIntMT.__unm = function(self)
    local ans = _duplicate(self)

    if not (#ans == 1 and ans[1] == 0) then
        ans = (~ans) + 1
    end
    return ans
end

bigIntMT.__sub = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    return self + (-other)
end

bigIntMT.__mul = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local ans = setmetatable({}, bigIntMT)


end

bigIntMT.__idiv = function(self, other)
end

bigIntMT.__mod = function(self, other)
end

bigIntMT.__div = bigIntMT.__idiv

bigIntMT.__pow = function(self, pwr)
end

bigIntMT.__eq = function(self, other)
-- hack to allow inspect to work
    if getmetatable(self) == bigIntMT and getmetatable(other) ~= bigIntMT and type(other) == "table" then return false end

    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local ans, idx = (#self == #other), 0
    while ans and idx < #self do
        idx = idx + 1
        ans = (self[idx] == other[idx])
    end

    return ans
end

bigIntMT.__lt = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local selfSign, optherSign = self[#self], other[#other]
    if selfSign == 0 and otherSign == 255 then
        return false
    elseif selfSign == 255 and otherSign == 0 then
        return true
    end

    for i = math.max(#self, #other) - 1, 1, -1 do
        local s, o = self[i] or selfSign, other[i] or otherSign
        for j = 7, 0, -1 do
            local sb, ob = (s >> j) & 1, (o >> j) & 1
            if sb == 0 and ob == 1 then
                return true
            elseif sb == 1 and ob == 0 then
                return false
            end
        end
    end

    return false
end

bigIntMT.__le = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    return (self == other) or (self < other)
end

bigIntMT.__tostring = function(self)
    if #self == 1 and self[1] == 0 then return "0" end
    local negative = (self[#self] == 255)
    local tmp = negative and -self or _duplicate(self)
    local ans = ""



    if negative then ans = "-" .. ans end
    return ans
end



return setmetatable(module, {
    __call = function(self, ...)
        local bigInts = {}
        for _, v in ipairs({ ... }) do table.insert(bigInts, newBigInt(v)) end
        return table.unpack(bigInts)
    end,
})

