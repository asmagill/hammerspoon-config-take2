local module = {}
local fs = require("hs.fs")

module.scan = function(path)
    assert((fs.attributes(path) or {}).mode == "directory", "must provide a path to a directory")
    local prevDir = fs.currentDir()
    -- force return to original dir, even if we error out
    local onClose <close> = setmetatable({}, { __close = function(_) fs.chdir(prevDir) end })

    local dirsToScan = { fs.pathToAbsolute(path) }
    local toRemove = {}
    local toCheck = {}

    while #dirsToScan > 0 do
        local dir = table.remove(dirsToScan, 1)

        fs.chdir(dir)
        for file in fs.dir(".") do
            local attr = fs.attributes(file)

            if attr.mode == "file" then
                if file:match(" %d+%.%w+$") then
                    local oFile =  table.concat({ file:match("^(.+) %d+(%.%w+)$")}, "")
                    if fs.attributes(oFile) then
                        local s, t, r = os.execute([[diff "]] .. file .. [[" "]] .. oFile .. [["]])
                        if s == true and t == "exit" and r == 0 then
                            table.insert(toRemove, dir .. "/" .. file)
                        else
                            table.insert(toCheck, dir .. "/" .. file)
                        end
                    end
                elseif file:match(" %d+$") then
                    local oFile =  file:match("^(.+) %d+$")
                    if fs.attributes(oFile) then
                        local s, t, r = os.execute([[diff "]] .. file .. [[" "]] .. oFile .. [["]])
                        if s == true and t == "exit" and r == 0 then
                            table.insert(toRemove, dir .. "/" .. file)
                        else
                            table.insert(toCheck, dir .. "/" .. file)
                        end
                    end
                end
            elseif attr.mode == "directory" then
                if not file:match("^%.+$") then
                    table.insert(dirsToScan, dir .. "/" .. file)
                end
            end
        end
    end

    table.sort(toRemove)
    print("Remove:")
    for _, v in ipairs(toRemove) do print("",v) end

    table.sort(toCheck)
    print("Check:")
    for _, v in ipairs(toCheck) do print("",v) end

    return toRemove, toCheck
end

return module
