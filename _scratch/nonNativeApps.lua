local spotlight = require("hs.spotlight")
local inspect   = require("hs.inspect")

local finspect = function(...)
    local args = table.pack(...)
    if args.n == 1 then args = args[1] else args.n = nil end
    return inspect(args, { newline = " ", indent = "" })
end

-- allow me to specify another architecture before loading this file via dofile
-- e.g. `_arch = "x86_64" ; dofile("_scratch/nonNativeApps.lua")` will list apps
-- that can't run on 64bit intel architecture (and clears _arch variable)
local arch = _arch or hs.execute("arch")
_arch = nil

local query
query = hs.spotlight.new():queryString([[
    kMDItemContentType == "com.apple.application-bundle" &&
    kMDItemExecutableArchitectures != "]] .. arch .. [["
]]):callbackMessages("didFinish") -- technically not necessary, but reminder that other opts exist
   :setCallback(function(obj, msg, info)
        if msg == "didFinish" then
            local paths = {}
            for _, v in ipairs(obj) do
                table.insert(paths, {
                    v.kMDItemDisplayName,
                    v.kMDItemExecutableArchitectures
                })
            end
            table.sort(paths, function(a, b)
                return tostring(a[1]):upper() < tostring(b[1]):upper()
            end)
            for _, v in ipairs(paths) do print(v[1], finspect(v[2])) end
            obj:stop()
            query = nil
        end
    end)
   :start()
