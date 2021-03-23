compareKey = function(key, path, file)
    local results = {}
    local fs    = require("hs.fs")
    local plist = require("hs.plist")
    for entry in fs.dir(path) do
        if entry:match(".lproj") then
            local targetFile = path .. "/" .. entry .. "/" .. file
            if fs.attributes(targetFile) then
                local dictionary = plist.read(targetFile)
                if dictionary then
                    print(string.format("%s[%s] = %s", entry, key, dictionary[key]))
                    results[entry] = dictionary[key]
                else
                    print(string.format("%s: unable to parse dictionary"))
                end
            else
                print(string.format("%s: unable to open %s", entry, targetFile))
            end
        end
    end
    return results
end
