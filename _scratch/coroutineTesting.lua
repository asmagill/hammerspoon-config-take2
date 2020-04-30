myFunction = function(...)
    local myFunctionWatchables = hs.watchable.new("myFunctionWatchables", true)
    myFunctionWatchables.running = true
    local dataChanged = false
    local internalWatchers = {
        hs.watchable.watch("myFunctionWatchables.quit", function(w, p, k, o, n)
            dataChanged = true
        end),
    }

    local cv = hs.canvas.new{ x = 100, y = 100, h = 100, w = 500 }:show()
    cv[#cv + 1] = {
        type      = "rectangle",
        fillColor = { white = .5 },
        action    = "fill",
    }
    cv[#cv + 1] = {
        type          = "text",
        textSize      = 36,
        text          = "******",
        textAlignment = "center",
    }

    local longTask
    longTask = coroutine.wrap(function(...)
        local exitCondition = false
        while not exitCondition do
            if dataChanged then
                if myFunctionWatchables.quit == true then
                    exitCondition = true
                end
                dataChanged = false
            end

            local newNum = hs.hash.MD5(hs.math.randomFromRange(0,100000))
            myFunctionWatchables.interimData = newNum
            cv[2].text = newNum

            coroutine.applicationYield()
        end

        myFunctionWatchables.finalData = "done!"
        cv:delete()

        longTask = nil
        for i,v in ipairs(internalWatchers) do
            v:release()
        end
        internalWatchers = nil

    end)
    longTask(...)
end

local myCount = 0
local lastNum = "******"

outsideWatchers = {
    hs.watchable.watch("myFunctionWatchables.interimData", function(w, p, k, o, n)
        myCount = myCount + 1
        lastNum = n
    end),
    hs.watchable.watch("myFunctionWatchables.finalData", function(w, p, k, o, n)
        print(myCount, lastNum, n)

        -- clean up so we don't leave things around that are no longer active
        for i,v in ipairs(outsideWatchers) do
            v:release() -- it's done, so release our watchers
        end
        outsideWatchers = nil
    end),
}

myFunction()
