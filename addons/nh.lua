require "posix"
require "inotify"
require "logging.console"

local logger = logging.console()
local config = {}
local handle
local charmap = {
   Arc = "Archeologist",
   Bar = "Barbarian",
   Cav = "Caveman",
   Hea = "Healer",
   Kni = "Knight",
   Mon = "Monk",
   Pri = "Priest",
   Rog = "Rogue",
   Ran = "Ranger",
   Sam = "Samurai",
   Tou = "Tourist",
   Val = "Valkyrie",
   Wiz = "Wizard",
   Vam = "Vampire",
   
   Hum = "human",
   Orc = "orcish",
   Gno = "gnomish",
   Elf = "elven",
   Dwa = "dwarven",

   Fem = "female",
   Mal = "male",
   Ntr = "neuter",
   
   Law = "lawful",
   Cha = "chaotic",
   Neu = "neutral",
   Una = "evil"
}

local zonemap = {
   [0] = "in The Dungeons of Doom",
   [1] = "in Gehennom",
   [2] = "in The Gnomish Mines",
   [3] = "in The Quest",
   [4] = "in Sokoban",
   [5] = "in Town",
   [6] = "in Fort Ludios",
   [7] = "in the Black Market",
   [8] = "in Vlad's Tower",
   [9] = "on The Elemental Planes",
}

local achievements = {
   'obtained the Bell of Opening',
   'entered Gehennom',
   'obtained the Candelabrum of Invocation',
   'obtained the Book of the Dead',
   'performed the invocation ritual',
   'obtained the amulet',
   'entered the elemental planes',
   'entered the astral plane',
   'ascended',
   'obtained the luckstone from the Mines',
   'obtained the sokoban prize',
   'defeated Medusa',
}

local scum = {}

function nh_init(config)
   logger:debug("nh_init()")
   config = config
   irc.hooks_msg_command[".online"] = nh_get_online_players   
   irc.hooks_msg_command[".cur"] = nh_get_online_players   
   irc.hooks_msg_command[".last"] = nh_get_last_dump
   irc.hooks_msg_command[".lastgame"] = nh_get_last_dump
   irc.hooks_msg_command[".lastdump"] = nh_get_last_dump
   xlogfile_pos = posix.stat('/opt/nethack.nu/var/unnethack/xlogfile').size
   livelog_pos = posix.stat('/opt/nethack.nu/var/unnethack/livelog').size
end

function lol()
   f = io.open("/opt/nethack.nu/var/unnethack/livelog", "r")
   l = f:read("*l")
   while l ~= nil do
      d = parse_nh(l)
      print(l)
      print(livelog_msg(d))
      l = f:read("*l")
   end
end

