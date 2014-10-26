local m = {}

m.f = function(a, b)
    if a == 'a' and b == 'b' then
        return 'nothing', 'sec' .. 'ret', 'nothing'
    end
end

return m

