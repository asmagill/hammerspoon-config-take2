-- this is wrong somehow: s = hs.socket.udp.new(function(d,a) print(hs.utf8.hexDump(d), finspect(hs.socket.parseAddress(a))) end):send(d.buildQuery("_services._dns-sd._udp.local", "PTR", "IN"), "10.0.1.1", 5353):receive()

-- s = hs.socket.udp.server(43267, function(d,a) print(hs.utf8.hexDump(d), finspect(hs.socket.parseAddress(a))) end):receive()
-- s:send(d.buildQuery("_services._dns-sd._udp.local", "PTR", "IN"), "10.0.1.1", 5353)

local module = {}

local socket = require("hs.socket")
local utf8   = require("hs.utf8")

local QTYPE = {
    ["A"]     =   1,
    ["NS"]    =   2,
    ["MD"]    =   3,
    ["MF"]    =   4,
    ["CNAME"] =   5,
    ["SOA"]   =   6,
    ["MB"]    =   7,
    ["MG"]    =   8,
    ["MR"]    =   9,
    ["NULL"]  =  10,
    ["WKS"]   =  11,
    ["PTR"]   =  12,
    ["HINFO"] =  13,
    ["MINFO"] =  14,
    ["MX"]    =  15,
    ["TXT"]   =  16,
    ["AXFR"]  = 252,
    ["MAILB"] = 253,
    ["MAILA"] = 254,
    ["*"]     = 255,
}

local QCLASS = {
    ["IN"] =   1,
    ["CS"] =   2,
    ["CH"] =   3,
    ["HS"] =   4,
    ["*"]  = 255,
}

local lastID = math.random(0, 65535)

local buildQuery = function(what,typ,cls,rec,inv)
    rec = rec or false
    inv = inv or false

    local id = lastID
    lastID = (lastID + 1) % 65536

--     MSB                                           LSB
--                                     1  1  1  1  1  1
--       0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                      ID                       |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |QR|   Opcode  |AA|TC|RD|RA|   Z    |   RCODE   |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                    QDCOUNT                    |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                    ANCOUNT                    |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                    NSCOUNT                    |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                    ARCOUNT                    |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

    local queryBuffer = ""
    queryBuffer = queryBuffer .. string.char((id >> 8) & 0xff, id & 0xFF)
    queryBuffer = queryBuffer .. string.char(0 + (inv and 1 or 0) << 3 + (rec and 1 or 0), 0)
    queryBuffer = queryBuffer .. string.char(0, 1)
    queryBuffer = queryBuffer .. string.char(0, 0)
    queryBuffer = queryBuffer .. string.char(0, 0)
    queryBuffer = queryBuffer .. string.char(0, 0)

--                                     1  1  1  1  1  1
--       0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                                               |
--     /                     QNAME                     /
--     /                                               /
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                     QTYPE                     |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
--     |                     QCLASS                    |
--     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

    if what:sub(#what) ~= "." then what = what .. "." end
    for part in what:gmatch("([^.]*)%.") do
        queryBuffer = queryBuffer .. string.char(#part) .. part
    end
    queryBuffer = queryBuffer .. string.char(0)
    local t,c = QTYPE[typ], QCLASS[cls]
    if not t then error("invalid type") end
    if not c then error("invalid class") end
    queryBuffer = queryBuffer .. string.char((t >> 8) & 0xff, t & 0xFF)
    queryBuffer = queryBuffer .. string.char((c >> 8) & 0xff, c & 0xFF)

    return queryBuffer
end

module.buildQuery = buildQuery

return module
