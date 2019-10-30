package = "arcturus"
version = "scm-1"
source = {
  tag = "master",
  url = "https://github.com/reTsubasa/arcturus.git",
}
description = {
  summary  = "A indicator to the road of openresty",
  detailed = [[
    Driven by great OpenResty
  ]],
  homepage = "https://github.com/reTsubasa/arcturus",
  license  = "MIT"
}
dependencies = {
  "lua-resty-mlcache == 2.4.0-1",	
  "dkjson == 2.5-2",
  "penlight  == 1.7.0-1",
  "lua-resty-jit-uuid == 0.0.7-2",
  "lua_system_constants == 0.1.3-0",
}
build = {
  type    = "builtin",
  modules = {
    ["arcturus"] = "src/arcturus.lua",
    ["arcturus.patch"] = "src/patch.lua",
    ["arcturus.utils.log"] = "src/utils/log.lua",
    ["arcturus.utils.basic"] = "src/utils/basic.lua",
  },
}