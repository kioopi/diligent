rockspec_format = "3.0"
package = "diligent"
version = "scm-0"
source = {
   url = "git+https://github.com/kioopi/diligent.git"
}
description = {
   summary = "A declarative, per-project workspace manager for AwesomeWM",
   license = "MIT"
}
dependencies = {
   "lua >= 5.4, < 5.5",
   "luafilesystem >= 1.8.0",
   "dkjson >= 2.5",
   "luaposix >= 35.0",
   "lua_cliargs >= 3.0",
   "penlight >= 1.5.0",
   "lua-livr >= 0.5",
}
build = {
   type = "builtin",
   modules = {
      diligent = "lua/diligent.lua",
      json_utils = "lua/json_utils.lua",
      cli_printer = "lua/cli_printer.lua",
      dbus_communication = "lua/dbus_communication.lua",
      ["commands.ping"] = "lua/commands/ping.lua"
   },
   install = {
      bin = {
         workon = "cli/workon"
      }
   }
}
