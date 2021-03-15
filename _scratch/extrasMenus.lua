--
--    Quick and Dirty attempt at looking into Extras Menus (those menus applications put
--    in the menubar at the right)
--
--    This is offered *as-is*. I may work on it some more and make it more robust at a later
--    date. Or I may not. You're welcome to, but I make zero promises about it in its current
--    state beyond that it works for *some* menus (Time Machine and Dash seemed to work well)
--    not at all for others, and horrendously for yet others (specifically Hammerspoon itself
--    -- read-on)
--
--    Limitations -- the axuielements don't exist until the menu is created, so this
--    *must* trigger them before enumerating their contents. There is no other way.
--
--    To identify the source application for a menu, you can move the mouse point over
--    the icon in question and then enter the following into the Hammerspoon console
--    (without moving the mouse pointer):
--
--        hs.axuielement.systemElementAtPosition(hs.mouse.absolutePosition()):path()[1].AXTitle
--
--    This does *not* work with all extras menus. In some cases this is because they don't use
--    traditional menu/menuitem elements; in other cases, I have no idea why. This is meant as
--    a starting point for exploration, not a finished product.
--
--    It should also be noted that this does *not* work with Hammerspoon extras menus. Don't know
--    why. Some return an empty table, some appear but don't auto-close themselves (and have to
--    be manually closed by clicking somewhere or tapping Esc) before returning an empty table
--    while others enter an infinite loop. At present, the `getExtrasMenus` function will
--    prevent you from choosing the Hammerspoon app, so if you wish to experiment with this
--    further, you'll need to comment out that line.
--
--    I'll use Dash as an example of one that *does* work (https://kapeli.com/dash)
--
--         > em = dofile("_scratch/extrasMenus.lua") -- or wherever you saved it
--
--         > r = em.getExtrasMenus("Dash")
--
--         > #r
--         1
--
--         > em.getMenuItemsForExtrasMenu(r[1], function(results) print(hs.inspect(results)) end)
--         { { "Open" }, { "Preferences" }, { "Help", "User Guide" }, { "Help", "Contact Support" }, { "Help", "Check for Updates" }, { "Quit" } }
--
--         > em.selectMenuItemForExtrasMenu(r[1], { "Help", "User Guide" })
--
--
--
--    Let me reiterate -- extras menus do not *exist* in the axuielement hierarchy until they
--    are visible on the screen. So it's kind of hard to explore them. But you can do something
--    along these lines if you want to look at them in details and maybe see where the logic
--    below could be extended or corrected.
--
--         em = dofile("_scratch/extrasMenus.lua") -- or wherever you saved it
--         r = em.getExtrasMenus("Dash") -- get the extras menus for the app you want to explore
--         -- some apps may have more than one, but most will only have the one extras menu
--         -- checking #r will tell you for sure.
--
--         -- The following has to all be one entry in the console or in a file you're loading with
--         -- dofile or require:
--             r[1]:doAXPress() -- make the menu appear so the axuielement objects exist
--             r[1]:buildTree(function(msg, tbl) -- see hs.axuielement docs for buildTree
--                 print(msg)
--                 ans = tbl -- store results in global so we can examine them in a bit
--                 r[1][1]:doAXCancel() -- close the menu
--             end)
--
--         -- Now you can use `hs.inspect` to examine `ans`. Warning, it will probably be a
--         -- *lot* of stuff to wade through, but that's how you figure out what's available
--         -- with axuielement and how things are connected.

local axuielement = require("hs.axuielement")
local application = require("hs.application")

local axuielementMT = hs.getObjectMetatable("hs.axuielement")

local module = {}

module.getExtrasMenus = function(app)
    local appElement = axuielement.applicationElement(application(app))
    if appElement.AXTitle == "Hammerspoon" then error("can't inspect our own extras menus") end

    if appElement then
        -- iterate over children backwards (extras menubar is usually *after* application one)
        local extraMenuElements = {}
        for i = #appElement, 1, -1 do
            local entity = appElement[i]
            if entity.AXRole == "AXMenuBar" then
                for j = 1, #entity, 1 do
                    local menuBarEntity = entity[j]
                    if menuBarEntity.AXSubrole == "AXMenuExtra" then
                        table.insert(extraMenuElements, menuBarEntity)
                    end
                end
                if #extraMenuElements > 0 then
                    return extraMenuElements
                end
            end
        end
        return nil, "no extra menus found for application"
    end
    return nil, "unable to get application element"
