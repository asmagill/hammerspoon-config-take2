-- todo:
--   add way to set eye position (i.e. angles offset from 0, 0, 0
--   add way to rotate object in x, y, and z
--   add way to specify function for x, y, z (i.e. for sphere wire projection)
--
--   add 4d?

local uitk = require("hs._asm.uitk")
w = uitk.window{x = 100, y = 100, h = 1000, w = 1000 }:show()
c = uitk.element.canvas{}
w:content(c)
c:transformation(uitk.util.matrix.translate(500, 500))

points = {
    {  1,  1,  1 },
    {  1,  1, -1 },
    {  1, -1,  1 },
    {  1, -1, -1 },
    { -1,  1,  1 },
    { -1,  1, -1 },
    { -1, -1,  1 },
    { -1, -1, -1 },
}

-- lines between any two points with only one difference
-- could calculate, but may do more complex shapes later
lines = {
    { 1, 2 },
    { 2, 4 },
    { 4, 3 },
    { 3, 1 },
    { 5, 6 },
    { 6, 8 },
    { 8, 7 },
    { 7, 5 },
    { 1, 5 },
    { 2, 6 },
    { 4, 8 },
    { 3, 7 },
}

zEyeD = 1000

scale = 200

offset = 5

projectXY = function(x, y, z)
    return scale * zEyeD * x / (zEyeD + scale * z + offset), scale * zEyeD * y / (zEyeD + scale * z + offset)
end

plotXY = function()
    for i, v in ipairs(lines) do
        local fromP, toP = points[v[1]], points[v[2]]
        local x1, y1 = projectXY(fromP[1], fromP[2], fromP[3])
        local x2, y2 = projectXY(toP[1], toP[2], toP[3])

        c[i] = {
            type = "segments",
            strokeColor = { white = 0 },
            coordinates = {
                { x = x1, y = y1 },
                { x = x2, y = y2 },
            }
        }
    end
end

plotXY()
