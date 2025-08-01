rockspec_format = "3.0"
package = "diligent-dev"
version = "scm-0"
source = {
   url = "git+https://github.com/user/diligent.git"
}
description = {
   summary = "Development dependencies for Diligent workspace manager",
   detailed = "This rockspec installs all development and testing dependencies for Diligent contributors",
   license = "MIT"
}
dependencies = {
   "lua >= 5.4, < 5.5",
   -- Runtime dependencies
   "luafilesystem >= 1.8.0",
   "dkjson >= 2.5",
   "luaposix >= 35.0",
   "lua_cliargs >= 3.0",
   "penlight >= 1.5.0",
   "lua-livr >= 0.5",
   -- Development dependencies
   "busted >= 2.0",
   "luacov >= 0.15.0",
   -- Note: stylua and selene are system packages, not LuaRocks packages
}
build = {
   type = "none"
}
