-- Quick & Dirty Ugly XML parser
--
--  I like JSON. It's well understood, has a simple layout, maps nicely to lua data types...
--  XML doesn't. But some web enabled devices still use XML though its probably bloated
--  overkill for what they really need (<cough>Roku</cough>)... but I'm stuck with using it...
--
-- Based on XML specifications as described at https://www.w3schools.com/xml/xml_syntax.asp
--
-- Known limitations
--    minimally tested
--    will probably barf on UTF-8 in tag names or attributes.
--        Should be ok for entity values though.
--    just parses tags, attributes, and entity values... no validation, no DTDs no nutten but the
--        bare minimum
--    does not fail gracefully when presented with bad (i.e. not well formed) XML
--

local module = {}
module._version = "0.0.1"

local NAME_PATTERN = "[%a_][%a%d%-%._:]*"

local decodeEntities = function(val)
    return (val:gsub("&(%w+);", {
        lt   = "<",
        gt   = ">",
        amp  = "&",
        apos = "'",
        quot = '"',
    }))
end

local elementMetatable = {
    tag   = function(self) return getmetatable(self)._tag end,
    value = function(self)
        local v = getmetatable(self)._value
        return type(v) == "string" and v or nil
    end,
    children = function(self)
        local v = getmetatable(self)._value
        return type(v) == "table" and v or {}
    end,
}

local elementCall = function(self, key)
    if type(key) == "number" and math.type(key) == "integer" then
        return self:children()[key]
    elseif type(key) == "string" then
        local results = {}
        for _,v in ipairs(self:children()) do
            if v:tag() == key then
                table.insert(results, v)
            end
        end
        return results
    else
        return nil
    end
end

local elementIndex = function(self, key)
    if elementMetatable[key] then
        return elementMetatable[key]
    elseif type(key) == "number" and math.type(key) == "integer" then
        return elementCall(self, key)
    else
        return nil
    end
end

local parseSegment
parseSegment = function(xmlString)
    if not xmlString:match("<") then
        return decodeEntities(xmlString)
    end

    local result = {}

    local pos = 1
    while (pos < #xmlString) do
        local workingString = xmlString:sub(pos)

        local tag, attrs, closing = workingString:match("^%s*<(" .. NAME_PATTERN .. ")%s*([^/>]-)%s*(/?>)")
        if not tag then
            error("tag malformed in " .. workingString)
        elseif tag:match("^[xX][mM][lL]") then
            error("tag cannot start with the letters 'xml': " .. tag)
        end

        local entity = {}

        local aPos = 1
        while (aPos < #attrs) do
            local s, e = attrs:find(NAME_PATTERN, aPos)
            local a = attrs:sub(s, e)
            aPos = e + 1
            s, e = attrs:find("['\"]", aPos)
            local q = attrs:sub(s, e)
            aPos = e + 1
            s, e = attrs:find(q, aPos)
            local v = attrs:sub(aPos, e - 1)
            aPos = e + 1
            entity[a] = decodeEntities(v)
        end

        local s, e = workingString:find(closing)

        local value

        if closing ~= "/>" then
            local start = e + 1
            s, e = workingString:find("<%s*/" .. tag:gsub("%-", "%%-") .. "%s*>", start)
            pos = pos + e + 1
            value = parseSegment(workingString:sub(start, s - 1))
        else
            value = ""
            pos = pos + e + 1
        end

        table.insert(result, setmetatable(entity, {
            _tag       = tag,
            _value     = value,
            __index    = elementIndex,
            __call     = elementCall,
            __tostring = function(self) return "xmlNode: " .. self:tag() .. " (" .. tostring(#self) .. ")" end,
            __len      = function(self) return #self:children() end,
        }))
    end

    return result
end

module.parseXML = function(xmlString)
    assert(type(xmlString) == "string", "input must be a string")

    if xmlString:match("^[\r\n]*<%?xml") then -- purge prolog if present
        xmlString = xmlString:match("^[\r\n]*<%?xml.-%?>[\r\n]*(.*)$")
    end
    xmlString = xmlString:gsub("<!%-%-.-%-%->", "") -- purge comments

    return parseSegment(xmlString)[1]
end

module.entityValue = function(entity)
    -- Simplifies upstream logic from:
    --        a = #xml.parseXML(txt)("tag")[n] and xml.parseXML(txt)("tag")[n]:value() or nil
    -- to just:
    --        a = xml.entityValue(xml.parseXML(txt)("tag")[n])
    if entity and getmetatable(entity).__index == elementIndex then
        return entity:value()
    else
        return nil
    end
end

return module
