--[[ Live-updating floating windows at your service!

  https://www.hammerspoon.org/docs/hs.window.html
  https://www.hammerspoon.org/docs/hs.canvas.html
  https://www.hammerspoon.org/docs/hs.image.html
  https://www.hammerspoon.org/docs/hs.mouse.html
  https://www.hammerspoon.org/docs/hs.timer.html

  https://www.lua.org/manual/5.4/manual.html#6.2 (coroutines)
  https://github.com/Hammerspoon/hammerspoon/issues/2710#issuecomment-788266990 (thanks @asmagill)

  TODO:
  =====
  ^ fix crashes! SIGABRT
  ? make PrtScr the on/off toggle and set a modal when floater is active, ctrl pgup/pgdn to shrink/grow
  ? change `sizes` to an {x=,y=} list to allow non-uniform canvas dimensions
  ? use hs.canvas:elementCount() instead of #canvas
  - better way to handle mouseUp if mouse leaves the canvas area during coroutine?
  - clean up global/local var usage
  - use coroutine instead of hs.timer for canvas redraw?
  - support for multiple floaters?
  - properly test multi-monitor

]]--

-- user-settable prefs
local key = 'f12'
local sizes = { 400, 300, 200, 100, 50, 25 }
local sizeIndex = 2 -- starting size index // (zero-based)
local nudge = 35
local refreshIntervals = { 0.25, 0.10, 0.05 }
local reactivateWhenClosing = true
local notifyOnClose = true
local invertScrollDirection = true
local moveOffscreen = true
local hiliteCaptureArea = false
local captureRectColor = { red=0, green=1, blue=0, alpha=1 }
local lineColor = { red=1, green=0, blue=0, alpha=1 }

-- use hs.styledtext.fontNames() to list available fonts
local textFontSize = 20
local textPadding = 3.0
local fTextStyle = {
  font = { name="SFProText-Medium", size=textFontSize },
  color = { red=1, green=1, blue=1, alpha=0.8 },
  paragraphStyle = {
    alignment="left",
    lineBreak="clip",
    maximumLineHeight=textFontSize + 2
  },
  shadow = {
    offset = { h=-1, w=-2 },
    color = { red=0, green=0, blue=0, alpha=0.7 }
  }
}

-- globals
local _cMouseAction
local floater
local w -- current hs.window object to capture from
local i -- windowID of w
local t -- refresh timer
local app -- stores hs.application object that owns w
local appname -- app:name()
local capture_origin = {}
local capture_center = {}
local floater_origin = {}
local win_frame = {}
local winPosCache = {}
local canvasSize = {}
local _lastClickPos = {}
local _lastClickTime = hs.timer.absoluteTime()
local doubleClickTime = 250000000 -- nanoseconds (0.25s)
local refreshInt = refreshIntervals[1]
local _updatesPaused = false
local loopcount = 0
local failCount = 0
local hasBeenMoved = false

function to_int(num)
  return math.floor(num + 0.5)
end

function get_size(incr)
  idx = sizeIndex or 0
  max = math.min(win_frame.h,win_frame.h)
  if incr then idx = idx+1 end
  if idx > #sizes then idx = 1 end
  for i=idx, #sizes do
    if sizes[i] < max then
      sizeIndex = i
      break
    end
    sizeIndex = 1
  end
  return sizes[sizeIndex]
end

function cycleRefreshInt()
  for c,int in ipairs(refreshIntervals) do
    if refreshInt == int then
      refreshInt = (refreshIntervals[c+1] or refreshIntervals[1])
      break
    end
  end
  startTimer()
  _stopCoroutine('cycle refreshInt')
  if canvasSize.w >= 100 then
    txt = hs.styledtext.new(refreshInt..'s', fTextStyle)
    removeOverlays('interval')
    floater:insertElement({
      id = "interval",
      type = "text",
      text = txt,
      padding = textPadding,
      action = "stroke",
      frame = { x="0%", y="0%", h="100%", w="100%" },
      antialias = true
    })
  end
  if r then r:stop() end
  r = hs.timer.doAfter(1.5, function() removeOverlays('interval') end)
