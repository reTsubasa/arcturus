-- utility funcitons
-- Parts of one from KONG @module kong.tools.utils
local cjson = require("cjson.safe")
local dkjson = require("dkjson")
local pl_path = require("pl.path")
local pl_dir = require("pl.dir")
local pl_utils = require ("pl.utils")
local log = require("arcturus.utils.log").log
local uuid = require("resty.jit-uuid")
local ffi = require("ffi")
local pl_stringx = require ("pl.stringx")
local system_constants = require ("lua_system_constants")

local C = ffi.C
local ffi_fill = ffi.fill
local ffi_new = ffi.new
local ffi_str = ffi.string
local type = type
local pairs = pairs
local ipairs = ipairs
local select = select
local tostring = tostring
local sort = table.sort
local concat = table.concat
local insert = table.insert
local lower = string.lower
local fmt = string.format
local find = string.find
local gsub = string.gsub
local split = pl_stringx.split
local strip = pl_stringx.strip
local re_find = ngx.re.find
local re_match = ngx.re.match
local DEBUG = ngx.DEBUG
local WARN = ngx.WARN

ffi.cdef [[
typedef unsigned char u_char;

int gethostname(char *name, size_t len);

int RAND_bytes(u_char *buf, int num);

unsigned long ERR_get_error(void);
void ERR_load_crypto_strings(void);
void ERR_free_strings(void);

const char *ERR_reason_error_string(unsigned long e);

int open(const char * filename, int flags, int mode);
size_t read(int fd, void *buf, size_t count);
int write(int fd, const void *ptr, int numbytes);
int close(int fd);
char *strerror(int errnum);
]]

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

--- Retrieves the hostname of the local machine
-- @return string  The hostname
function _M.get_hostname()
    local result
    local SIZE = 128

    local buf = ffi_new("unsigned char[?]", SIZE)
    local res = C.gethostname(buf, SIZE)

    if res == 0 then
        local hostname = ffi_str(buf, SIZE)
        result = gsub(hostname, "%z+$", "")
    else
        local f = io.popen("/bin/hostname")
        local hostname = f:read("*a") or ""
        f:close()
        result = gsub(hostname, "\n$", "")
    end

    return result
end

-- Retrieves the machine CPU core number
function _M.get_cpu_core()
    local ok, _, stdout = pl_utils.executeex("getconf _NPROCESSORS_ONLN")
    if ok then
        return stdout
    end
    return nil,"Retrieves cpu number failed"
end

-- Retrieves uname
function _M.get_uname()
    local ok,_,stdout = pl_utils.executeex("uname -a")
    if ok then
        return stdout
    end
    return nil,"Retrieves uname failed"
end


local function urandom_bytes(buf, size)
    local O_RDONLY = system_constants.O_RDONLY()

    local fd = ffi.C.open("/dev/urandom", O_RDONLY, 0) -- mode is ignored
    if fd < 0 then
      log(WARN, "Error opening random fd: ",
                    ffi_str(ffi.C.strerror(ffi.errno())))

      return false
    end

    local res = ffi.C.read(fd, buf, size)
    if res <= 0 then
        log(WARN, "Error reading from urandom: ",
                    ffi_str(ffi.C.strerror(ffi.errno())))

      return false
    end

    if ffi.C.close(fd) ~= 0 then
        log(WARN, "Error closing urandom: ",
                    ffi_str(ffi.C.strerror(ffi.errno())))
    end

    return true
  end

-- Get random bytes
function _M.get_rand_bytes(n_bytes,urandom)
    local bytes_buf_t = ffi.typeof "char[?]"

    local buf = ffi_new(bytes_buf_t, n_bytes)
    ffi_fill(buf, n_bytes, 0x0)

    -- only read from urandom if we were explicitly asked
    if urandom then
      local rc = urandom_bytes(buf, n_bytes)

      -- if the read of urandom was successful, we returned true
      -- and buf is filled with our bytes, so return it as a string
      if rc then
        return ffi_str(buf, n_bytes)
      end
    end

    if C.RAND_bytes(buf, n_bytes) == 0 then
      -- get error code
      local err_code = C.ERR_get_error()
      if err_code == 0 then
        return nil, "could not get SSL error code from the queue"
      end

      -- get human-readable error string
      C.ERR_load_crypto_strings()
      local err = C.ERR_reason_error_string(err_code)
      C.ERR_free_strings()

      return nil, "could not get random bytes (" ..
                  "reason:" .. ffi_str(err) .. ") "
    end

    return ffi_str(buf, n_bytes)
  end
return _M
