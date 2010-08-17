require "posix"
require "logging.console"
require "irc"
require "util"
require "addons"

config_file = "config.lua"
local logger = logging.console()
local running = false

function stop()
   running = false
end

function main()
   running = true

   if arg[1] ~= nil then
      config_file = arg[1]
   end
   logger:info("loading config " .. config_file .. "..")
   dofile(config_file)

   irc = IRC.create(config["server"],
                    config["port"],
                    config["nick"],
                    config["channel"])

   local twittermodule = require("twitter")
   -- creating client instance
   twitter = twittermodule.Client(config["twitter_username"], config["twitter_password"])
   -- verifying given credentials
   -- TODO verify ret
   ret = twitter:VerifyCredentials()

   load_addons()
   if not irc:connect() then
      return
   end
   
   while running do
      if not irc:tick() then
         return
      end
      for _,addon in pairs(addons) do
         local func = addon["tick"]
         if func ~= nil then
            success, error = xpcall(function() func(irc) end,
                                    debug.traceback)
            if not success then
               logger:error("failed to tick" .. error)
            end
         end
      end
   end
   
   unload_addons()
   irc:quit()
end

main()