end

function invalidateSrcWindow()
  print('invalidating src window')
  w = nil
end

function resetSrcWindow()
  w,i = nil
  app, appname = nil
  canvasSize = {}
end

function close_floater(flag,delay,reason)
  print('closing floater: '..(reason or 'unknown'))
  _stopCoroutine('called from close_floater')
  stopTimer()
  if floater then
    floater:delete(delay or 0)
    floater = nil
  end
  if captureHilite then
    captureHilite:delete(0)
    captureHilite = nil
  end
  destroyHotkeys()
  if flag then
    toggleWinPos('show')
    resetSrcWindow()
  end
  failCount = 0
  collectgarbage()
end

function point_near(p1,p2,d)
  local delta = math.abs(p1.x - p2.x) + math.abs(p1.y - p2.y)
  return (delta <= d)
end

function checkForDoubleClick(ts,pos)
  if ts - _lastClickTime < doubleClickTime then
    if point_near(pos, _lastClickPos, 2) then
      return true
    end
  end
  _lastClickPos = pos
  _lastClickTime = ts
  return false
end

function startTimer()
  stopTimer()
  t = hs.timer.doWhile(
    function() return srcWinExists(w) end,
    function() refreshWin(i) end,
    refreshInt)
    -- print('refresh timer started')
end

function stopTimer()
  if t then
    t:stop()
    t = nil
    -- print('refresh timer stopped')
  end
end

function srcWinExists(w)
  if w and hs.axuielement.windowElement(w):isValid() then
    return true
  else
    invalidateSrcWindow()
    if notifyOnClose then
      msg = 'The window that was being tracked from '..appname..' has closed.'
      hs.notify.show('Underlying window closed','',msg)
      print(msg)
    end
    close_floater(true,0,'unexpected close')
    return false
  end
end

function valid_capture_pos(p,max)
  if p < 0 then return 0 end
  if p > max then return to_int(max) end
  return to_int(p)
end

function get_relative_mouse(mouse,frame)
  local left = frame.x
  local right = frame.x + frame.w
  local top = frame.y
  local bottom = frame.y + frame.h
  local rmx = mouse.x - left
  local rmy = mouse.y - top
  if rmx < 0 then rmx = 0 end
  if rmy < 0 then rmy = 0 end
  if mouse.x > right then rmx = right end
  if mouse.y > bottom then rmy = bottom end
  return { x=to_int(rmx), y=to_int(rmy) }
end

function valid_origin(o,min,max)
  local max_adj = min + max
  if o < min then return to_int(min) end
  if o > max_adj then return to_int(max_adj) end
  return to_int(o)
end

function _updateCaptureOrigin(new_origin,offset)
  capture_origin = {
    x = new_origin.x,
    y = new_origin.y
  }
  capture_center = {
    x = capture_origin.x + offset.x,
    y = capture_origin.y + offset.y
  }
end

function max_x_pos()
  -- hs.inspect(hs.screen.screenPositions())
  local max_x = 0
  for _,scr in ipairs(hs.screen.allScreens()) do
    scrWidth = scr:currentMode().w
    scrPos = { scr:position() }
    scrX = scrWidth + scrPos[1]
    if scrX > max_x then max_x = scrX end
  end
  return (to_int(max_x) or 0)
end

function mouseHasMoved(old,new)
  if (type(old) ~= 'table') or (type(new) ~= 'table') then return true end
  if old == new then return false end
  if to_int(old.x) ~= to_int(new.x) then return true end
  if to_int(old.y) ~= to_int(new.y) then return true end
  return false
end

