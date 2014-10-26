local m = {}

m.ret = function()
    return 'ret'
end

m.f = function(a, b)
    if a == 'a' and b == 'b' then
        return 'nothing', 'sec' .. m.ret(), 'nothing'
    end
end

return m

