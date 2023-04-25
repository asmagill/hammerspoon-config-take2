-- BigInt library for use with projectEuler problems
--
-- This is a minimal implementation sufficient to answer the problems I've encountered
-- that require greater than the 64bit integers that Lua 5.4 supports.
--
-- This is neither complete nor optimized... but it works for my needs
--
-- Functions:
-- ?  __add addition of bigInts
-- +  __sub subtraction of bigInts
--    __mul multiplication of bigInts
--
--    __pow exponentiation but exponent must be non-negative integer (i.e. not a bigInt itself)
--          could we allow bigint exp by dividing by (-1 >> 1) and looping?
-- +  __unm unary minus
-- +  __idiv (integer) division
-- +  __div  (same as __idiv)
-- +  __mod modulus
--
--    bigint:div(y)
--        shortcut for `bX // y, bX % y` since both are calculated at the same time
--        __(i)div and __mod return the single value expected; if you need both, use
--        this to prevent having to calculate it twice
--
-- +  bigint:eq(y) shortcut for `bX == bigint(y)` since the __eq mm only triggers if *both* arguments are tables (unlike __lt and __le)
-- +  bigint:abs()
-- +  bigint:sgn() return -1 if bigint is negative, 0 if zero, and 1 if positive
--
-- +  __band bitwise and
-- +  __bor  bitwise or
-- +  __bxor bitwise xor
-- +  __bnot bitwise not
-- +  __shl  bitwise shift left
-- +  __shr  bitwise shift right
--
-- <, >, <=, >=, ==, ~=
-- +  __lt
-- +  __le
-- +  __eq
--
-- +  __tostring
--
-- (should probably move it into a compiled library at that point to take advantage of
-- compiler optimizations for bitwise operations if I want true speed or to formally add it
-- to Hammerspoon...)
--
--    __pairs   -- if moved to userdata in compiled library
--    __ipairs  -- if moved to userdata in compiled library

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

    -- convert base-10 to base-2 (256)
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

    -- set sign
    if not (#self == 1 and self[1] == 0) then
        table.insert(ans, 0) -- it's a positive number (so far) so set last byte to 0
    end
    if negative then ans = -ans end -- now adjust if it's negative

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

-- consolidate leading 0 or 255
local _compress = function(self)
    if #self ~= 1 then
        while #self > 2 and self[#self] == self[#self - 1] do table.remove(self) end
        if #self == 2 and self[1] == 0 then table.remove(self) end
    end
    return self
end

bigIntMT.abs = function(self)
    local ans = _duplicate(self)
    if ans < 0 then ans = -ans end
    return ans
end

bigIntMT.sgn = function(self)
    return (#self == 1) and 0 or ((self[#self] == 255) and -1 or 1)
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

    -- by extending the sequence by a copy of the sign byte, I *think* we
    -- can ignore the carry at the end, but this needs testing!!
    local a, b = _duplicate(self), _duplicate(other)
    table.insert(a, selfSign)
    table.insert(b, otherSign)

    local idx, maxIdx = 1, math.max(#a, #b)
    while idx < maxIdx do
        local tmp = (a[idx] or selfSign) + (b[idx] or otherSign) + carry
        ans[idx] = tmp % 256
        carry = (tmp // 256) >> 8
        idx = idx + 1
    end

    return _compress(ans)
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

-- bigIntMT.__mul = function(self, other)
--     if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
--     if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
--
--     local ans = setmetatable({}, bigIntMT)
--
--
-- end

-- bigIntMT.div = function(self, other)
--     if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
--     if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
--
--     if other == zeroBigInt then error("attempt to divide by zero") end
--
-- end

bigIntMT.__idiv = function(self, other)
    local Q, _ = self:div(other)
    return Q
end

bigIntMT.__mod = function(self, other)
    local _, R = self:div(other)
    return R
end

bigIntMT.__div = bigIntMT.__idiv

-- bigIntMT.__pow = function(self, pwr)
-- end
--

bigIntMT.__bnot = function(self)
    local ans = _duplicate(self)
    for i = 1, #ans, 1 do ans[i] = (~ans[i]) & 255 end
    return ans
end

bigIntMT.__band = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
    local ans = setmetatable({}, bigIntMT)

    for i = 1, math.max(#self, #other), 1 do
        ans[i] = (self[i] or self[#self]) & (other[i] or other[#other])
    end
    return _compress(ans)
end

bigIntMT.__bor = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
    local ans = setmetatable({}, bigIntMT)

    for i = 1, math.max(#self, #other), 1 do
        ans[i] = (self[i] or self[#self]) | (other[i] or other[#other])
    end
    return _compress(ans)
end

bigIntMT.__bxor = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end
    local ans = setmetatable({}, bigIntMT)

    for i = 1, math.max(#self, #other), 1 do
        ans[i] = (self[i] or self[#self]) ~ (other[i] or other[#other])
    end
    return _compress(ans)
end

bigIntMT.__shl = function(self, shift)
    assert(getmetatable(self) == bigIntMT and math.type(shift) == "integer", "shift must be an integer")
    if shift < 0 then return self >> (-shift) end
    if #self == 1 and self[1] == 0 then return _duplicate(zeroBigInt) end
    local ans, isNegative = self:abs(), (self < 0)

    for i = 1, shft, 1 do
        local idx, carry = 1, 0
        while idx < #ans do
            local tmp = (ans[idx] << 1) + carry
            ans[idx] = tmp % 256
            carry = (tmp // 256) >> 8
            idx = idx + 1
        end

        if carry == 1 then table.insert(ans, #ans, carry) end
    end
    return _compress(isNegative and -ans or ans)
end

bigIntMT.__shr = function(self, shift)
    assert(getmetatable(self) == bigIntMT and math.type(shift) == "integer", "shift must be an integer")
    if shift < 0 then return self << (-shift) end
    if #self == 1 and self[1] == 0 then return _duplicate(zeroBigInt) end
    local ans, isNegative = self:abs(), (self < 0)

    for i = 1, shft, 1 do
        local idx, carry = #ans - 1, 0
        while idx > 0 do
            local tmp = (ans[idx] >> 1) + carry
            carry = (ans[idx] & 1 == 1) and 255 or 0
            ans[idx] = tmp
            idx = idx - 1
        end
        -- shift right drops bits that shift below 0
    end
    return _compress(isNegative and -ans or ans)
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

-- https://en.wikipedia.org/wiki/Two's_complement#Comparison_(ordering)
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

-- see https://stackoverflow.com/a/36665483
local chunker = math.tointeger(10 ^ math.floor(math.log(-1 >> 1, 10))) --  max power of 10 that lua represents as int
-- local chunker = 1000000000 -- 1000000000 based on example in above link
local numZeros = math.floor(math.log(chunker, 10)) -- number of zeros in chunker

bigIntMT.__tostring = function(self)
    if #self == 1 and self[1] == 0 then return "0" end
    local negative = (self[#self] == 255)
    local num = self:abs()
    local ans = ""

    repeat
        num, current = num:div(chunker)
        current = tointeger(tostring(current)) -- we know current will be representable as int
        for i = 0, numZeros - 1, 1 do
            ans = tostring(current % 10) .. ans
            current = current // 10
            if current == 0 and num == 0 then break end
        end
    until num == 0

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

