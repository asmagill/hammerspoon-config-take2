local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

-- Notes:
--  1. For M rows, we actually have M + 1 vertices in that row
--  2. Same for columns. Eg:   .--.--.--.
--                             |  |  |  |
--                             .--.--.--.
--                             |  |  |  |
--                             .--.--.--.
--                             |  |  |  |
--                             .--.--.--.
--   3. At ending vertex, there are 0 possible routes
--   4. At edge (furthest right and furthest down) vertices, we have 1 possible route
--   5. Other vertices are the sum of the possible routes of the vertex immediately to the
--       right and immediately below

gridWalk = function(M, N)
    N = N or M
    local matrix = {}
    local verticesPerRow = M + 1
    local verticesPerCol = N + 1

    for i = 1, verticesPerRow, 1 do matrix[i] = {} end

    -- Note 3
    matrix[verticesPerRow][verticesPerCol] = 0

    -- Note 4
    for i = 1, verticesPerRow, 1 do matrix[i][verticesPerCol] = 1 end
    for i = 1, verticesPerCol, 1 do matrix[verticesPerRow][i] = 1 end

    -- Note 5
    for i = verticesPerRow - 1, 1, -1 do
        for j = verticesPerCol - 1, 1, -1 do
            matrix[i][j] = matrix[i + 1][j] + matrix[i][j + 1]
        end
    end

    return matrix[1][1]
end

print(gridWalk(20))

print(systemTime() - t)
