-- modified from code found at https://github.com/dharmapoudel/hammerspoon-config
--
-- Modified to more closely match my usage style

-- I prefer a different type of key invocation/remove setup
local alert       = require("hs.alert")
local hotkey      = require("hs.hotkey")
local timer       = require("hs.timer")
local eventtap    = require("hs.eventtap")
local notify      = require("hs.notify")
local dn          = require("hs.distributednotifications")
local fnutils     = require("hs.fnutils")
local application = require("hs.application")
local watchables  = require("hs.watchable")
local screen      = require("hs.screen")
local webview     = require("hs.webview")
local canvas      = require("hs.canvas")

local events = eventtap.event.types

local module = {}

local menuGetter = require("utils.getMenusIn").getMenuItems

module.watchables = watchables.new("cheatsheet", true)

module.autoDismiss     = true
module.showEmptyMenus  = false
module.cmdKeyPressTime = 3

-- module.bgColor  = "#bbd" -- "#eee"
module.bgColor  = "#003f3f"
module.fgColor  = "#fff"
module.alpha    = 0.85

module.font     = "arial"
module.fontSize = 12


------------------------------------------------------------------------
--/ Cheatsheet Copycat /--
------------------------------------------------------------------------

local modifiersToString = function(mods)
    if type(mods) ~= "table" then
        print("~~ unrecognized type for menu shortcut modifier map: " .. type(mods))
        retrn ""
    end

    local map, result = {}, ""
    for i,v in ipairs(mods) do map[v] = true end
    if map["ctrl"] then
        result = result .. "⌃"
        map["ctrl"] = nil
    end
    if map["alt"] then
        result = result .. "⌥"
        map["alt"] = nil
    end
    if map["shift"] then
        result = result .. "⇧"
        map["shift"] = nil
    end
    if map["cmd"] then
        result = result .. "⌘"
        map["cmd"] = nil
    end
    if next(map) then
        print("~~ unrecognized modifier in menu shortcut map: { " .. table.concat(mods, ", ") .. " }")
    end
    return result
end

local glyphs = application.menuGlyphs

local getAllMenuItems -- forward reference, since we're called recursively
getAllMenuItems = function(t)
    local menu = ""
        for pos,val in pairs(t) do
            if(type(val)=="table") then
                if(val['AXRole'] =="AXMenuBarItem" and type(val['AXChildren']) == "table") then
                    local menuDetails = getAllMenuItems(val['AXChildren'][1])
                    if module.showEmptyMenus or menuDetails ~= "" then
                        menu = menu.."<ul class='col col"..pos.."'>"
                        menu = menu.."<li class='title'><strong>"..val['AXTitle'].."</strong></li>"
                        menu = menu.. menuDetails
                        menu = menu.."</ul>"
                    end
                elseif(val['AXRole'] =="AXMenuItem" and not val['AXChildren']) then
                    if( val['AXMenuItemCmdModifiers'] ~='0' and (val['AXMenuItemCmdChar'] ~='' or type(val['AXMenuItemCmdGlyph']) == "number")) then
                        if val['AXMenuItemCmdChar'] == "" then
                            menu = menu.."<li><div class='cmdModifiers'>"..modifiersToString(val['AXMenuItemCmdModifiers']).." "..(glyphs[val['AXMenuItemCmdGlyph']] or "?"..tostring(val['AXMenuItemCmdGlyph']).."?").."</div><div class='cmdtext'>".." "..val['AXTitle'].."</div></li>"
                        else
                            menu = menu.."<li><div class='cmdModifiers'>"..modifiersToString(val['AXMenuItemCmdModifiers']).." "..val['AXMenuItemCmdChar'].."</div><div class='cmdtext'>".." "..val['AXTitle'].."</div></li>"
                        end
                    end
                elseif(val['AXRole'] =="AXMenuItem" and type(val['AXChildren']) == "table") then
                    menu = menu..getAllMenuItems(val['AXChildren'][1])
                end

            end
        end
    return menu
end

