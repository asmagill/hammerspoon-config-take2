
--- === HaveIBeenPwned ===
---
--- Perform queries about email addresses and passwords against the data breaches which have been consolidated at https://haveibeenpwned.com/ to determine if you have an account which may have been compromised in a known data breach.
---
--- You can read more at https://haveibeenpwned.com/
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config/trunk/_Spoons/PwnedPasswords.spoon`

-- local logger  = require("hs.logger")

local obj    = {
-- Metadata
    name      = "HaveIBeenPwned",
    version   = "0.1",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config/tree/master/_Spoons/HaveIBeenPwned.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = debug.getinfo(1, "S").source:match("^@(.+/).+%.lua$"),
}
local metadataKeys = {} ; for k, v in require("hs.fnutils").sortByKeys(obj) do table.insert(metadataKeys, k) end

local checkPasswordURL = "https://api.pwnedpasswords.com/range/"
local checkOtherURL    = "https://haveibeenpwned.com/api/v2/"
local userAgent        = "Hammerspoon-" .. obj.name .. "-v" .. obj.version

local http  = require("hs.http")
local timer = require("hs.timer")
local host  = require("hs.host")
local hash  = require("hs.hash")

obj.__index = obj

-- for timers when we add other queries so they don't get collected
obj.__internals = {}

--- HaveIBeenPwned:checkPassword(password, fn)
--- Method
--- Check a password against the Pwned Passwords repository collected at https://haveibeenpwned.com.
---
--- Parameters:
---  * `password` - A string specifying the password to check for in recorded data breaches.
---  * `fn`       - a callback function to receive the results of the query. Specifying this parameter performs the query in an asynchronous (non-blocking) manner.
---    * The callback function should expect 1 argument: an integer specifying the number of times the password was found to be present in the consolidated data breaches (0 means that the password was not found); otherwise a string specifying the error that occurred.
---
--- Returns:
---  * None
---
--- Notes:
---  * This spoon takes advantage of "Cloudflare, Privacy and k-Anonymity" as outlined at https://www.troyhunt.com/ive-just-launched-pwned-passwords-version-2/#cloudflareprivacyandkanonymity so that no password, even in hashed form, is ever sent over the internet in a way that it could be reversed or logged.
---
---  * If a specified password returns a number greater then 0, it does not mean that your specific use of the password has been compromised; it means that the password has been used by *someone* who has been compromised and may find its way into a dictionary of passwords to attempt when trying to crack passwords so you should consider changing your password to something more secure.
obj.checkPassword = function(self, password, callback)
    -- correct if they called this as a function
    if type(self) == "string" then self, password, callback = obj, self, password end
    assert(type(password) == "string", "expected a string for the password")
    assert(type(callback) == "function" or (getmetatable(callback) or {}).__call, "expected a function for the callback")

    local hashedPassword = hash.SHA1(password):upper()
    local hashedPrefix   = hashedPassword:sub(1,  5)
    local hashedSuffix   = hashedPassword:sub(6, -1)
    http.asyncGet(
        checkPasswordURL .. hashedPrefix,
        { ["User-Agent"] = userAgent },
        function(status, body, headers)
            if status == 200 then
                local qty = 0
                for suffix, count in string.gmatch(body, "([A-F0-9]+):([0-9]+)[\r\n]*") do
                    if suffix:upper() == hashedSuffix then
                        qty = tonumber(count)
                        break
                    end
                end
                callback(qty)
            else
                callback(body or tostring(status) .. " status code")
            end
        end
    )
end

return setmetatable(obj, {
    __tostring = function(self)
        local result, fieldSize = "", 0
        for i, v in ipairs(metadataKeys) do fieldSize = math.max(fieldSize, #v) end
        for i, v in ipairs(metadataKeys) do
            result = result .. string.format("%-"..tostring(fieldSize) .. "s %s\n", v, self[v])
        end
        return result
    end,
})
