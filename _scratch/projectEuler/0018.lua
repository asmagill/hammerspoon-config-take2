local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local triangle = {
                                { 75 },
                              { 95, 64 },
                            { 17, 47, 82 },
                          { 18, 35, 87, 10 },
                        { 20, 04, 82, 47, 65 },
                      { 19, 01, 23, 75, 03, 34 },
                    { 88, 02, 77, 73, 07, 63, 67 },
                  { 99, 65, 04, 28, 06, 16, 70, 92 },
                { 41, 41, 26, 56, 83, 40, 80, 70, 33 },
              { 41, 48, 72, 33, 47, 32, 37, 16, 94, 29 },
            { 53, 71, 44, 65, 25, 43, 91, 52, 97, 51, 14 },
          { 70, 11, 33, 28, 77, 73, 17, 78, 39, 68, 17, 57 },
        { 91, 71, 52, 38, 17, 14, 91, 43, 58, 50, 27, 29, 48 },
      { 63, 66, 04, 68, 89, 53, 67, 30, 73, 16, 69, 87, 40, 31 },
    { 04, 62, 98, 27, 23, 09, 70, 98, 73, 93, 38, 53, 60, 04, 23 },
}

-- works, but requires 2^n steps -- won't scale when number of rows is large
--
-- local valueAtCoordinate = function(m, n)
--     return (triangle[m] or {})[n]
-- end
--
-- local currentMax = 0
--
-- traverse = function(m, n, currentSum)
--     m = m or 1
--     n = n or 1
--     currentSum = (currentSum or 0) + valueAtCoordinate(m, n)
--     local left, right = valueAtCoordinate(m + 1, n), valueAtCoordinate(m + 1, n + 1)
--
--     if left or right then
--         if left then
--             traverse(m + 1, n, currentSum)
--         end
--         if right then
--             traverse(m + 1, n + 1, currentSum)
--         end
--     else
--         currentMax = math.max(currentMax, currentSum)
--     end
-- end
--
-- traverse()
-- print(currentMax)

-- better -- traverses each row only once, shrinking the scratch space as it goes
--
bottomsUp = function()
    -- initial scratch pad is last row of triangle
    local scratch = triangle[#triangle]

    -- now iterate from the second to last row *up* to the first
    for i = #triangle - 1, 1, -1 do
        local newScratch = {}
        -- since scratch is the last line of an i+1 row triangle, we "create" the
        -- i'th row by adding the actual triangle value to the largest of the two
        -- directly beneath it (i.e. the row currently in scratch)
        for j = 1, #triangle[i], 1 do
            newScratch[j] = triangle[i][j] + math.max(scratch[j], scratch[j + 1])
        end
        scratch = newScratch
    end

    return scratch[1]
end

print(bottomsUp())
print(systemTime() - t)
