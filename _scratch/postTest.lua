local http       = require("hs.http")
local httpserver = require("hs.httpserver")
local utf8       = require("hs.utf8")

local serverPort = math.floor(math.sqrt(2) * 10000) -- I'm a math nerd

local module    = {}
local _holding  = {}
module._holding = _holding

module.server = httpserver.new():setName("HTTPSERVER Test for #2059")
                                :setPort(serverPort)
                                :setCallback(function(typ, path, headers, body)
                                    local responseBody = typ .. ": " .. path .. "\n"
                                    for k, v in pairs(headers) do
                                        responseBody = responseBody .. k .. " = " .. v .. "\n"
                                    end
                                    responseBody = responseBody .. "\n" .. utf8.hexDump(body)
                                    print(string.rep("*", 80))
                                    print("Server Output -- ")
                                    print(responseBody)
                                    print(string.rep("*", 80))
                                    return responseBody, 200, {}
                                end):start()

module.post = function(text)
    local uniqueID = tostring(math.random(999999))
    -- we store the request in _holding to ensure garbage collection doesn't end it prematurely
    _holding[uniqueID] = http.asyncPost("http://localhost:" .. serverPort .. "/postTest",
                                        text,
                                        nil,
                                        function(code, body, headers)
                                            print(string.rep("*", 80))
                                            print("Request Output -- " .. tostring(code))
                                            for k,v in pairs(headers or {}) do
                                                print(k .. " = " .. v)
                                            end
                                            print(body)
                                            print(string.rep("*", 80))
                                            _holding[uniqueID] = nil -- now allow gc to do its thing
                                        end)
end

return module
