-- arcturus
local log = require("arcturus.utils.log")
local basic = require("arcturus.utils.basic")
local settings = require("arcturs.conf.settings")
local collector = require("arcturs.collector")

local DEBUG = ngx.DEBUG

local get_phase = ngx.get_phase

local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function(narr, nrec)
        return {}
    end
end

local _M = {_VERSION = "0.1.0"}
local mt = {__index = _M}

function _M.init()
    -- STEP0 Patch
    require("arcturus.patch")()

    -- STEP1 Pre_init check

    -- other init
end

function _M.new()
    local ctx = ngx.ctx.arcturus or tab_new(10, 64)

    if ctx.mode then
        log(DEBUG, "Got ctx.Run mode:" .. ctx.mode)
        return ctx
    end

    -- init ctx value
    ctx = {
        arcturus_id = basic.uuid(),
        path = settings.path,
        mode = settings.mode,
        pcre = settings.pcre,
        arcturus_version = _M._VERSION,
        req = {},
        resp = {}
    }
    return setmetatable(ctx, mt)
end
function _M.run(ctx)
    if ctx.mode == "bypass" then
        return
    end

    -- fetch req args by phase
    local current_phase = get_phase()
    collector.fetch(ctx, current_phase)

    -- run plugins in currnet phase
end

return _M
