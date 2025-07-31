rockspec_format = "3.0"
package = "diligent"
version = "scm-0"
source = {
   url = "git+https://github.com/user/diligent.git"
}
description = {
   summary = "A declarative, per-project workspace manager for AwesomeWM",
   license = "MIT"
}
dependencies = {
   "lua >= 5.4, < 5.5",
   "luafilesystem >= 1.8.0",
   "dkjson >= 2.5",
   "luaposix >= 35.0"
}
build = {
   type = "builtin",
   modules = {
      diligent = "lua/diligent.lua",
      json_utils = "lua/json_utils.lua"
   },
   install = {
      bin = {
         workon = "cli/workon"
      }
   }
}