function livelog_msg(data)
   if data["player"] ~= nil and scum[data["player"]] ~= nil then
      logger:info(string.format("scum ignored: %s", data["player"]))
      return "ignore"
   end
   if data['achieve'] ~= nil then
      local diff_a = tonumber(data['achieve_diff'])
      -- ignore irrelevant achievements & luckstone
      if diff_a == 0 or diff_a == 0x200 or diff_a == 0x400 then
         return
      end
      
      local astr = ""
      for i,v in ipairs(achievements) do
         if hasbit(diff_a, bit(i)) then
            astr = v
         end
      end
      
      return string.format("%s %s after %s turns.", data['player'], astr, data['turns'])
   elseif data['wish'] ~= nil then
      if data['wish']:lower() == "nothing" then
         return string.format("%s has declined a wish.", data['player'])
      else
         return string.format("%s wished for '%s' after %s turns.",
                              data['player'],
                              data['wish'],
                              data['turns'])
      end
   elseif data['shout'] ~= nil then
      local msg = string.format("You hear %s's distant rumbling", data['player'])
      if data['shout'] == "" then
         msg = msg .. "."
      else
         msg = msg .. string.format(": \"%s\"", data["shout"])
      end
      return msg
   elseif data['killed_uniq'] ~= nil then
      return string.format("%s killed %s after %s turns.",
                           data['player'],
                           data['killed_uniq'],
                           data['turns'])
   elseif data['shoplifted'] ~= nil then
      local suffix = "'s"
      if data["shopkeeper"]:find("s$") ~= nil then
         suffix = "'"
      end
      return string.format("%s stole %s zorkmids worth of merchandise from %s%s %s after %s turns",
                           data['player'],
                           data['shoplifted'],
                           data['shopkeeper'],
                           suffix,
                           data['shop'],
                           data['turns'])
      
   elseif data['bones_killed'] ~= nil then
      return string.format("%s killed the %s of %s the former %s after %s turns.",
                           data['player'],
                           data['bones_monst'],
                           data['bones_killed'],
                           data['bones_rank'],
                           data['turns'])
   elseif data['crash'] ~= nil then
      return string.format("%s has defied the laws of unnethack, process exited with status %s",
                           data['player'],
                           data['crash'])
   elseif data['sokobanprize'] ~= nil then
      return string.format("%s obtained %s after %s turns in Sokoban.",
                           data['player'], 
                           data['sokobanprize'], 
                           data['turns'])
   elseif data['game_action'] ~= nil then
      if data['game_action'] == 'started' and data['character'] ~= nil then
         return string.format("%s enters the dungeon as a%s.",
                              data['player'],
                              data['character'])
      elseif data['game_action'] == 'resumed' and data['character'] ~= nil then
         return string.format("%s the%s resumes the adventure.",
                              data['player'],
                              data['character'])
      elseif data['game_action'] == 'started' then
         return string.format("%s enters the dungeon as a%s %s %s.",
                              data['player'],
                              data['alignment'],
                              data['race'],
                              data['role'])
      elseif data['game_action'] == 'resumed' then
         return string.format("%s the %s %s resumes the adventure.",
                              data['player'],
                              data['race'],
                              data['role'])
      elseif data['game_action'] == 'saved' then
         return string.format("%s is taking a break from the hard life as an adventurer.",
                              data['player'])
      elseif data['game_action'] == 'panicked' then
         return string.format("The dungeon of %s collapsed after %s turns!",
                              data['player'],
                              data['turns'])
      end
   end
   
   return nil
end

function nh_tick(irc)
   for k,v in pairs(scum) do
      if v + 60 < os.time() then
         logger:info(string.format("forgetting scum: %s", k))
         scum[k] = nil
      end
   end
   local fn = nil   
   if posix.stat('/opt/nethack.nu/var/unnethack/xlogfile').size > xlogfile_pos then
      fn = '/opt/nethack.nu/var/unnethack/xlogfile'
   elseif posix.stat('/opt/nethack.nu/var/unnethack/livelog').size > livelog_pos then
      fn = '/opt/nethack.nu/var/unnethack/livelog'
   end
   if fn ~= nil then
      local f, err = io.open(fn)
      logger:debug(string.format("opening %s", fn))
      if f == nil then
         logger:error(string.format("failed to open %s: %s", fn, err))
      else
         local line, err
         if fn == "/opt/nethack.nu/var/unnethack/xlogfile" then
            f:seek("set", xlogfile_pos)
            line, err = f:read("*l")
            xlogfile_pos = f:seek()
         else
            f:seek("set", livelog_pos)
            line, err = f:read("*l")
            livelog_pos = f:seek()
         end
         if line == nil then
            logger:error(string.format("failed to read line from %s: %s", fn, err))
         else
            f:close()
            local data = parse_nh(line)
            if fn == '/opt/nethack.nu/var/unnethack/xlogfile' then
               local out = string.format("%s, the %s %s %s %s",
                                         data["name"],
                                         charmap[data["align"]],
                                         charmap[data["gender"]],
                                         charmap[data["race"]],
                                         charmap[data["role"]])
               zone = zonemap[tonumber(data["deathdnum"])]
               if zone == nil then zone = "at an unknown location" end
               if data["death"] == "ascended" then
                  out = out .. " ascended to demigod-good. "
               else
                  out = out .. string.format(", %s %s on level %s, %s. ",
                                             "left this world",
                                             zone,
                                             data["deathlev"],
                                             data["death"])
               end
               if data["gender"] == "Mal" then
                  out = out .. "His "
               elseif data["gender"] == "Fem" then
                  out = out .. "Her "
               elseif data["gender"] == "Ntr" then
                  out = out .. "It's "
               end
               out = out .. string.format("score was %s.", data['points'])
               if ((data["death"] == "quit" or data["death"] == "escaped") and tonumber(data["turns"]) < 10) or scum[data["name"]] ~= nil then
                  scum[data["name"]] = os.time()
                  logger:info(string.format("ignoring startscummer: %s", data["name"]))
               else
                  irc:send_msg(irc.channel, out)
               end
            elseif fn == '/opt/nethack.nu/var/unnethack/livelog' then
               local msg = livelog_msg(data)
               if msg ~= nil and msg ~= "ignore" then
                  irc:send_msg(irc.channel, msg)
               elseif msg == nil then
                  logger:warn(string.format("unhandled livelog line: %s", line))
               end
            end
         end
      end
   end
