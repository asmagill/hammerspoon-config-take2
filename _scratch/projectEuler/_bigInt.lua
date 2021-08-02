-- BigInt library for use with projectEuler problems
--
-- This is a minimal implementation sufficient to answer the problems I've encountered
-- that require greater than the 64bit integers that Lua 5.4 supports.
--
-- This is neither complete nor optimized... but it works for my needs
--
-- Implemented:
--  * addition of bigInts
--  * subtraction of bigInts
--  * multiplication of bigInts
--  * comparisons: <, >, <=, >=, ==, ~=
--  * exponentiation but exponent must be non-negative integer (i.e. not a bigInt itself)
--  * unary minus
--  * (integer) division - plausibly fast, considering, but still the slowest of all operations
--  * modulus - plausibly fast, considering, but still the slowest of all operations
--
--  * bigint:eq(y)
--        shortcut for `bX == bigint(y)` since the __eq mm only triggers if *both* arguments
--        are tables (unlike __lt and __le)
--  * bigint:abs()
--  * bigint:sgn()
--        return -1 if bigint is negative, 0 if zero, and 1 if positive
--  * bigint:div(y)
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

    local ans, nAsStr = {}, tostring(n)

    if nAsStr:sub(1,1) == "-" then
        nAsStr = nAsStr:sub(2)
        ans.negative = true
    end

    -- in case they gave us a string, strip leading 0's
    while nAsStr:sub(1,1) == "0" and #nAsStr > 1 do nAsStr = nAsStr:sub(2) end

    for i = #nAsStr, 1, -1 do table.insert(ans, tonumber(nAsStr:sub(i, i))) end

    return setmetatable(ans, bigIntMT)
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

    return setmetatable(ans, bigIntMT)
end

bigIntMT.abs = function(self)
    local ans = _duplicate(self)
    ans.negative = nil
    return ans
end

bigIntMT.sgn = function(self)
    if #self == 1 and self[1] == 0 then
        return 0
    else
        return self.negative and -1 or 1
    end
end

-- figure out the maximum power of 10 we can support without overflow
-- used in div algorithm because integer addition faster than bigint addition
-- local maxP10 = 0
-- do
--     local workingOn = 1
--     while workingOn > 0 do
--         maxP10, workingOn = workingOn, workingOn * 10
--     end
-- end

-- method to return both integer quotient and remainder; can't calculate one
-- with out the other, so offer a way to get both as a time saver.
-- __(i)div and __mod use this as well
bigIntMT.div = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    if other == zeroBigInt then error("attempt to divide by zero") end
    if other < 0 then
        local Q, R = self:div(-other)
--         print("neg D", Q, R)
        if R == zeroBigInt then
            return -Q, R
        else
            return -(Q + 1), (other + R)
        end
    end
    if self < 0 then
        local Q, R = (-self):div(other)
--         print("neg N", Q, R)
        if R == zeroBigInt then
            return -Q, R
        else
            return (-Q - 1), (other - R)
        end
    end

    -- At this point, self ≥ 0 and other > 0

    local N, D = _duplicate(self), _duplicate(other)

-- going right-left (p = qd + r)
-- we can speed it up for some special cases, but it's still pig-dog slow
--
--     local preR = setmetatable({}, bigIntMT)
--     -- special case when denominator is # * power-of-10
--     while #D > 1 and #N > 1 and D[1] == 0 do
--         table.insert(preR, table.remove(N, 1))
--         table.remove(D, 1)
--     end

--     -- special case when denominator == 1
--     if #D == 1 and D[1] == 1 then
--         if #preR == 0 then preR[1] = 0 end
--         while #preR > 1 and preR[#preR] == 0 do table.remove(preR) end
--         return N, preR
--     end
--
--     local quotient, remainder = zeroBigInt, _duplicate(N)
--
--     local quotientCnt = 0
--
--     while remainder >= D do
--         quotientCnt = (quotientCnt + 1) % maxP10
--         if  quotientCnt == 0 then quotient = quotient + maxP10 end
--
--         remainder = remainder - D
--     end
--     if  quotientCnt ~= 0 then quotient = quotient + quotientCnt end

--     -- reapply factors of 10 removed above
--     while #preR > 0 do table.insert(remainder, 1, table.remove(preR)) end


