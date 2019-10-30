local errlog = require("ngx.errlog")

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
-- local DEBUG = ngx.DEBUG

-- local up = string.upper
-- local s_find = string.find
-- local sub = string.sub
local fmt = string.format

local insert = table.insert
local concat = table.concat

-- local LOG_EMERG = 0 --  system is unusable
-- local LOG_ALERT = 1 --  action must be taken immediately
-- local LOG_CRIT = 2 --  critical conditions
-- local LOG_ERR = 3 --  error conditions
-- local LOG_WARNING = 4 --  warning conditions
-- local LOG_NOTICE = 5 --  normal but significant condition
-- local LOG_INFO = 6 --  informational
-- local LOG_DEBUG = 7 --  debug-level messages

local _M = {}

function _M.set_log_level(level)
    if type(level) ~= "number" then
        return nil, fmt("log level must be a number,input type: %s", type(level))
    end
    local s, err = errlog.set_filter_level(level)
    if not s then
        log(ERR, "set log level failed: ", err)
        return nil, fmt("set log level failed: ", err)
    end
    _M.log(INFO, fmt("set log level: %s", level))
    return true
end

function _M.get_logs(max)
    max = max or 20
    if type(max) ~= "number" then
        return nil, fmt("type of the logs to getback must be a number,input type: %s", type(max))
    end
    local res = errlog.get_logs(max)
    local logs = {}
    for i = 1, #res, 3 do
        local level = res[i]
        if not level then
            break
        end

        local time = res[i + 1]
        local msg = res[i + 2]
        insert(logs, {level = level, time = time, msg = msg})
    end
    return logs
end

function _M.log(lvl, ...)
    -- log to error logs with our custom prefix, stack level
    -- and separator
    local n = select("#", ...)
    local t = {...}
    local info = debug.getinfo(2)

    local prefix = fmt("(%s),line:%d:", info.short_src, info.currentline)
    local buf = {prefix}

    for i = 1, n do
        buf[i + 1] = tostring(t[i])
    end

    local msg = concat(buf, " ")

    errlog.raw_log(lvl, msg)
end

return _M