end


local recursiveMenuDescent
recursiveMenuDescent = function(element)
    local results = {}
    if element and element:isValid() then
        for i = 1, #element, 1 do
            local child = element[i]
            if child.AXEnabled then
                if #child == 0 then
                    table.insert(results, { child.AXTitle })
                else
                    for _, v2 in ipairs(recursiveMenuDescent(child[1])) do
                        table.insert(results, table.move(v2, 1, #v2, 2, { child.AXTitle }))
                    end
                end
            end
        end
    end
    return results
end

module.getMenuItemsForExtrasMenu = function(element, fn)
    assert(getmetatable(element) == axuielementMT, "expected hs.axuielement object for argument 1")
    assert(
        type(fn) == "function" or (getmetatable(fn) or {}).__call,
        "callback must be a function or object with __call metamethod"
    )

    -- extremely slow left at default... not sure why but don't have time to dig right now...
    axuielement.systemWideElement():setTimeout(.1)

    element:doAXPress()
    -- in some cases, it may take a bit for the axuielements to be created, so lets use
    -- a coroutine to check before parsing the extras menubar
    local backgroundTask
    backgroundTask = coroutine.wrap(function()
        local count = 0
        while #element == 0 and count <= 100 do
            coroutine.applicationYield()
            count = count + 1
        end

        local results = {}
        if count ~= 100 then
            local bar = element[1]
            results = recursiveMenuDescent(bar)
            if bar and bar:isValid() then bar:doAXCancel() end
        end
        backgroundTask = nil -- make this an upvalue captured local
        axuielement.systemWideElement():setTimeout(0)

        fn(results)
    end)
    backgroundTask()
end

module.selectMenuItemForExtrasMenu = function(element, item)
    assert(getmetatable(element) == axuielementMT, "expected hs.axuielement object for argument 1")
    if type(item) == "string" then item = { item } end
    for _, v in ipairs(item) do
        assert(type(v) == "string", "expected table of strings specifying menu item")
    end

    -- make a copy in case they're saving this for some reason
    local menuPath = table.move(item, 1, #item, 1, {})

    -- extremely slow left at default... not sure why but don't have time to dig right now...
    axuielement.systemWideElement():setTimeout(.1)

    element:doAXPress()
    -- in some cases, it may take a bit for the axuielements to be created, so lets use
    -- a coroutine to check before parsing the extras menubar
    local backgroundTask
    backgroundTask = coroutine.wrap(function()
        local count = 0
        while #element == 0 and count <= 100 do
            coroutine.applicationYield()
            count = count + 1
        end

        local errMsg
        if count == 100 then
            errMsg = "unable to get extras menu items"
        else
            local bar = element[1]
            local found
            while #menuPath > 0 do
                local step = table.remove(menuPath, 1)
                found = nil
                for i = 1, #bar, 1 do
                    if step == bar[i].AXTitle then
                        found = bar[i]
                        break
                    end
                end
                if found then
                    if #menuPath > 0 then
                        bar = found[1]
                        if not bar then
                            errMsg = string.format(
                                "menu terminates at path item %s from %s",
                                step,
                                table.concat(item, " -> ")
                            )
                            break
                        end
                    end
                    found:doAXPress()
                else
                    errMsg = string.format(
                        "path item %s from %s not found in menu",
                        step,
                        table.concat(item, " -> ")
                    )
                    break
                end
            end
            if errMsg then element[1]:doAXCancel() end
        end
        backgroundTask = nil -- make this an upvalue captured local
        axuielement.systemWideElement():setTimeout(0)

        if errMsg then error(errMsg) end
    end)
    backgroundTask()
end

return module
