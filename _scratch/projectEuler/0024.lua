local systemTime = hs and hs.timer.secondsSinceEpoch or os.time
local t = systemTime()

local cnt = 0

for i0 = 0, 9, 1 do
  for i1 = 0, 9, 1 do
    if i1 ~= i0 then
      for i2 = 0, 9, 1 do
        if i2 ~= i0 and i2 ~= i1 then
          for i3 = 0, 9, 1 do
            if i3 ~= i0 and i3 ~= i1 and i3 ~= i2 then
              for i4 = 0, 9, 1 do
                if i4 ~= i0 and i4 ~= i1 and i4 ~= i2 and i4 ~= i3 then
                  for i5 = 0, 9, 1 do
                    if i5 ~= i0 and i5 ~= i1 and i5 ~= i2 and i5 ~= i3 and i5 ~= i4 then
                      for i6 = 0, 9, 1 do
                        if i6 ~= i0 and i6 ~= i1 and i6 ~= i2 and i6 ~= i3 and i6 ~= i4 and i6 ~= i5 then
                          for i7 = 0, 9, 1 do
                            if i7 ~= i0 and i7 ~= i1 and i7 ~= i2 and i7 ~= i3 and i7 ~= i4 and i7 ~= i5 and i7 ~= i6 then
                              for i8 = 0, 9, 1 do
                                if i8 ~= i0 and i8 ~= i1 and i8 ~= i2 and i8 ~= i3 and i8 ~= i4 and i8 ~= i5 and i8 ~= i6 and i8 ~= i7 then
                                  for i9 = 0, 9, 1 do
                                    if i9 ~= i0 and i9 ~= i1 and i9 ~= i2 and i9 ~= i3 and i9 ~= i4 and i9 ~= i5 and i9 ~= i6 and i9 ~= i7 and i9 ~= i8 then
                                        cnt = cnt + 1
                                        if cnt == 1000000 then
                                            print(string.format("%d%d%d%d%d%d%d%d%d%d", i0, i1, i2, i3 ,i4, i5, i6, i7, i8, i9))
                                            break
                                        end
                                    end
                                    if cnt == 1000000 then break end
                                  end
                                  if cnt == 1000000 then break end
                                end
                                if cnt == 1000000 then break end
                              end
                              if cnt == 1000000 then break end
                            end
                            if cnt == 1000000 then break end
                          end
                          if cnt == 1000000 then break end
                        end
                        if cnt == 1000000 then break end
                      end
                      if cnt == 1000000 then break end
                    end
                    if cnt == 1000000 then break end
                  end
                  if cnt == 1000000 then break end
                end
                if cnt == 1000000 then break end
              end
              if cnt == 1000000 then break end
            end
            if cnt == 1000000 then break end
          end
          if cnt == 1000000 then break end
        end
        if cnt == 1000000 then break end
      end
      if cnt == 1000000 then break end
    end
    if cnt == 1000000 then break end
  end
  if cnt == 1000000 then break end
end

print(systemTime() - t)
