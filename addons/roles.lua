require "logging.console"

local logger = logging.console()
local authed = {}

function roles_init()
   irc.hooks_msg_command[".auth"] = role_auth
end

function roles_destroy()
   irc.hooks_msg_command[".auth"] = nil
end

function has_role(sender, role)
   if authed[sender] ~= nil then
      for i,v in pairs(authed[sender]["roles"]) do
         if v == role then
            return true
         end
      end
   end
   return false
end

function role_auth(irc, target, cmd, sender, line)
   local tokens = split(line)
   logger:info(string.format("%s trying to auth", sender))
   if #tokens >= 2 then
      local cfg = addon_config("roles")
      if cfg[sender] ~= nil and cfg[sender]["password"] == tokens[2] then
         logger:info("authed " .. sender .. " with roles " .. join(cfg[sender]["roles"]))
         authed[sender] = {roles = cfg[sender]["roles"],
                           authed = os.time()}
         irc:reply("Ready to serve.")
      else
         irc:reply("Sorry, dude.")
      end
   end
end

function roles_tick()
   for k,v in pairs(authed) do
      if v["authed"] + 60 < os.time() then
         logger:debug("timed out auth for " .. k)
         authed[k] = nil
      end
   end
end

return {init=roles_init,
        destroy=roles_destroy,
        tick=roles_tick}

