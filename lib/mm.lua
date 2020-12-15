local json=require "json"
MM={debug=false,device=1}

function MM:new(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  
  -- load file
  local f=assert(io.open(o.filename,"rb"))
  local content=f:read("*all")
  f:close()
  o.c=json.decode(content)
  
  -- explode the settings (in cases of multiple)
  events={}
  for i,e in pairs(o.c.events) do
    event=e
    if e.count==nil then
      table.insert(events,e)
    else
      for j=1,e.count do
        e2={comment=e.comment..j,midi=e.midi+(j-1)*e.midi_add,osc={}}
        e2.comment=e2.comment:gsub("X",j)
        if e.button~=nil then
          e2.button=true
        end
        for k,o in pairs(e.osc) do
          o2=MM.deepcopy(o)
          o2.msg=o2.msg:gsub("X",j)
          table.insert(e2.osc,o2)
        end
        table.insert(events,e2)
      end
    end
  end
  
  -- initialize the settings
  for i,e in pairs(events) do
    events[i].state={}
    for j,_ in pairs(e.osc) do
      events[i].state[j]={last_val=0,mem=0}
    end
    events[i].last_msg_time=MM.current_time()
  end
  o.c.events=events
  
  -- intiailize midi
  o.input=midi.connect(o.device)
  o.input.event=o:on_input
  
  o:print("created")
  return o
end

function MM:oninput(data)
  local d=midi.to_msg(data)
  o:print('MM',d.type,d.cc,d.val)
  nval=d.val/127.0
  current_time=MM.current_time()
  for i,e in pairs(self.c.events) do
    -- check if the midi is equal to the cc value
    if e.cc==d.cc then
      if e.comment~=nil then
        print(e.comment)
      end
      
      -- buttons only toggle when hitting 127
      if e.button~=nil and d.val~=127 then
        return
      end
      
      -- a small debouncer
      if current_time-e.last_msg_time<0.01 then
        return
      end
      
      -- loop through each osc message for this event
      for j,o in pairs(e.osc) do
        send_val=nil
        if o.bounds~=nil then
          -- bounds are continuous
          send_val=nval*(o.bounds[2]-o.bounds[1])
          send_val=send_val+o.bounds[1]
        elseif o.datas~=nil then
          -- loop through multiple discrete data
          if e.button~=nil and e.button then
            -- button toggles to next data
            if (self.c.events[i].state[j].mem==nil) then
              self.c.events[i].state[j].mem=1
            end
            self.c.events[i].state[j].mem=self.c.events[i].state[j].mem+1
            if self.c.events[i].state[j].mem>#o.datas then
              self.c.events[i].state[j].mem=1
            end
            send_val=o.datas[self.c.events[i].state[j].mem]
          else
            -- slider/toggle selects closest value in discrete set
            send_val=o.datas[math.floor(nval*(#o.datas-1.0)+1.0)]
          end
        elseif o.data~=nil then
          -- single data is defined
          send_val=o.data
        end
        if send_val~=nil and nval~=self.c.events[i].state[j].last_val then
          self.c.events[i].state[j].last_val=nval
          midi2osc.print("MM",o.msg,nval)
          osc.send({"localhost",10111},o.msg,{nval})
          self.c.events[i].last_msg_time=current_time
        end
      end
      midi2osc.print('MM',e.comment)
      break
    end
  end
  
end

function MM:print(...)
  local arg={...}
  if self.debug and arg~=nil then
    printResult=""
    for i,v in ipairs(arg) do
      printResult=printResult..tostring(v).." "
    end
    print(printResult)
  end
end

MM.current_time=function()
  return clock.get_beats()*clock.get_beat_sec()
end

MM.deepcopy=function(orig)
  local orig_type=type(orig)
  local copy
  if orig_type=='table' then
    copy={}
    for orig_key,orig_value in next,orig,nil do
      copy[MM.deepcopy(orig_key)]=MM.deepcopy(orig_value)
    end
    setmetatable(copy,MM.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy=orig
  end
  return copy
end

a=MM:new({debug=true,filename="../examples/nanokontrol-oooooo.json"})
a:print("hello")
