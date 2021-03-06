dr = debug.getregistry()
drEval = function(l, everyThing)
    l = l or debug.getregistry()
    for i,v in ipairs(l) do
        local ty, val = type(v), tostring(v)
        if ty == "table" then
            if v == _G then
                val = "Global Environment"
            else
                local kvCt = 0
                local kvIdx, _ = next(v)
                while kvIdx do
                    if kvIdx ~= "__type" then kvCt = kvCt + 1 end
                    kvIdx, _ = next(v, kvIdx)
                end

                local isArray, isKV = (#v > 0), (kvCt > #v)
--                 if not isArray and not isKV then
--                     val = nil
--                 elseif isArray and not isKV then
--                     val = string.format("array: %d items", #v)
--                 elseif not isArray and isKV then
--                     val = string.format("kv:    %d pairs", kvCt)
--                 else -- isArray and isKV then
--                     val = string.format("table: %d items +  %d pairs", #v, kvCt - #v)
--                 end
                val = string.format("%4d / %4d kv", #v, kvCt - #v)
            end
        else
            if not everyThing then val = nil end
        end
        if val then print(i, ty, val, v.__type or "** unknown **") end
    end
end
