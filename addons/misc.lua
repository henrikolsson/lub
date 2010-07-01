require "logging.console"

local logger = logging.console()

function misc_init(config)
   irc.hooks_msg_command[".commands"] = commands
   irc.hooks_msg_command[".insult"] = insult
   irc.hooks_msg_command[".random"] = random
end

function misc_destroy(config)
   irc.hooks_msg_command[".commands"] = nil
   irc.hooks_msg_command[".insult"] = nil
   irc.hooks_msg_command[".random"] = nil
end

function random(irc, target, command, sender, line)
   local tokens = split(line)
   if #tokens == 1 then
      irc:reply("42")
   else
      local index = math.random(2, #tokens)
      irc:reply(tokens[index])
   end
end

function insult(irc, target, command, sender, line)
   local tokens = split(line)
   local nick = irc:parse_prefix(sender)
   if #tokens >= 2 then
      nick = tokens[2]
   end
   irc:reply(string.format("%s: I am rubber, you are glue!", nick))
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
