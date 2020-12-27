--
-- Download Organizer
--
-- Some basic clean up rules that I want to run on my Downloads folder every
-- so often to keep things cleaner
--

local sourceDir = os.getenv("HOME") .. "/Downloads"
local module = {}

local fs      = require("hs.fs")
local plist   = require("hs.plist")
local inspect = require("hs.inspect")

module.rules = {
    instructables = {
        filePattern  = "[pP][dD][fF]$",
        xattr        = "com.apple.metadata:kMDItemWhereFroms",
        xattrPattern = "^https://content.instructables.com/pdfs/",
        targetDir    = os.getenv("HOME") .. "/Downloads/Instructable PDFs"
    },
    tedtalk = {
        filePattern  = "[mM][pP]4$",
        xattr        = "com.apple.metadata:kMDItemWhereFroms",
        xattrPattern = "^https://www.ted.com/",
        targetDir    = os.getenv("HOME") .. "/Downloads/TED Talk"
    },
}

module.debug = true

module.scan = function(subDir)
    local dir = sourceDir
    if subDir then dir = dir .. "/" .. subDir end
    local filesToMove = {}
    for file in fs.dir(dir) do
        if not file:match("^%.") then
            for label, details in pairs(module.rules) do
                if not filesToMove[fullPath] then
                    local debugString = label .. ":"
                    local fullPath = dir .. "/" .. file
                    if fullPath:match(details.filePattern) then
                        debugString = debugString .. fullPath
                        local attrs = fs.xattr.get(fullPath, details.xattr)
                        if attrs then
                            attrs = plist.readString(attrs)
                            for _, entry in ipairs(attrs) do
                                if entry:match(details.xattrPattern) then
                                    filesToMove[fullPath] = details.targetDir
                                    break
                                end
                            end
                        end
                        if filesToMove[fullPath] then
                            debugString = debugString .. " moving to " .. details.targetDir
                        else
                            debugString = debugString .. " not a match"
                        end
                        if module.debug then print(debugString) end
                    end
                end
            end
        end
    end

    for file, path in pairs(filesToMove) do print(hs.execute([[mv "]] .. file .. [[" "]] .. path .. [["]])) end
end

module.report = function(subDir)
    local dir = sourceDir
    if subDir then dir = dir .. "/" .. subDir end
    for file in fs.dir(dir) do
        if not file:match("^%.") then
            local fullPath = dir .. "/" .. file
            local attrs = fs.xattr.get(fullPath, "com.apple.metadata:kMDItemWhereFroms")
            attrs = attrs and plist.readString(attrs) or { "** no source found **" }
            print(file, attrs[#attrs])
        end
    end
end

return module
