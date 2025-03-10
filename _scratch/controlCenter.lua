-- get info about control center
-- disappointing, as a lot of attributes error with "has no value" suggesting Apple is
-- limiting access, but I may look closer in the future.
--
-- see HS issue #3713

ap = hs.application("Control Center")
apx = hs.axuielement.applicationElement(ap)

apx:elementSearch(function(m, r, c)
    if m == "completed" then
        if c == 1 then
            r[1]:doAXPress()
            t = hs.timer.doAfter(2, function()
                f = apx:elementSearch(function(m2, r2, c2)
                    if m2 == "completed" then
                        r[1]:doAXPress() -- close control center
                        hs.console.clearConsole()
                        print(hs.inspect(r2))
                    end
                end, { objectOnly = false })
                t = nil
            end)
        else
            print("criteria not specific correct: expected 1 result, found " .. tostring(c))
        end
    -- else search not complete
    end
end, hs.axuielement.searchCriteriaFunction({ attribute = "AXIdentifier", value = "com.apple.menuextra.controlcenter" }))
