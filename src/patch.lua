require("resty.core")

-- patches base on KONG
local function patch()
    do -- implement `sleep` in the `init_worker` context
        -- initialization code regularly uses the shm and locks.
        -- the resty-lock is based on sleeping while waiting, but that api
        -- is unavailable. Hence we implement a BLOCKING sleep, only in
        -- the init_worker context.
        local get_phase = ngx.get_phase
        local ngx_sleep = ngx.sleep
        local alternative_sleep = require("socket").sleep

        -- luacheck: globals ngx.sleep
        ngx.sleep = function(s)
            if get_phase() == "init_worker" then
                ngx.log(ngx.WARN, "executing a blocking 'sleep' (", s, " seconds)")
                return alternative_sleep(s)
            end
            return ngx_sleep(s)
        end
    end

    do -- randomseeding patch for: cli, rbusted and OpenResty
        --- Seeds the random generator, use with care.
        -- Once - properly - seeded, this method is replaced with a stub
        -- one. This is to enforce best-practices for seeding in ngx_lua,
        -- and prevents third-party modules from overriding our correct seed
        -- (many modules make a wrong usage of `math.randomseed()` by calling
        -- it multiple times or by not using unique seeds for Nginx workers).
        --
        -- This patched method will create a unique seed per worker process,
        -- using a combination of both time and the worker's pid.
        local util = require "arcturus.utils.basic"
        local seeds = {}
        local randomseed = math.randomseed

        _G.math.randomseed = function()
            local seed = seeds[ngx.worker.pid()]
            if not seed then
                if ngx.get_phase() ~= "init_worker" then
                    ngx.log(ngx.ERR, debug.traceback("math.randomseed() must be " .. "called in init_worker context", 2))
                end

                local bytes, err = util.get_rand_bytes(8)
                if bytes then
                    ngx.log(ngx.DEBUG, "seeding PRNG from OpenSSL RAND_bytes()")

                    local t = {}
                    for i = 1, #bytes do
                        local byte = string.byte(bytes, i)
                        t[#t + 1] = byte
                    end
                    local str = table.concat(t)
                    if #str > 12 then
                        -- truncate the final number to prevent integer overflow,
                        -- since math.randomseed() could get cast to a platform-specific
                        -- integer with a different size and get truncated, hence, lose
                        -- randomness.
                        -- double-precision floating point should be able to represent numbers
                        -- without rounding with up to 15/16 digits but let's use 12 of them.
                        str = string.sub(str, 1, 12)
                    end
                    seed = tonumber(str)
                else
                    ngx.log(ngx.ERR, "could not seed from OpenSSL RAND_bytes, seeding ", "PRNG with time and worker pid instead (this can ", "result to duplicated seeds): ", err)

                    seed = ngx.now() * 1000 + ngx.worker.pid()
                end

                ngx.log(ngx.DEBUG, "random seed: ", seed, " for worker nb ", ngx.worker.id())

                local ok, err = ngx.shared.system:safe_set("pid: " .. ngx.worker.pid(), seed)
                if not ok then
                    ngx.log(ngx.WARN, "could not store PRNG seed in kong shm: ", err)
                end

                randomseed(seed)
                seeds[ngx.worker.pid()] = seed
            else
                ngx.log(ngx.DEBUG, debug.traceback("attempt to seed random number " .. "generator, but already seeded with: " .. tostring(seed), 2))
            end

            return seed
        end
    end
end
return function()
    return patch()
end