end

function bit(p)
   return 2 ^ (p - 1)  -- 1-based indexing
end

function hasbit(x, p)
   return x % (p + p) >= p
end

function nh_destroy(config)
   logger:debug("nh_destroy()")
   irc.hooks_msg_command[".online"] = nil
   irc.hooks_msg_command[".cur"] = nil
   irc.hooks_msg_command[".last"] = nil
   irc.hooks_msg_command[".lastgame"] = nil
   irc.hooks_msg_command[".lastdump"] = nil
end

function parse_nh(line)
   local kvs = split(line, ":")
   local result = {}
   for i,v in ipairs(kvs) do
      local kv = split(v, "=")
      result[kv[1]] = kv[2]
   end
   return result
end

function nh_get_last_dump(irc, target, command, sender, line)
   local tokens = split(line)
   local nick = irc:parse_prefix(sender)
   if #tokens >= 2 then
      nick = tokens[2]
   end
   nick = nick:gsub("/", "")
   nick = nick:gsub("%.", "")
   local ext = nil
   local stat = posix.stat(string.format("/srv/un.nethack.nu/users/%s/dumps/%s.last.txt.html", nick, nick))
   if stat == nil then
      stat = posix.stat(string.format("/srv/un.nethack.nu/users/%s/dumps/%s.last.txt", nick, nick))
      if stat == nil then
         irc:reply("No lastdump for %s", nick)
      else
         ext = ".txt"
      end
   else
      ext = ".txt.html"
   end
   
   if ext ~= nil then
      local tg = posix.readlink(string.format("/srv/un.nethack.nu/users/%s/dumps/%s.last%s", nick, nick, ext))
      local fn = posix.basename(tg)
      irc:reply("http://un.nethack.nu/users/%s/dumps/%s", nick, fn)
   end
end

function nh_get_online_players(irc, target, command)
   local playing = 0
   for i,v in ipairs(posix.dir("/opt/nethack.nu/dgldir/inprogress/")) do
      if v ~= ".." and v ~= "." then
         local pos = v:find(":")
         if pos == nil then
            logger:error(string.format("inprogress file without : %s", v))
         else
            local player = v:sub(1, pos-1)
            local date = v:sub(pos+1)
            local stat = posix.stat(string.format("/opt/nethack.nu/dgldir/ttyrec/%s/%s", player, date))
            if stat == nil then
               logger:error(string.format("no ttyrec corresponding to inprogress: %s | %s",
                                          v,
                                          string.format("/opt/nethack.nu/dgldir/ttyrec/%s/%s", player, date)))
            else
               local idle = os.time() - stat.mtime
               local fd, err = io.open(string.format("/opt/nethack.nu/var/unnethack/%s.whereis", player), "r")
               if fd == nil then
                  logger:error(string.format("failed to open %s: %s", v, err))
               else
                  local t = parse_nh(fd:read("*l"))
                  io.close(fd)
                  local amulet = ""
                  if t["amulet"] == nil then
                     amulet = " (carrying the amulet)"
                  end

                  if t["playing"] ~= "1" then
                     logger:error(string.format("playing should be 1 for %s",
                                                string.format("/opt/nethack.nu/var/unnethack/%s.whereis", player)))
                  end
                  playing = playing + 1
                  irc:reply("%s the %s %s %s %s is currently at level %s in %s at turn %s%s (idle for %s)",
                            t["player"],
                            t["align"],
                            charmap[t["gender"]],
                            t["race"],
                            t["role"],
                            t["depth"],
                            t["dname"],
                            t["turns"],
                            amulet,
                            format_time(idle))
                end
            end
         end
      end
   end
   if playing == 0 then
      irc:reply("the world of unnethack is currently empty.. why don't you give it a try?")
   end
end

return {tick=nh_tick,
        init=nh_init,
        destroy=nh_destroy}
   