local generateHtml = function(allMenuItems)
    local focusedApp = application.frontmostApplication()
    local appTitle = focusedApp:title()
    local myMenuItems = allMenuItems and getAllMenuItems(allMenuItems) or "<i>&nbsp;&nbsp;application has no menu items</i>"

    local html = [[
        <!DOCTYPE html>
        <html>
        <head>
        <style type="text/css">
            *{margin:0; padding:0;}
            html, body{
              background-color:]]..module.bgColor..[[;
              font-family: ]]..module.font..[[;
              font-size: ]]..module.fontSize..[[px;
              color: ]]..module.fgColor..[[;
            }
            a{
              text-decoration:none;
              color:#000;
              font-size: ]]..module.fontSize..[[px;
            }
            li.title{ text-align:left;}
            ul, li{list-style: inside none; padding: 0 0 5px;}
            footer{
              position: fixed;
              left: 0;
              right: 0;
              height: 48px;
              background-color:]]..module.bgColor..[[;
            }
            header{
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              height:48px;
              background-color:]]..module.bgColor..[[;
              z-index:99;
            }
            footer{ bottom: 0; }
            header hr,
            footer hr {
              border: 0;
              height: 0;
              border-top: 1px solid rgba(0, 0, 0, 0.1);
              border-bottom: 1px solid rgba(255, 255, 255, 0.3);
            }
            .title{
                padding: 15px;
            }
            li.title{padding: 0  10px 15px}
            .content{
              padding: 0 0 15px;
              font-size: ]]..module.fontSize..[[px;
              overflow:hidden;
            }
            .content.maincontent{
              position: relative;
              height: 577px;
              margin-top: 46px;
            }
            .content > .col{
              width: 23%;
              padding:10px 0 20px 20px;
            }

            li:after{
              visibility: hidden;
              display: block;
              font-size: 0;
              content: " ";
              clear: both;
              height: 0;
            }
            .cmdModifiers{
              width: 65px;
              padding-right: 15px;
              text-align: right;
              float: left;
              font-weight: bold;
            }
            .cmdtext{
              float: left;
              overflow: hidden;
              width: 165px;
            }
        </style>
        </head>
          <body>
            <header>
              <div class="title"><strong>]]..appTitle..[[</strong></div>
              <hr />
            </header>
            <div class="content maincontent">]]..myMenuItems..[[</div>

          <footer>
            <hr />
              <div class="content" >
                <div class="col">
                  by <a href="https://github.com/dharmapoudel" target="_parent">dharma poudel</a>
                </div>
              </div>
          </footer>

          <script type="text/javascript">
            var elem = document.querySelector('.content');
            var iso = new Isotope( elem, {
              // options
              itemSelector: '.col',
              layoutMode: 'masonry'
            });
          </script>
          </body>
        </html>
        ]]

    return html
end

-- We use a modal hotkey setup as a convenient wrapper which gives us an enter and an exit method for
-- generating the display, but we don't actually assign any keys

module.cs = hotkey.modal.new()
    function module.cs:entered()
        module.cs._waitingToBuild = true

        local screenFrame = screen.mainScreen():frame()

        local c = canvas.new{ x = 0, y = 0, h = 0, w = 0 }
        c[1] = {
            type             = "rectangle",
            action           = "strokeAndFill",
            strokeColor      = { white = 1, alpha = 1 },
            fillColor        = { hex = module.bgColor, alpha = 0.75 },
            roundedRectRadii = { xRadius = 27, yRadius = 27 },
        }
        c[2] = {
            type             = "text",
            textColor        = { white = 1, alpha = 1 },
            textFont         = ".AppleSystemUIFont",
            textSize         = 24,
            text             = "Thinking",
        }
        local textSize = c:minimumTextSize(2, "Thinking . . .")
        c[2].frame = { x = c[2].textSize, y = c[2].textSize / 2, w = textSize.w, h = textSize.h }
        c:frame{
            x = screenFrame.x + (screenFrame.w - (textSize.w + (c[2].textSize * 2))) / 2,
            y = screenFrame.y + (screenFrame.h - (textSize.h + (c[2].textSize * 3))) / 2,
            w = textSize.w + (c[2].textSize * 2),
            h = textSize.h + c[2].textSize
        }:show()

        local thinkingLabels = {
            "Thinking",
            "Thinking .",
            "Thinking . .",
            "Thinking . . .",
        }
        local thinkingPos = 0
        local thinkingUpdated = timer.secondsSinceEpoch()
        local thinkingCR
        thinkingCR = coroutine.wrap(function()
            while module.cs._waitingToBuild do
--                 print(thinkingUpdated, thinkingPos)
                if timer.secondsSinceEpoch() - thinkingUpdated >= 0.5 then
                    thinkingPos = (thinkingPos + 1) % #thinkingLabels
                    c[2].text = thinkingLabels[thinkingPos + 1]
                    thinkingUpdated = timer.secondsSinceEpoch()
                end
                coroutine.applicationYield(.2)
            end
            c:hide()

            thinkingCR = nil
            c = nil
        end)

        thinkingCR()
