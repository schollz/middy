-- A small library to do extend midi mapping functionality
-- usage:
-- local MidiMidi=include("midimidi/lib/midimidi")
-- MidiMidi:init({log_level="debug",filename="/home/we/dust/code/midimidi/examples/nanokontrol-oooooo.json",device=1})

local json=include("midimidi/lib/json")
MidiMidi={log_level="",device=1,file_loaded=false,recording={},is_recording=false,subdivisions=16,measures=4,recording_start_beat=0,beats_per_measure=4}

function MidiMidi:init(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  
  if o.filename~=nil and util.file_exists(o.filename) then
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
          e2={comment=e.comment..j,cc=e.cc+(j-1)*e.add,commands={}}
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
        events[i].state[j]={last_val=0,mem=1}
      end
      events[i].last_msg_time=MidiMidi.current_time()
    end
    o.events=events
    o.file_loaded=true
  end
  
  -- intiailize midi
  o:info("midimidi listening to device "..o.device)
  o.input=midi.connect(o.device)
  o.input.event=function(data)
    o:process(data)
  end
  
  return o
end

function MidiMidi:add_menu()
  -- add parameters
  params:add_group("MIDIMIDI",2)
  params:add{type='binary',name='toggle recording',id='midimidi_record',behavior='momentary',action=function(v)
    if self.is_recording then
      self:recording_stop()
      params:set("midimidi_messsage","started recording.")
    else
      self:recording_start()
      params:set("midimidi_messsage","stopped recording.")
    end
  end}
  params:add_text('midimidi_messsage',">","")
end

function MidiMidi:recording_start()
  self:info("recording_start")
  self.recording={}
  self.recording_start_beat=clock.get_beats()
  self.is_recording=true
end

function MidiMidi:recording_stop()
  self:info("recording_stop")
  -- TODO save recording
  print(json.encode(self.recording))
  self.is_recording=false
end

function MidiMidi:process_note(d)
  if not self.is_recording then
    do return end
  end
  beat=MidiMidi.round_to_nearest(clock.get_beats()-self.recording_start_beat,4/self.subdivisions)
  if beat>self.measures*self.beats_per_measure then
    return self:recording_stop()
  end
  -- add note to recording
  if self.recording[beat]==nil then
    self.recording[beat]={}
  end
  self:debug("adding note "..json.encode(d))
  table.insert(self.recording[beat],d)
end

function MidiMidi:process(data)
  local d=midi.to_msg(data)
  self:debug('MidiMidi',d.type,d.cc,d.val)
  if d.type=="note_on" or d.type=="note_off" then
    return self:process_note(d)
  end
  if not self.file_loaded then
    self:debug("file not loaded")
    do return end
  end
  current_time=MidiMidi.current_time()
  for i,e in pairs(self.events) do
    -- check if the midi is equal to the cc value
    if e.cc==d.cc then
      self:debug("MidiMidi",e.comment)
      -- buttons only toggle when hitting 127
      if e.button~=nil and d.val~=127 then
        return
      end
      
      -- a small debouncer
      if current_time-e.last_msg_time<0.05 then
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
          self:debug("MidiMidi",e.comment,o.msg,send_val)
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

-- http://phrogz.net/round-to-nearest-via-modulus-division
MidiMidi.round_to_nearest=function(i,n)
  local m=n/2
  return i+m-(i+m)%n
end

return MidiMidi
