
local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function(narr, nrec)
        return {}
    end
end

local _M = {}

function _M.init()
    require("arcturus.patch")()
    
end

function _M.new()
    -- statements
end
function _M.run(arcturus)
    -- statements
end

return _M