-- going left-right, like long division by hand; a lot faster, *most* of the time

    local quotient = setmetatable({}, bigIntMT)
    for i = 1, #N, 1 do table.insert(quotient, 0) end

    local nSize, dSize = #N, #D

    while nSize >= dSize and N > D do
        -- get high order part of N to subtract D from
        local headN = setmetatable({}, bigIntMT)
        for i = dSize, 1, -1 do table.insert(headN, N[nSize + 1 - i]) end
        if headN < D then table.insert(headN, 1, N[nSize - dSize]) end
        -- truncate N so it no longer has its head
        for i = 1, #headN, 1 do table.remove(N) end
        -- now see how many times D goes into headN
        local digit = 0
        while headN >= D do
            digit = digit + 1
            headN = headN - D
        end
        quotient[#N + 1] = digit
        -- attach remainder of headN to N and recalc nSize
        for i = 1, #headN, 1 do table.insert(N, headN[i]) end
        while #N  > 1 and N[#N] == 0 do table.remove(N) end
        nSize = #N
    end

    local remainder = N

-- and now back to our regularly scheduled ending...

    -- prune leading 0s, just in case
    while #remainder > 1 and remainder[#remainder] == 0 do table.remove(remainder) end
    while #quotient  > 1 and quotient[#quotient]   == 0 do table.remove(quotient)  end

    return quotient, remainder
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

    local ans = {}

    if self.negative ~= other.negative then
        local selfNeg, otherNeg = self.negative, other.negative
        self.negative, other.negative = nil, nil
        if self > other then
            ans = self - other
            ans.negative = selfNeg
        elseif other > self then
            ans = other - self
            ans.negative = otherNeg
        else -- |self| == |other|
            ans = { 0 }
        end
        self.negative, other.negative = selfNeg, otherNeg
    else
        local carry = 0
        local len = math.max(#self, #other)
        for i = 1, len, 1 do
            local sub = (self[i] or 0) + (other[i] or 0) + carry
            ans[i] = sub % 10
            carry = (sub > 9) and 1 or 0
        end
        if carry == 1 then table.insert(ans, 1) end

        ans.negative = self.negative
    end

    if #ans == 1 and ans[1] == 0 then ans.negative = nil end -- we don't do negative 0
    return setmetatable(ans, bigIntMT)
end

bigIntMT.__unm = function(self)
    local ans = _duplicate(self)
    ans.negative = (not self.negative) and true or nil

    if #ans == 1 and ans[1] == 0 then ans.negative = nil end -- we don't do negative 0
    return ans
end

bigIntMT.__sub = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local ans = {}

    if self.negative ~= other.negative then
        local otherNeg = other.negative
        other.negative = not(otherNeg) and true or nil
        ans = self + other
        other.negative = otherNeg
    else
        local areNegative = self.negative -- already know that they're the same
        self.negative, other.negative = nil, nil

        local term1, term2, swapped = self, other, false
        if term2 > term1 then term1, term2, swapped = other, self, true end
        local borrow = 0
        for i = 1, #term1, 1 do
            local digit1 = term1[i] - borrow
            if digit1 < 0 then
                digit1, borrow = 10 - borrow, 1
            else
                borrow = 0
            end
            local digit = digit1 - (term2[i] or 0)
            if digit < 0 then digit, borrow = digit + 10, 1 end
            ans[i] = digit
        end

        while #ans > 1 and ans[#ans] == 0 do table.remove(ans) end
        self.negative, other.negative = areNegative, areNegative
        if #ans > 1 or ans[1] > 0 then
            if swapped then
                ans.negative = (not areNegative) and true or nil
            else
                ans.negative = areNegative
            end
        end
    end

    if #ans == 1 and ans[1] == 0 then ans.negative = nil end -- we don't do negative 0
    return setmetatable(ans, bigIntMT)
end

bigIntMT.__mul = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local termsToAdd = {}

    local term1, term2 = self, other
    if #term2 < #term1 then term1, term2 = other, self end

    for i = 1, #term1, 1 do
        local digit = term1[i]
        if digit ~= 0 then
            local interimProduct, carry = {}, 0
            -- insert initial 0's based on digit
            for j = 2, i, 1 do table.insert(interimProduct, 0) end
            -- now multiply term2 by digit
            for j = 1, #term2, 1 do
                local result = digit * term2[j] + carry
                if result < 10 then
                    table.insert(interimProduct, result)
                    carry = 0
                else
                    table.insert(interimProduct, result % 10)
                    carry = result // 10
                end
            end
            if carry ~= 0 then table.insert(interimProduct, carry) end
            table.insert(termsToAdd, setmetatable(interimProduct, bigIntMT))
        end
    end

    local ans = zeroBigInt
    for i = 1, #termsToAdd, 1 do ans = ans + termsToAdd[i] end
    if self.negative ~= other.negative then ans.negative = true end

    if #ans == 1 and ans[1] == 0 then ans.negative = nil end -- we don't do negative 0
    return ans
end

bigIntMT.__idiv = function(self, other)
    local Q, _ = bigIntMT.div(self, other)
    return Q
end

bigIntMT.__mod = function(self, other)
    local _, R = bigIntMT.div(self, other)
    return R
end

bigIntMT.__div = bigIntMT.__idiv

bigIntMT.__pow = function(self, pwr)
    assert(getmetatable(self) == bigIntMT and math.type(pwr) == "integer", "exponent must be an integer")
    assert(pwr >= 0, "exponent miust not be negative")

    local ans = bigint(1)

    for i = 1, pwr, 1 do ans = ans * self end
    return ans
end

bigIntMT.__eq = function(self, other)
-- hack to allow inspect to work
    if getmetatable(self) == bigIntMT and getmetatable(other) ~= bigIntMT and type(other) == "table" then return false end

    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    local equal, idx = (self.negative == other.negative), 1
    if equal then equal = (#self == #other) end
    while equal do
        equal = (self[idx] == other[idx])
        idx = idx + 1
        if idx > #self then break end
    end
    return equal
end

bigIntMT.__lt = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    if self.negative ~= other.negative then
        return self.negative and true or false
    end

    local answer
    if #self == #other then
        local idx = #self
        while idx > 0 and self[idx] == other[idx] do idx = idx - 1 end
        if idx == 0 then return false end -- they're equal
        answer = (self[idx] < other[idx])
    else
        answer = (#self < #other)
    end
    if self.negative then
        return not answer
    else
        return answer
    end
end

bigIntMT.__le = function(self, other)
    if getmetatable(self) ~= bigIntMT then self = newBigInt(self) end
    if getmetatable(other) ~= bigIntMT then other = newBigInt(other) end

    return (self == other) or (self < other)
end

bigIntMT.__tostring = function(self)
    local ans = ""
    for i = #self, 1, -1 do ans = ans .. tostring(self[i]) end
    if self.negative then ans = "-" .. ans end
    return ans
end



return setmetatable(module, {
    __call = function(self, ...)
        local bigInts = {}
        for _, v in ipairs({ ... }) do table.insert(bigInts, newBigInt(v)) end
        return table.unpack(bigInts)
    end,
})

