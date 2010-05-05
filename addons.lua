require "logging.console"

local logger = logging.console()

addons = {}

function addon_config(name)
   return config["addons"][name]
end

function require_addon(name)
   load_addon(name)
end

function load_addon(name)
   if addons[name] == nil then
      logger:info(string.format("loading %s..", name))
      addons[name] = dofile(string.format("addons/%s.lua", name))
      if addons[name] == nil then
         addons[name] = {}
      end
      if addons[name]["init"] ~= nil then            
         addons[name]["init"](config["addons"][name])
      end
   end
end

function load_addons()
   for i,v in ipairs(posix.dir("addons/")) do
      if v:find(".lua$") then
         local name = v:sub(1, v:find(".lua$")-1)
         load_addon(name)
      end
   end
end

function unload_addons()
   for name,addon in pairs(addons) do
      logger:info(string.format("unloading %s..", name))
      if addon["destroy"] ~= nil then
         addon["destroy"](config)
      end
   end
   addons = {}
end