function showPausedText()
  if canvasElementExists('pausedrect') then return end
  if canvasSize.w >= 100 then
    txt = hs.styledtext.new('PAUSED', fTextStyle)
  else
    txt = hs.styledtext.new('X', fTextStyle)
  end
  floater:appendElements({
    id = "pausedrect",
    type = "rectangle",
    action = "fill",
    fillColor = { red=0, green=0, blue=0, alpha=0.5 },
    antialias = false,
    frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
    trackMouseDown = true,
    trackMouseUp = true
  },
  {
    id = "pausedtxt",
    type = "text",
    text = txt,
    padding = textPadding,
    action = "stroke",
    frame = { x="0%", y="0%", h="100%", w="100%" },
    antialias = true,
    trackMouseDown = true,
    trackMouseUp = true
  })
end

function refreshWin(i,force)

  if _updatesPaused then
    if w and w:isMinimized() then
      if force then showPausedText() end
      return
    else
      _updatesPaused = false
      removeOverlays({'pausedrect','pausedtxt'})
    end
  else
    if w and w:isMinimized() then
      _updatesPaused = true
      showPausedText()
      return
    end
  end

  -- hs.window:snapshot(false) doesn't work, but hs.window:snapshot() does
  -- local snap = w:snapshot()
  local snap = hs.window.snapshotForID(i, false)
  if not (snap and getmetatable(snap).__type == 'hs.image') then
    failCount = failCount + 1
    if failCount >= 10 then
      close_floater(true,0.1,'failed to get snapshot, giving up after '..failCount..' tries')
    end
    return
  end
  local cropped = snap:croppedCopy({
    x=capture_origin.x,
    y=capture_origin.y,
    h=canvasSize.h,
    w=canvasSize.w,
  })
  floater[2] = {
    id = "preview",
    type = "image",
    action = "fill",
    compositeRule = 'copy',
    antialias = false,
    frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
    padding = 2.0,
    image = cropped,
    imageAlpha = 1.0,
    imageAlignment = 'center',
    imageScaling = 'none',
    trackMouseDown = true,
    trackMouseUp = true,
    trackMouseEnterExit = true
  }
  snap, cropped = nil
  loopcount = loopcount + 1
  if loopcount > 40 then
    collectgarbage()
    -- print("Process resident size: "..hs.crash.residentSize())
    -- print("Lua state size: "..math.floor(collectgarbage("count")*1024))
    loopcount = 0
  end
end

function toggleWinPos(action)
  if action == 'show' then
    if winPosCache[i] then
      if w then w:setFrame(winPosCache[i]) end
      winPosCache[i] = nil
    end
    if reactivateWhenClosing and app and w then
      app:activate()
      w:unminimize()
    end
    hasBeenMoved = false
  elseif action == 'hide' then
    if moveOffscreen and w then
      winPosCache[i] = win_frame
      w:setFrame({ x=max_x_pos(), y=win_frame.y, w=win_frame.w, h=win_frame.h }, 0)
      w:move({nudge,0}, false, 0.5) -- kludge because setFrame won't fully push a window offscreen
      hasBeenMoved = true
    end
  end
end

function drawBoxAroundCaptureArea()
  captureHilite = hs.canvas.new({
    x=win_frame.x + capture_origin.x,
    y=win_frame.y + capture_origin.y,
    h=canvasSize.h,
    w=canvasSize.w
  })
  captureHilite[1] = {
    id = "border",
    type = "rectangle",
    action = "stroke",
    strokeWidth = 4.0,
    strokeColor = captureRectColor,
    antialias = false,
    frame = { x = "0%", y = "0%", h = "100%", w = "100%" }
  }
  captureHilite:level('overlay')
  captureHilite:show()
end

function drawCrosshairs()
  if _updatesPaused then return end
  if canvasElementExists(floater,'crosshair') then return end
  top = { x=floater:frame().w/2, y=0 }
  bottom = { x=floater:frame().w/2, y=floater:frame().h }
  left = { x=0, y=floater:frame().h/2 }
  right = { x=floater:frame().w, y=floater:frame().h/2 }
  center = { x=floater:frame().w/2, y=floater:frame().h/2 }
  floater:insertElement({
    id = "crosshair",
    type = "segments",
    action = "stroke",
    coordinates = { top, bottom, center, left, right },
    strokeWidth = 1.0,
    antialias = false,
    strokeColor = lineColor
  })
