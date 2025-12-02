local M = {}

function M.into(seconds)
        local ms = math.floor((seconds % 1) * 1000)
        local s = math.floor(seconds)
        local m = math.floor(s / 60)
        local h = math.floor(m / 60)
        local d = math.floor(h / 24)

        s = s % 60
        m = m % 60
        h = h % 24

        if d > 0 then
                return ("%02d:%02d:%02d:%02d.%03d"):format(d, h, m, s, ms)
        elseif h > 0 then
                return ("%02d:%02d:%02d.%03d"):format(h, m, s, ms)
        elseif m > 0 then
                return ("%02d:%02d.%03d"):format(m, s, ms)
        else
                return ("%d.%03d"):format(s, ms)
        end
end

return M
