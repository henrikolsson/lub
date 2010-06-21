require "logging.console"

local logger = logging.console()

function misc_init(config)
   irc.hooks_msg_command[".commands"] = commands
end

function misc_destroy(config)
   irc.hooks_msg_command[".commands"] = nil
end

function commands(irc)
   local result = ""
   for key,value in pairs(irc.hooks_msg_command) do
      if result:len() > 0 then
         result = result .. ", "
      end
      result = result .. key
   end
   irc:reply(result)
end

return {init=misc_init,
        destroy=misc_destroy}
