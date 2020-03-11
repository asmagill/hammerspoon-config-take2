--
-- Extremely crude and simple profiler for Hammerspoon
--
-- Uses debug.sethook, so just the fact you're using this will slow things down
--
-- Probably gets some skew from our own function calls, (if you invoke dump before
--     stop, or from coroutine wrappers), but since _profiler *is* the hook, and it checks
--     debuginfo 2 up on stack, it should be minimal in most cases.
--
-- Only captures internals of coroutines created *after* `start` called
--      function which uses coroutines records full time from entry to end (i.e. even
--          though execution yielded to allow other stuff, the initiating function didn't
--          "return" until the final resume)
--      Total for `resume` + `yield` functions will be (effectively) the same as the sum
--          of functions which use coroutines.
--

--
-- Found after I started this, but should look at https://github.com/geoffleyland/luatrace
-- supports LuaJit/5.1 so not certain if it will work with 5.3 as is, but lists LuaJit as
-- optional, and it appears to be able to detect coroutine threads without requiring wrapping
-- the coroutine constructors
--

local module = {}

local calls, total, this = {}, {}, {}

local _otherHook = {} -- in case they have another debug hook, lets be nice and return it when we're done
local _coroutine_create
local _coroutine_wrap

local _previousFunc

local _profiler = function(event)
    local i = debug.getinfo(2, "Sln")
    local func = i.source .. ":" .. i.linedefined .. " (" .. (i.name or "???") .. ")"
    if event == 'call' then
        this[func] = os.clock()
        _previousFunc = func
    elseif event == 'tail call' then
        if _previousFunc then
            local time = os.clock() - this[_previousFunc]
            total[_previousFunc] = (total[_previousFunc] or 0) + time
            calls[_previousFunc] = (calls[_previousFunc] or 0) + 1
        end
        this[func] = os.clock()
        _previousFunc = func
    else
        if this[func] then
            local time = os.clock() - this[func]
            total[func] = (total[func] or 0) + time
            calls[func] = (calls[func] or 0) + 1
-- testing shows this to only be the returns from invoking our start, so ignoring for now
--         else
--             print(event, func, finspect(i))
        end
        _previousFunc = nil
    end
end

module.clear = function()
    calls, total, this = {}, {}, {}
end

module.start = function()
    local f, m, c = debug.gethook()
    if f ~= _profiler then
        _otherHook = { f, m, c }
        debug.sethook(_profiler, "cr")
        _coroutine_create = coroutine.create
        coroutine.create = function(f)
            local t = _coroutine_create(f)
            debug.sethook(t, _profiler, "cr")
            return t
        end
        _coroutine_wrap = coroutine.wrap
        coroutine.wrap = function(f)
            return _coroutine_wrap(function(...)
                debug.sethook(_profiler, "cr")
                return f(...)
            end)
        end
    end
end

module.stop = function()
    local f, m, c = debug.gethook()
    if f == _profiler then
        if #_otherHook > 0 then
            debug.sethook(_otherHook[1], _otherHook[2], _otherHook[3])
            _otherHook = {}
        else
            debug.sethook(nil, "")
        end
        if _coroutine_create then
            coroutine.create = _coroutine_create
            _coroutine_create = nil
        end
        if _coroutine_wrap then
            coroutine.wrap = _coroutine_wrap
            _coroutine_wrap = nil
        end
    end
end

module.dump = function()
    local tSz, cSz = 0, 0
    local funcs = {}

    for f,time in pairs(total) do
        tSz = math.max(tSz, #tostring(string.format("%.3f", time)))
        cSz = math.max(cSz, #tostring(calls[f]))
        table.insert(funcs, f)
    end
    table.sort(funcs, function(a,b) return total[a] > total[b] end)

    local fmtString = "%" .. tostring(tSz) .. ".3fs for %" .. tostring(cSz) .. "d calls :: %s"
    for i,v in ipairs(funcs) do
      hs.printf(fmtString, total[v], calls[v], v)
    end
end

return module
