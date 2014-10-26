local m = {}

m.ret = function()
    return m.vvv
end

m.f = function(a, b)
    m.vvv = 'ret'
    if a == 'a' and b == 'b' then
        return 'nothing', 'sec' .. m.ret(), 'nothing'
    end
end

return m

