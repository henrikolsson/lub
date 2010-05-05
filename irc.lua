require "socket"
require "util"
require "logging"
require "logging.console"

local logger = logging.console()
local context = nil

IRC = {}
IRC.__index = IRC

function IRC.create(host, port, nick, channel)
   local irc = {}
   setmetatable(irc, IRC)
   irc.host = host
   irc.port = port
   irc.nick = nick
   irc.channel = channel
   irc.hooks_msg_command = {}
   return irc
end

function IRC:parse(line)
   local prefix = ""
   local trailing = {}
   local args = {}
   if line == nil then
      return nil,nil,nil
   end

   if line:len() < 1 then
      return nil,nil,nil
   end

   local pos
   if line:sub(1,1) == ":" then
      pos = line:find(" ")
      prefix = line:sub(2, pos-1)
      line = line:sub(pos+1)
   end
   pos = line:find(" :")
   if pos ~= nil then
      trailing = line:sub(pos+2)
      line = line:sub(1, pos-1)
   end
   local words = split(line)
   for i, w in ipairs(words) do
      table.insert(args, w)
   end
   table.insert(args, trailing)

   local command = args[1]
   table.remove(args, 1)
   return prefix,command,args
end

function IRC:send(fmt, ...)
   local line = string.format(fmt, ...)
   line = string.gsub(line, "\n", " | ")
   line = string.gsub(line, "\r", "")
   line = string.gsub(line, "\t", " ")
   -- logger:debug(string.format("--> %s", line))
   local sent, err = self.client:send(string.format("%s\r\n", line))
   if sent == nil then
      logger:error(string.format("failed to send data: %s", err))
   end
end

function IRC:parse_prefix(prefix)
   if prefix == nil or
      prefix:find("!") == nil or prefix:find("@") == nil then
      return nil, nil, nil
   end

   return prefix:sub(1, prefix:find("!")-1),
   prefix:sub(prefix:find("!")+1, prefix:find("@")-1),
   prefix:sub(prefix:find("@")+1, prefix:len())
end

function IRC:send_msg(target, fmt, ...)
   self:send("PRIVMSG %s :%s", target, string.format(fmt, ...))
end

function IRC:reply(fmt, ...)
   if context == nil then
      logger:error("reply without context")
   else
      local target = nil
      if context[1]:find("#") == 1 then
         target = context[1]
      else
         target = self:parse_prefix(context[2])
      end
      self:send("PRIVMSG %s :%s", target, string.format(fmt, ...))
   end
end

function IRC:quit()
   self.client:close()
end

function IRC:connect()
   self.client, err = socket.connect(self.host, self.port)
   if self.client == nil then
      logger:error(string.format("failed to connect: %s", err))
      return false
   end
   self.client:settimeout(0.5)
   self:send("NICK %s", self.nick)
   self:send("USER %s 8 * :%s", self.nick, self.nick)
   return true
end

function IRC:tick()
   local line, err = self.client:receive("*l")
   if err ~= nil and err ~= "timeout" then
      logger:error(string.format("failed to receive data: %s", err))
      return false
   end
   if line == nil then return true end
   -- logger:debug(string.format("<-- %s", line))
   prefix, command, args = self:parse(line)
   if command == "PING" then
      self:send("PONG :%s", args[1])
   elseif command == "001" then
      self:send("JOIN %s", self.channel)
   elseif command == "PRIVMSG" then
      local target = args[1]
      local tokens = split(args[2])
      context = {target, prefix}
      if self.hooks_msg_command[tokens[1]] ~= nil then
         success, error = xpcall(function()
                                    self.hooks_msg_command[tokens[1]](self, target,  tokens[1], prefix, args[2])
                                 end,
                                 debug.traceback)
         if not success then
            logger:error(error)
            irc:reply("error: %s", error)
         end
      end
      context = nil
   end
   return true
end
