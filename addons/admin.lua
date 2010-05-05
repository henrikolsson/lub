require_addon("roles")
require "logging.console"

local logger = logging.console()

function admin_init(config)
   irc.hooks_msg_command[".reload"] = reload_addons
   irc.hooks_msg_command[".quit"] = quit
end

function admin_destroy(config)
   irc.hooks_msg_command[".reload"] = nil
   irc.hooks_msg_command[".quit"] = nil
end

function reload_addons(irc, target, command, sender)
   if has_role(sender, "admin") then
      success, error = xpcall(reload_addons_real, debug.traceback)
      if not success then
         logger:error(error)
         irc:reply("error: %s", error)
      else
         irc:reply("Config and addons reloaded.")
      end
   else
      irc:reply("Bummer, man.")
   end
end

function reload_addons_real()
   logger:info("reloading config..")
   dofile(config_file)
   logger:info("reloading addons..")
   unload_addons()
   load_addons()
end

function quit(irc, target)
   if has_role(sender, "admin") then
      irc:reply("Adios amigos!")
      stop()
   else
      irc:reply("Bummer, man.")
   end
end

return {init=admin_init,
        destroy=admin_destroy}
