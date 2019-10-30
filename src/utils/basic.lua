local cjson = require("cjson.safe")
local dkjson = require("dkjson")
local pl_path = require("pl.path")
local pl_dir = require("pl.dir")
local log = require("arcturus.utils.log").log
local uuid = require("resty.jit-uuid")

local fmt = string.format
local DEBUG = ngx.DEBUG

local _M = {}

-- write then content to the position
-- @string position the abs_path of file
-- @param content the info write to file,if content type is a table,this will auto translate to json file
-- @table opts control the write behavior,like mode,pp(pretty_print),etc)
function _M.write(position, content, opts)
    if not opts then
        opts = {}
    end

    local mode = opts.mode or "w+"
    local file = io.open(position, mode)
    if not file then
        return nil, fmt("Write file failed,path: %s", position)
    else
        if type(content) == "table" then
            if opts.pp then
                content = dkjson.encode(content, {indent = true})
            else
                content = cjson.encode(content)
            end
        end

        file:write(content)
        file:close()
    end
    return true
end

-- read file by given path from local disk
-- @string postion abs_path of the file
local function read(position)
    local file = io.open(position, "r")
    if file then
        local text = file:read("*a")
        file:close()
        return text
    end
    return nil, fmt("Read file failed,path: %s", position)
end
_M.read = read

-- read json file,by given path,return a table on succ
-- nil,with err message if failed
-- todo:return the read file's md5 as second return
local function read_json(p)
    local t, e = read(p)
    if not t then
        return nil, e
    end
    local r, e = cjson.decode(t)
    if not r then
        return nil, e
    end
    return r
end
_M.read_json = read_json

-- normlize the give file path
local function normpath(path)
    if (not path) or type(path) ~= "string" then
        return nil, "Input arg path type must be string"
    end
    return pl_path.normpath(path)
end
_M.normpath = normpath

-- check if the given path exist.path can both file and directory
local function exists(path)
    if (not path) or type(path) ~= "string" then
        return nil, "Input arg path type must be string"
    end
    local e = pl_path.exists(path)
    if not e then
        return nil, "Path not exist"
    end
    return true
end
_M.exists = exists

-- is this a file?
local function isfile(path)
    if (not path) or type(path) ~= "string" then
        return nil, "Input arg path type must be string"
    end
    local e = pl_path.isfile(path)
    if not e then
        return nil, "Given path is not a file"
    end
    return true
end
_M.isfile = isfile

-- is this a directory?
local function isdir(path)
    if (not path) or type(path) ~= "string" then
        return nil, "Input arg path type must be string"
    end
    local e = pl_path.isdir(path)
    if not e then
        return nil, "Given path is not a directory"
    end
    return true
end
_M.isdir = isdir

-- is this an absolute path?
local function isabs(path)
    if (not path) or type(path) ~= "string" then
        return nil, "Input arg path type must be string"
    end
    return pl_path.isabs(path)
end
_M.isabs = isabs

-- given a path, return the directory part and a file part.
-- if there’s no directory part, the first value will be empty
local function splitpath(path)
    if (not path) or type(path) ~= "string" then
        return nil, "Input arg path type must be string"
    end
    return pl_path.splitpath(path)
end
_M.splitpath = splitpath

--- give write permition for give path file
-- this function should always use in phase "init"
-- due the worker run as nobody ,this function may not work in other phase
local function chmod_file(abs_path)
    local cmd = fmt("chmod a+w %s", abs_path)
    local code = os.execute(cmd)
    if (not code) then
        return nil, fmt("Chmod file %s a+w failed", abs_path)
    end
    if type(code) == "number" and code ~= 0 then
        return nil, fmt("Chmod file %s a+w failed", abs_path)
    end
    return true
end

-- create the file by give file's absolute path
-- and add file permittion to "a+w"
local function create_file(abs)
    if (not abs) or type(abs) ~= "string" then
        return nil, "Input arg path type must be string"
    end

    abs = normpath(abs)

    local ok = _M.isabs(abs)
    if not ok then
        return nil, "Given path not a absolute path"
    end

    local d, f = splitpath(abs)
    if not exists(d) then
        -- create directory
        local ok, err = pl_dir.makepath(d)
        log(DEBUG, ok, err)
        if not ok then
            return nil, err
        end
    end
    local cmd = fmt("touch %s", abs)
    local code = os.execute(cmd)
    log(DEBUG, cmd, code, type(code))

    if (not code) then
        return nil, "Create file failed path " .. abs
    end
    if type(code) == "number" and code ~= 0 then
        return nil, "Create file failed path " .. abs
    end
    log(DEBUG, "Create file succ")

    return chmod_file(abs)
end
_M.create_file = create_file

-- gen a uuid
-- should always install the dependence lua_system_constants and enable the  lua_code_cache
-- to get the random seed.Deatail at: https://github.com/thibaultcha/lua-resty-jit-uuid
function _M.uuid()
    return uuid()
end

return _M
