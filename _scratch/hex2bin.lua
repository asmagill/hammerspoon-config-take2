local module = {}
local fs = require("hs.fs")

module.convert = function(fromFile)
    assert(type(fromFile) == "string")

    fromFile = fs.pathToAbsolute(fromFile)
    local toFile = fromFile .. ".bin"

    if not fs.attributes(fromFile) then error(string.format("unable to find file %s", fromFile)) end
    if fs.attributes(toFile) then error(string.format("file %s already exists", toFile)) end

    local oFile = io.open(toFile, "w")
    for input in io.lines(fromFile, "l") do
        for x in input:match(":%s+[0-9A-F ]+$"):gmatch("[0-9A-F]+") do
            oFile:write(string.char(tonumber(x, 16)))
        end
        oFile:flush()
    end
    oFile:close()
end


return module


