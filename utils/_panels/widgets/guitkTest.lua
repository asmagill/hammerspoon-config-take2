local module = {}
local USERDATA_TAG = "guitkTest"

local guitk      = require("hs._asm.guitk")
local styledtext = require("hs.styledtext")
local timer      = require("hs.timer")

local mgr = guitk.manager.new()

mgr[#mgr + 1] = {
    _element = guitk.element.textfield.newLabel("I am a label that is longer than my field"):expandIntoTooltip(true):selectable(true),
    frameDetails = { w = 200 },
}

mgr[#mgr + 1] = {
    _element = guitk.element.textfield.newTextField("I am a text field"):expandIntoTooltip(true),
    frameDetails = { w = 200 },
}

-- colorwell pops up a new panel, so we need to disable autoClose if it's currently active.
--     requires knowing the panel object
local prevAutoClose
mgr[#mgr + 1] = {
    _element = guitk.element.colorwell.new(),
    frameDetails = { h = 50, w = 50 },
    bordered = true,
    callback = function(cwObj, msg, ...)
        if msg == "didBeginEditing" then
            prevAutoClose = _asm._panels.infoPanel:autoClose()
            _asm._panels.infoPanel:autoClose(false)
        elseif msg == "didEndEditing" then
            _asm._panels.infoPanel:autoClose(prevAutoClose)
        end
    end,
}
mgr(#mgr):moveBelow(mgr(#mgr - 1), "flushRight")

mgr[#mgr + 1] = {
    _element = guitk.element.button.radioButtonSet("a","b","c"),
}
mgr(#mgr):moveBelow(mgr(#mgr - 2), "flushLeft")

mgr:sizeToFit(5)

module.element = mgr

-- let the user specify the location when adding the widget, but make sure it's big enough
return function(fd, ...)
    local frameSize = mgr:frameSize()
    fd.id, fd.h, fd.w = USERDATA_TAG, frameSize.h, frameSize.w
    return {
        source = module,
        frameDetails = fd,
        element = mgr,
    }
end
