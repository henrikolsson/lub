function join(c, s)
   local result = ""
   if s == nil then
      s = ", "
   end
   for i,v in ipairs(c) do
      if i > 1 then
         result = result .. s .. v
      else
         result = result .. v
      end
   end
   return result
end

function format_time(secs)
   if secs < 60 then
      return secs .. "s"
   else
      local minutes = math.floor(secs / 60)
      secs = secs % 60
      if minutes < 60 then
         return minutes .. "m " .. secs .. "s"
      else
         local hours = math.floor(minutes / 60)
         minutes = minutes % 60
         return hours .. "h " .. minutes .. "m " .. secs .. "s"
      end
   end
end

function split(s, sep)
   if s == nil then
      return {}
   end
   if sep == nil then
      sep = " "
   end
   
   local result = {}
   local pos = s:find(sep)
   while pos ~= nil do
      table.insert(result, s:sub(1, pos-sep:len()))
      s = s:sub(pos+sep:len())
      pos = s:find(sep)
   end
   table.insert(result, s)
   return result
end

function range(from, to, step)
   step = step or 1
   return function(_, lastvalue)
             local nextvalue = lastvalue + step
             if step > 0 and nextvalue <= to or step < 0 and nextvalue >= to or
                step == 0
             then
                return nextvalue
             end
          end, nil, from - step
end
