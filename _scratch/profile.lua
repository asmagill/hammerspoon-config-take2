--
-- Extremely crude and simple profiler for Hammerspoon
--
-- Uses debug.sethook, so just the fact you're using this will slow things down some
--
-- Previous version didn't handle tail calls properly; this one should do better
--
-- By default, dump only displays lua function calls. Add `true` as argument to see
-- C function calls as well.
--
-- Decimal precision in dump report can be changed by setting `module.prec` and then
-- (re)running dump function.
--
-- To minimize confusion from other things Hammerspoon may be doing while trying to
-- identify specific functions that are slow, the best way to use this is probably
-- something like this:
--
--      profile = require("profile") -- assuming you save this in ~/.hammerspoon
--
--      profile.start()
--      ... invoke the code you want to profile
--      profile.stop()
--
-- If done as a block (in a file, function, or as one multi-line entry in the console),
-- this *should* prevent any timers or other Hammerspoon activity from being included
-- in the report. To clear the data for another profile run, do profile.clear() before
-- the next start.


-- I think I've caught all of these now
--     Probably gets some skew from our own function calls, (if you invoke dump before
--         stop, or from coroutine wrappers), but since _profiler *is* the hook, and it checks
--         debuginfo 2 up on stack, it should be minimal in most cases.
--

-- To clarify, this wraps the lua builtin coroutine library functions (which have always
-- been available in Hammerspoon, just unused by anyone) and does *not* require the
-- experimental coroutine friendly branch of Hammerspoon.
--
--         Only captures internals of coroutines created *after* `start` called
--              function which uses coroutines records full time from entry to end (i.e. even
--                  though execution yielded to allow other stuff, the initiating function didn't
--                  "return" until the final resume)
--              Total for `resume` + `yield` functions will be (effectively) the same as the sum
--                  of functions which use coroutines.
--

--
-- Found after I started this, but should look at https://github.com/geoffleyland/luatrace
-- supports LuaJit/5.1 so not certain if it will work with 5.3 as is, but lists LuaJit as
-- optional, and it appears to be able to detect coroutine threads without requiring wrapping
-- the coroutine constructors
--

local module = {}

local details = {}

-- normally I think this kind of optimization is overkill on modern machines, but since
-- we are attempting to profile with minimally impacting the actual run time...

local debug_getinfo = debug.getinfo
local debug_gethook = debug.gethook
local debug_sethook = debug.sethook
local table_insert  = table.insert
local table_remove  = table.remove
local table_sort    = table.sort
local os_clock      = os.clock
local math_max      = math.max
local string_format = string.format
local hs_printf     = hs.printf

local _callStack = {}
local _ourPath = debug_getinfo(1, "S").source

local _otherHook = {} -- in case they have another debug hook, lets be nice and return it when we're done
local _coroutine_create
local _coroutine_wrap

local _inProfiler = false

local _profiler = function(event)
    if _inProfiler then return end
    local i = debug_getinfo(2, "Sln")
    if i.source == _ourPath then return end -- don't include (lua) stuff from the profiler itself

    local func = i.source .. ":" .. i.linedefined .. " (" .. (i.name or "???") .. ")"
    details[func] = details[func] or {
        total  = 0,
        calls  = 0,
        line   = i.linedefined,
        source = i.source,
        name   = i.name or "????",
    }
    if event == 'call' then
        table_insert(_callStack, func)
        details[func].curr = os_clock()
    elseif event == 'tail call' then
        if #_callStack > 0 then
            local _prev = table_remove(_callStack)
            local time = os_clock() - details[_prev].curr
            details[_prev].total = details[_prev].total + time
            details[_prev].calls = details[_prev].calls + 1
        end
        table_insert(_callStack, func)
        details[func].curr  = os_clock()
    else -- event == "return"
        table_remove(_callStack)
        if details[func].curr then
            local time = os_clock() - details[func].curr
            details[func].total = details[func].total + time
            details[func].calls = details[func].calls + 1
        else
            -- don't keep record for a return without a corresponding call -- it's
            -- probably from the profiler starting
            details[func] = nil
        end
    end
end

module.clear = function()
    _inProfiler = true
    details = {}
    _inProfiler = false
end

module.start = function()
    _inProfiler = true
    local f, m, c = debug_gethook()
    if f ~= _profiler then
        _otherHook = { f, m, c }
        _callStack = {}
        debug_sethook(_profiler, "cr")
        _coroutine_create = coroutine.create
        coroutine.create = function(f)
            local t = _coroutine_create(f)
            debug_sethook(t, _profiler, "cr")
            return t
        end
        _coroutine_wrap = coroutine.wrap
        coroutine.wrap = function(f)
            return _coroutine_wrap(function(...)
                debug_sethook(_profiler, "cr")
                return f(...)
            end)
        end
    end
    _inProfiler = false
end

module.stop = function()
    _inProfiler = true
    local f, m, c = debug_gethook()
    if f == _profiler then
        if #_otherHook > 0 then
            debug_sethook(_otherHook[1], _otherHook[2], _otherHook[3])
            _otherHook = {}
        else
            debug_sethook(nil, "")
        end
        if _coroutine_create then
            coroutine.create = _coroutine_create
            _coroutine_create = nil
        end
        if _coroutine_wrap then
            coroutine.wrap = _coroutine_wrap
            _coroutine_wrap = nil
        end

        -- remove dangling entries, probably from the profiler itself
        for k,v in pairs(details) do if v.calls == 0 then details[k] = nil end end
    end
    _inProfiler = false
end

module.prec = 4

module.dump = function(includeC)
    _inProfiler = true
    local tSz, cSz, fSz = 0, 0, 0
    local funcs = {}

    for k,v in pairs(details) do
        if includeC or v.source ~= "=[C]" then
            tSz = math_max(tSz, #tostring(string_format("%." .. tostring(module.prec) .. "f", v.total)))
            cSz = math_max(cSz, #tostring(v.calls))
            fSz = math_max(fSz, #v.name)
            v.avg = v.total / v.calls
            table_insert(funcs, k)
        end
    end
    table_sort(funcs, function(a,b) return details[a].total > details[b].total end)

    local fmtString = "%" .. tostring(tSz) .. "." .. tostring(module.prec) .. "fs / %-" .. tostring(cSz) .. "d (%" .. tostring(tSz) .. "." .. tostring(module.prec) .. "fs) :: %-" .. tostring(fSz) .. "s (%s:%d)"
    for i,v in ipairs(funcs) do
        local item = details[v]
        if includeC or item.source ~= "=[C]" then
            hs_printf(fmtString, item.total, item.calls, item.avg, item.name, item.source, item.line)
        end
    end
    _inProfiler = false
end

return module