--         application.frontmostApplication():getMenuItems(function(allMenuItems)
        menuGetter(application.frontmostApplication(), function(allMenuItems)
            if c then c:hide() end
            if module.cs._waitingToBuild then
                module.cs._waitingToBuild = nil

                local viewFrame = {
                    x = screenFrame.x + 50,
                    y = screenFrame.y + 50,
                    h = screenFrame.h - 100,
                    w = screenFrame.w - 100,
                }

                if not module._contentController then
                    module._contentController = webview.usercontent.new("injectedLocalJS")
                    local scriptPath = hs.configdir .. "/_localAssets/isotope.pkgd.min.js"
                    local f = io.open(scriptPath)
                    if f then
                        local jsCode = f:read("a")
                        f:close()
                        module._contentController:injectScript{ source = jsCode }
                    else
                        print("*** Unable to load " .. scriptPath)
                    end
                end

                module.myView = webview.new(viewFrame, { developerExtrasEnabled = true }, module._contentController)
                      :windowStyle("utility")
                      :closeOnEscape(true)
                      :allowGestures(true)
                      :windowTitle("CheatSheets")
                      :level(canvas.windowLevels.floating)
                      :alpha(module.alpha or 1.0)
                      :html(generateHtml(allMenuItems))
                      :show()
            else
                module.cs:exit()
            end
        end, true)
    end
    function module.cs:exited()
        if module.myView then
            module.myView:delete()
            module.myView=nil
        end
    end
module.cs:bind({}, "escape", function() module.cs:exit() end)

-- mimic CheatSheet's trigger for holding Command Key

module.eventwatcher = eventtap.new({events.flagsChanged}, function(ev)
    -- been getting triggered too easily and making the mac slow, so let's make it a little
    -- harder to do on accident
    module.cmdPressed = ev:getFlags():containExactly{ "cmd", "fn" }

    if module.cmdPressed then
        module.eventwatcher:stop()

        module.countDown = timer.doAfter(module.cmdKeyPressTime, function()
            if module.cmdPressed then -- in case it gets cleared before we're run but our callback is queued
                module.cs:enter()
                module.cmdPressed = nil
            end
        end)

        module.eventwatcher2 = eventtap.new({events.flagsChanged, events.keyDown, events.leftMouseDown}, function(ev)
            -- because we listen for multiple event types, it's possible that this callback function may
            -- be queued and executed multiple times... bail if we've already done our work
            if module.eventwatcher2 then
                if module.countDown then
                    module.countDown:stop()
                    module.countDown = nil
                end

                module.cs._waitingToBuild = nil -- in case the display is still waiting on the getMenuItems callback
                if module.myView and module.autoDismiss then module.cs:exit() end

                module.eventwatcher2:stop()
                module.eventwatcher2 = nil
                module.eventwatcher:start()
                module.cmdPressed = nil
            end
            return false
        end):start()
    end

    return false
end):start()

module.remoteAccessWatcher = dn.new(function(n,o,i)
    local vn = i and i.ViewerNames or nil
    if not vn then
        print("~~ com.apple.remotedesktop.viewerNames with unknown details: object = " .. tostring(o) .. ", info = " .. tostring(i))
    else
        if #vn > 0 and module.eventwatcher:isEnabled() then
            notify.show("Remote Viewer Detected", "...disabling Cmd-Key Cheatsheat", "", "")
            module.watchables.enabled = false
        elseif #vn == 0 and not module.eventwatcher:isEnabled() then
            notify.show("Remote Viewer Left", "...re-enabling Cmd-Key Cheatsheat", "", "")
            module.watchables.enabled = true
        end
    end
end, "com.apple.remotedesktop.viewerNames"):start()

module.toggle = function()
   module.watchables.enabled = not module.watchables.enabled
end

module.watchables.enabled = module.eventwatcher:isEnabled()

module.toggleForWatchablesEnabled = watchables.watch("cheatsheet.enabled", function(w, p, i, oldValue, value)
    if value then
        module.eventwatcher:start()
    else
        module.eventwatcher:stop()
    end
end)

return module
