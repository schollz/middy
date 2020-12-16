-- A small library to do extend midi mapping functionality
-- usage:
-- local MidiMidi=include("midimidi/lib/midimidi")
-- MidiMidi:init({log_level="debug",filename="/home/we/dust/code/midimidi/examples/nanokontrol-oooooo.json",device=1})

local json=include("midimidi/lib/json")
MidiMidi={log_level="info",device=1,file_loaded=false}

function MidiMidi:init(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  
  if util.file_exists(o.filename) then
    -- load file
    local f=assert(io.open(o.filename,"rb"))
    local content=f:read("*all")
    f:close()
    o.events=json.decode(content)
    
    -- explode the settings (in cases of multiple)
    events={}
    for i,e in pairs(o.events) do
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
          for k,o in pairs(e.commands) do
            o2=MidiMidi.deepcopy(o)
            o2.msg=o2.msg:gsub("X",j)
            table.insert(e2.commands,o2)
          end
          table.insert(events,e2)
        end
      end
    end
    
    -- initialize the settings
    for i,e in pairs(events) do
      events[i].state={}
      for j,_ in pairs(e.commands) do
        events[i].state[j]={last_val=0,mem=0}
      end
      events[i].last_msg_time=MidiMidi.current_time()
    end
    o.events=events
    o.file_loaded=true
  end
  
  -- intiailize midi
  o:info("midimidi listening to device "..o.device)
  o.input=midi.connect(o.device)
  o.input.event=o:on_input
  return o
end

function MidiMidi:oninput(data)
  local d=midi.to_msg(data)
  self:debug('MidiMidi',d.type,d.cc,d.val)
  if not self.file_loaded then
    do return end
  end
  current_time=MidiMidi.current_time()
  for i,e in pairs(self.events) do
    -- check if the midi is equal to the cc value
    if e.cc==d.cc then
      -- buttons only toggle when hitting 127
      if e.button~=nil and d.val~=127 then
        return
      end
      
      -- a small debouncer
      if current_time-e.last_msg_time<0.01 then
        return
      end
      
      -- loop through each osc message for this event
      for j,o in pairs(e.commands) do
        send_val=nil
        if o.bounds~=nil then
          -- bounds are continuous
          send_val=d.val/127.0*(o.bounds[2]-o.bounds[1])
          send_val=send_val+o.bounds[1]
        elseif o.datas~=nil then
          -- loop through multiple discrete data
          if e.button~=nil and e.button then
            -- button toggles to next data
            if (self.events[i].state[j].mem==nil) then
              self.events[i].state[j].mem=1
            end
            self.events[i].state[j].mem=self.events[i].state[j].mem+1
            if self.events[i].state[j].mem>#o.datas then
              self.events[i].state[j].mem=1
            end
            send_val=o.datas[self.events[i].state[j].mem]
          else
            -- slider/toggle selects closest value in discrete set
            send_val=o.datas[math.floor(d.val/127.0*(#o.datas-1.0)+1.0)]
          end
        elseif o.data~=nil then
          -- single data is defined
          send_val=o.data
        end
        if send_val~=nil and send_val~=self.events[i].state[j].last_val then
          self:info("MidiMidi",e.comment,o.msg,send_val)
          osc.send({"localhost",10111},o.msg,{send_val})
          self.events[i].last_msg_time=current_time
          self.events[i].state[j].last_val=send_val
        end
      end
      break
    end
  end
  
end

function MidiMidi:debug(...)
  if self.log_level~="debug" then
    do return end
  end
  local arg={...}
  if arg~=nil then
    printResult=""
    for i,v in ipairs(arg) do
      printResult=printResult..tostring(v).." "
    end
    print(printResult)
  end
end

function MidiMidi:info(...)
  if self.log_level~="info" and self.log_level~="debug" then
    do return end
  end
  local arg={...}
  if arg~=nil then
    printResult=""
    for i,v in ipairs(arg) do
      printResult=printResult..tostring(v).." "
    end
    print(printResult)
  end
end

MidiMidi.current_time=function()
  return clock.get_beats()*clock.get_beat_sec()
end

MidiMidi.deepcopy=function(orig)
  local orig_type=type(orig)
  local copy
  if orig_type=='table' then
    copy={}
    for orig_key,orig_value in next,orig,nil do
      copy[MidiMidi.deepcopy(orig_key)]=MidiMidi.deepcopy(orig_value)
    end
    setmetatable(copy,MidiMidi.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy=orig
  end
  return copy
end

return MidiMidi
