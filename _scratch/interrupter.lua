local eventtap = require("hs.eventtap")
local timer    = require("hs.timer")
local math     = require("hs.math")

local rawFlags  = eventtap.event.rawFlagMasks
local preFilter = ~(0x20000000 | 0x100) -- see hs.eventtap.event.rawFlagMasks docs

local module = {}

-- The following from hs.eventtap.event.rawFlagMasks are known to work. The right/left
-- distinctions don't seem to be captured; choose the combination that best suits you
-- as a "interrupt trigger".
--
-- secondaryFn (laptop fn key)
-- alternate   (option)
-- command
-- control
-- shift
module.triggerFlags = rawFlags.command + rawFlags.control +
                      rawFlags.shift   + rawFlags.secondaryFn

-- Predeclare so these are all local
local _running
local _consoleInputPreparser
local _hookFn, _hookMask, _hookCount
local _resetHook

local _interrupterCheck = function(...)
    local mods = eventtap.checkKeyboardModifiers(true)._raw & preFilter

    if mods == module.triggerFlags then
        debug.sethook()
        error("interrupted!")
    else
        if _hookFn then
            -- if it becomes an issue, we can look at the reason and the _hookMask and
            -- _hookCount to decide if we should call the previously installed debug hook;
            -- for now, I think that only applies to profilers and moonscript, neither of
            -- which are very common, so we're going to take the easy way out until someone
            -- complains...
            -- local reason = table.pack(...)[1]
            _hookFn(...)
        end
    end
end

module.start = function()
    if _running then
        return nil, "interrupter already being injected"
    end

    _consoleInputPreparser, _running = hs._consoleInputPreparser, true

    hs._consoleInputPreparser = function(s)
        if _consoleInputPreparser then
            s = _consoleInputPreparser(s)
        end

        _hookFn, _hookMask, _hookCount = debug.gethook()
        debug.sethook(_interrupterCheck, "crl", 1)

        _resetHook = timer.doAfter(math.minFloat, function()
            if _hookFn or _hookMask or _hookCount then
                debug.sethook(_hookFn, _hookMask, _hookCount)
            else
                debug.sethook()
            end
            _hookFn, _hookMask, _hookCount = nil, nil, nil
            _resethook = nil
        end)

        return s
    end
    return module
end

module.stop = function()
    if not _running then
        return nil, "interrupter is not currently being injected"
    end

    hs._consoleInputPreparser = _consoleInputPreparser
    _consoleInputPreparser, _running = nil, nil

    return module
end

return module