end

function drawEscText()
  if canvasElementExists(floater,'esctxt') then return end
  if canvasElementExists(floater,'crosshair') then
    if canvasSize.w >= 100 then
      removeOverlays('interval')
      txt = hs.styledtext.new('ESC', fTextStyle)
      floater:insertElement({
        id = "esctxt",
        type = "text",
        text = txt,
        padding = textPadding,
        action = "stroke",
        frame = { x="0%", y="0%", h="100%", w="100%" },
        antialias = true
      })
    end
  end
end

function canvasElementExists(canvas,id)
  if not (canvas and id) then return false end
  if getmetatable(canvas).__type ~= 'hs.canvas' then return false end
  if type(id) ~= 'string' then return false end
  for _,e in ipairs(canvas:canvasElements()) do
    if id == e.id then return true end
  end
  return false
end

function removeOverlays(ids) -- (...)
  -- local arg={...}
  if type(ids) == 'string' then ids = { ids } end
  if (floater and #floater > 2) then -- use hs.canvas:elementCount() ?
    for _,id in ipairs(ids) do
      for e=3, #floater do
        element_id = floater[e].id -- floater:elementAttribute(e,'id')
        if (id == 'all') or (element_id == id) then
          floater:removeElement(e) -- floater[e] = nil
          break
        end
      end
    end
  end
end

function destroyHotkeys()
  if hk_esc then
    hk_esc:delete()
    hk_esc = nil
  end
  if hk_speed then
    hk_speed:delete()
    hk_speed = nil
  end
end

function _stopCoroutine(reason)
  _cMouseAction = nil
  print('stopping coroutine: '..(reason or 'unknown'))
  removeOverlays({'esctxt','crosshair'})
  if hk_esc then
    hk_esc:delete()
    hk_esc = nil
  end
end

function createFail(msg)
  print(msg)
  resetSrcWindow()
  return false
end

function destroy_floater()
  if floater then
    close_floater(true,0.1,'closed by hotkey')
    return
  end
end

function create_floater()

  cur_pos = hs.mouse.absolutePosition()

   -- make sure we have a valid window to track
  if not w then
    w = hs.window.focusedWindow()
    if not w then return createFail('no focused window') end
    if w == hs.window.desktop() then return createFail('can\'t float the desktop window') end
    if not w:isVisible() then createFail('can\'t float an invisible window') end
    i = w:id()
    if not i then return createFail('couldn\'t obtain the windowID') end

    app = w:application()
    appname = (app:name() or 'unknown')
    win_frame = w:frame()
    win_scr = w:screen()
    win_scr_frame = win_scr:fullFrame()
    capture_center = get_relative_mouse(cur_pos,win_frame)
  end

  if floater then
    floater_center = {
      x = to_int(floater:frame().x + floater:frame().w/2),
      y = to_int(floater:frame().y + floater:frame().h/2)
    }
    close_floater(false,0,'respawn')
    presetSize = get_size(true)
  else
    floater_center = {
      x = to_int(cur_pos.x),
      y = to_int(cur_pos.y)
    }
    presetSize = get_size(false)
  end

  canvasSize = { h=math.min(presetSize,to_int(win_frame.h)), w=math.min(presetSize,to_int(win_frame.w)) }
  canvasAdj = { x=to_int(canvasSize.w/2), y=to_int(canvasSize.h/2) }

  floater_origin = {
    x = valid_origin(floater_center.x - canvasAdj.x, win_scr_frame.x, win_scr_frame.x + win_scr_frame.w - canvasSize.w),
    y = valid_origin(floater_center.y - canvasAdj.y, win_scr_frame.y, win_scr_frame.y + win_scr_frame.h - canvasSize.h)
  }

  _updateCaptureOrigin({
    x = valid_capture_pos(capture_center.x - canvasAdj.x, win_frame.w - canvasSize.w),
    y = valid_capture_pos(capture_center.y - canvasAdj.y, win_frame.h - canvasSize.h)},
    canvasAdj)

  if hiliteCaptureArea then
    drawBoxAroundCaptureArea()
  end
  floater = hs.canvas.new({
    x=floater_origin.x,
    y=floater_origin.y,
    h=canvasSize.h,
    w=canvasSize.w
  })
  if floater then
    floater[1] = {
      id = "border",
      type = "rectangle",
      action = "stroke",
      strokeWidth = 4.0,
      strokeColor = lineColor,
      antialias = false,
      frame = { x = "0%", y = "0%", h = "100%", w = "100%" }
    }
    refreshWin(i,true)
    floater:level('overlay') -- allows floater to be positioned above dock/menubar
    floater:show()
    startTimer()
    if not hasBeenMoved then
      if ht then ht:stop() end
      ht = hs.timer.doAfter(0.25, function() toggleWinPos('hide') end)
    end

    if not hk_speed then
      hk_speed = hs.hotkey.bind({'ctrl'}, key, nil, cycleRefreshInt, nil, nil)
    end

    floater:clickActivating(false):mouseCallback(function(_c, _m, _i, _x, _y)

      --[[
        _c = canvas
        _m = mouse action
        _i = element id
        _x, _y = click coordinates
      ]]--

      print('clickActivating: ' .. _m)
      if not hk_esc then
        hk_esc = hs.hotkey.bind(nil, 'escape', function()
          _stopCoroutine('hotkey')
        end, nil, nil)
      end
      if _m == "mouseDown" then
        local _buttons = hs.eventtap.checkMouseButtons()
        local last_pos = hs.mouse.absolutePosition()
        if _buttons.left and checkForDoubleClick(hs.timer.absoluteTime(),last_pos) then
          toggleWinPos('show')
          return
        end
        if _buttons.right then drawCrosshairs() end
        local starting_pos = last_pos
        local orig_capture_origin = capture_origin
        _cMouseAction = coroutine.wrap(function()
          while _cMouseAction do
            local cur_pos = hs.mouse.absolutePosition()
            if mouseHasMoved(last_pos,cur_pos) then
              last_pos = cur_pos
              if _buttons.right and not _updatesPaused then -- move capture area
                local delta = { x=(to_int(cur_pos.x - starting_pos.x)), y=(to_int(cur_pos.y - starting_pos.y)) }
                -- print('delta: x:'..delta.x..' y:'..delta.y..' invert:'..tostring(invertScrollDirection))
                if invertScrollDirection then
                  delta.x = -delta.x
                  delta.y = -delta.y
                end
                _updateCaptureOrigin({
                  x = valid_capture_pos(orig_capture_origin.x + delta.x, win_frame.w - canvasSize.w),
                  y = valid_capture_pos(orig_capture_origin.y + delta.y, win_frame.h - canvasSize.h)},
                  canvasAdj)
                refreshWin(i)
              elseif _buttons.left then -- move floater
                local frame = _c:frame()
                frame.x = to_int(cur_pos.x - _x)
                frame.y = to_int(cur_pos.y - _y)
                _c:frame(frame)
              end
            end
            coroutine.applicationYield() -- 0.001 ?
          end -- end of while loop
        end)
        _cMouseAction()
      elseif _m == "mouseUp" then
        _stopCoroutine(_m)
      elseif _m == "mouseExit" then
        drawEscText()
      end
    end)
  end
end

local hk_create = hs.hotkey.bind(nil, key, create_floater, nil, nil)
local hk_destroy = hs.hotkey.bind({'shift'}, key, nil, destroy_floater, nil, nil)
