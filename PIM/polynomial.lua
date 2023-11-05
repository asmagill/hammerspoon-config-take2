--- === Polynomial ===
---
--- A class representing a polynomial as a list of coefficients with no
--- trailing zeros.
---
--- A degree zero polynomial corresponds to the empty list of coefficients,
--- and is provided by this module as the variable ZERO.
---
--- Polynomials override the basic arithmetic operations.
---
--- Based primarily on python library written for _A_Programmer's_Introduction_to_Mathematics_, located at https://github.com/pim-book/programmers-introduction-to-mathematics/blob/master/secret_sharing/polynomial.py rewritten for use with Lua.
---
--- Differences between this and the Python implementation:
---  * the zero polynomial's string representation is "0" rather than an empty string
---  * factors with a 0 coefficient are suppressed in the string representation

local module = {}

--- Polynomial.literal
--- Variable
--- Boolean specifying whether or not string representations should match the original library exactly or not.
---
--- Notes:
---  * Default false
---  * See top-level notes for the differences between the two libraries; to match the original Python library, set this variable to true.
module.literal = false

local _internals = setmetatable({}, { __mode = "k" })

local _MT_polynomial = {}
_MT_polynomial.__eq = function(self, other)
    local result = (#self == #other)
    if result then
        local count = #self
        for i = 1, count, 1 do
            result = (self[i] == other[i])
            if not result then break end
        end
    end
    return result
end

_MT_polynomial.__add = function(self, other)
    local coefficients = {}
    local count = math.max(#self, #other)
    for i = 1, count, 1 do
        table.insert(coefficients, (self[i] or 0) + (other[i] or 0))
    end
    return module.new(coefficients)
end

_MT_polynomial.__unm = function(self)
    local coefficients = {}
    local count = #self
    for i = 1, count, 1 do
        table.insert(coefficients, -self[i])
    end
    return module.new(coefficients)
end

_MT_polynomial.__sub = function(self, other)
    return self + (-other)
end

_MT_polynomial.__mul = function(self, other)
    local coefficients = {}
    for i = 1, (#self + #other - 1), 1 do coefficients[i] = 0 end

    for i, a in ipairs(self) do
        for j, b in ipairs(other) do
            coefficients[i + j - 1] = coefficients[i + j - 1] + a * b
        end
    end

    return module.new(coefficients)
end

_MT_polynomial.__tostring = function(self)
    local result = {}
    for i,v in ipairs(_internals[self].coefficients) do
        if module.literal or v ~= 0 then
            table.insert(result, tostring(v) .. ((i > 1) and " " .. _internals[self].indeterminate .. "^" .. tostring(i - 1) or ""))
        end
    end
    result = table.concat(result, " + ")
    if not module.literal and (result == "") then result = "0" end
    return result
end

_MT_polynomial.__len = function(self)
    return #_internals[self].coefficients
end

_MT_polynomial.__index = function(self, key)
    if _MT_polynomial[key] then
        return _MT_polynomial[key]
    elseif math.type(key) == "integer" then
        return _internals[self].coefficients[key]
    else
        return nil
    end
end

--- Polynomial:evaluate_at(x) -> number
--- Method
--- Evaluate a polynomial at an input point.
---
--- Parameters:
---  * `x` - a number specifying the point at which to evaluate the polynomial
---
--- Returns:
---  * a number specifying the value of the polynomial evaluated for the number specified.
---
--- Notes:
---  * Uses Horner's method, first discovered by Persian mathematician Sharaf al-Dīn al-Ṭūsī, which evaluates a polynomial by minimizing the number of multiplications. (see https://en.wikipedia.org/wiki/Horner's_method)
---
---  * The polynomial object has a __call metamethod that invokes this method.
---    * e.g. `polynomialObject(x)` is equivalent to `polynomialObject:evaluate_at(x)`.
_MT_polynomial.evaluate_at = function(self, x)
    local theSum = 0
    for i = #self, 1, -1 do
        theSum = theSum * x + self[i]
    end
    return theSum
end

_MT_polynomial.__call = _MT_polynomial.evaluate_at

--- Polynomial.new({n, ...}) -> PolynomialObject
--- Constructor
--- Create a new polynomial.
---
--- Parameters:
---  * a table containing 0 or more numbers specifying the coefficients of the polynomial.
---
--- Returns:
---  * a polynomial object
---
--- Notes:
---  * The caller must provide a list of all coefficients of the polynomial, even those that are zero.
---    * e.g. Polynomial.new({ 0, 1, 0, 2 }) corresponds to f(x) = x + 2x^3.
---  * This module has a __call metamethod that invokes this function to construct a new polynomial object.
---    * e.g. Polynomial({ 1,2,3 }) is equivalent to Polynomial.new({ 1,2,3 })
module.new = function(...)
    local coefficients = table.pack(...)
    if type(coefficients[1]) == "table" then coefficients = coefficients[1] end

    for i = #coefficients, 1, -1 do
        if coefficients[i] == 0 then
            table.remove(coefficients)
        else
            break
        end
    end
    local newPolynomial = {}
    _internals[newPolynomial] = {
        coefficients  = coefficients,
        indeterminate = "x",
    }
    return setmetatable(newPolynomial, _MT_polynomial)
end

module.ZERO = module.new({})

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end
})
