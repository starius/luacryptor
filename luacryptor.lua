
function cleanSource(src)
    src = src:gsub("function ([%w_%.]+):([%w_]+)%(%)", "%1.%2 = function(self)")
    src = src:gsub("function ([%w_%.]+):([%w_]+)%(", "%1.%2 = function(self,")
    src = src:gsub("function ([%w_%.]+)%(", "%1 = function(")
    return src
end

