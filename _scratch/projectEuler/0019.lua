local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- using features of the chosen language...

local secondsPerDay  = 24 * 60 * 60
local secondsPerWeek = 7 * secondsPerDay

-- start at noon on Jan 1, 1901
local timeRecord = os.date("*t", os.time({ day = 1, month = 1, year = 1901, hour = 12 }))

-- now find first Sunday
if timeRecord.wday ~= 1 then
    -- wday == 1 for Sunday, so add seconds for how many days it will take to
    -- get to the next Sunday...
    timeRecord.sec = secondsPerDay * (8 - timeRecord.wday)
    timeRecord = os.date("*t", os.time(timeRecord))
end

local sundaysOnTheFirst = 0

while timeRecord.year < 2001 do
    -- we care about Sunday only if it is on the 1st of the month
    if timeRecord.wday == 1 and timeRecord.day == 1 then
        sundaysOnTheFirst = sundaysOnTheFirst + 1
    end
    -- now get the *next* Sunday and repeat
    timeRecord.sec = secondsPerWeek
    timeRecord = os.date("*t", os.time(timeRecord))
end

print(sundaysOnTheFirst)

print(systemTime() - t)

-- using a more generic approach
--
-- This actually turns out to be faster, surprisingly...

t = systemTime()

local isLeapYear = function(y)
    local isLeap = (y % 4 == 0)
    if (y % 100 == 0) then
        isLeap = (y % 400 == 0)
    end
    return isLeap
end

local daysArray = {
    31, -- Jan
    28, -- Feb
    31, -- Mar
    30, -- Apr
    31, -- May
    30, -- Jun
    31, -- Jul
    31, -- Aug
    30, -- Sep
    31, -- Oct
    30, -- Nov
    31, -- Dec
}

local daysInMonth = function(m, y)
    if m == 2 then
        return daysArray[m] + (isLeapYear(y) and 1 or 0)
    else
        return daysArray[m]
    end
end

local day, month, year = 1, 1, 1900
-- wday will correspond to the current day with 0 = Sunday, so we can just add to it
-- then modulo 7 to get a corrected day of the week
local wday = 1 -- a Monday (given in the description)

sundaysOnTheFirst = 0

-- now jump to next year, the *actual* start of the 20th century
wday, year = (wday + 365 + (isLeapYear(year) and 1 or 0)) % 7, year + 1

while year < 2001 do
    if wday == 0 then
        sundaysOnTheFirst = sundaysOnTheFirst + 1
    end

    wday, month = (wday + daysInMonth(month, year)) % 7, month + 1
    if month == 13 then
        month, year = 1, year + 1
    end
end

print(sundaysOnTheFirst)

print(systemTime() - t)
