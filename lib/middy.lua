-- A small library to do extend midi mapping functionality

local json=include("midimidi/lib/json")

Middy={
  file_loaded=false,
  is_recording=false,
  recording_start_beat=0,
  recorded_notes={},
  is_playing=false,
  clock_stop=0,
  notes_on={},
}

local m=nil

function Middy:init(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  return o
end

function Middy:init_midi()
  -- intiailize midi
  print("midimidi listening to device "..params:get("midimidi_device"))
  m=midi.connect()
  m.event=function(data)
    self:process(data)
  end
  params:set("midimidi_messsage","initialized.")
end

function Middy:init_map(filename)
  -- load file
  self.filename=filename
  local f=assert(io.open(self.filename,"rb"))
  local content=f:read("*all")
  f:close()
  self.events=json.decode(content)

  -- explode the settings (in cases of multiple)
  events={}
  for i,e in pairs(self.events) do
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
          o2=Middy.deepcopy(o)
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
    events[i].last_msg_time=Middy.current_time()
  end
  self.events=events
  self.file_loaded=true
end

function Middy:init_menu()
  params:add_group("MIDIMIDI",11)
  params:add_text('midimidi_messsage',">","need to initialize.")
  params:add{type='binary',name='initialize midi',id='midimidi_init',behavior='trigger',action=function(v)
    self:init_midi()
  end}
  params:add{type='binary',name='toggle recording',id='midimidi_record',behavior='trigger',action=function(v)
    if self.is_recording then
      self:recording_stop()
    else
      self:recording_start()
    end
  end}
  params:add{type='binary',name='toggle playback',id='midimidi_record',behavior='trigger',action=function(v)
    if not self.is_playing then
      self:playback_start()
    else
      self:playback_stop()
    end
  end}
  params:add_control("midimidi_recordnum","recording number",controlspec.new(0,1000,'lin',1,1,'',1/1000))
  params:add_option("midimidi_loopplayback","loop playback",{"no","yes"},1)
  params:add_control("midimidi_measures","measures",controlspec.new(1,16,'lin',1,2,'',1/16))
  params:add_control("midimidi_beats_per_measure","beats per measure",controlspec.new(1,16,'lin',1,4,'',1/16))
  params:add_control("midimidi_subdivision","subdivision",controlspec.new(1,32,'lin',1,16,'',1/32))
  params:add_option("midimidi_playwithstart","start recording on note",{"no","yes"},2)
  params:add_control("midimidi_device","midi device",controlspec.new(1,4,'lin',1,1,'',1/4))
  params:add_option("midimidi_op1","op1 start/stop",{"no","yes"},2)
end

function Middy:playback_stop()
  self.is_playing=false
  params:set("midimidi_messsage","stopped playback.")
  clock.cancel(self.clock_stop)
  for note,_ in pairs(self.notes_on) do
    m:note_off(note)
  end
end

function Middy:playback_start()
  params:set("midimidi_messsage","started playback.")
  local fname=_path.data.."midimidi/"..params:get("midimidi_recordnum")..".json"
  print(fname)
  local f=io.open(fname,"rb")
  if f==nil then
    params:set("midimidi_messsage","no file.")
    do return end
  end
  local save_data_json=f:read("*all")
  f:close()
  beats={}
  save_data=json.decode(save_data_json)
  for _,d in ipairs(save_data.notes) do
    if beats[d.beat]==nil then
      beats[d.beat]={}
    end
    table.insert(beats[d.beat],d)
  end
  beat_current=0
  clock.internal.start()
  self.clock_stop=clock.run(function()
    self.is_playing=true
    while beat_current<save_data.measures*save_data.beats_per_measure do
      if beat_current==0 then
        print(clock.get_beats())
      end
      if beats[beat_current]~=nil then
        -- send midi
        print(json.encode(beats[beat_current]))
        for _,note in ipairs(beats[beat_current]) do
          if note.type=="note_on" then
            m:note_on(note.note,note.vel)
            self.notes_on[note.note]=true
          elseif note.type=="note_off" then
            m:note_off(note.note)
            self.notes_on[note.note]=nil
          end
        end
      end
      clock.sync(4/save_data.subdivisions)
      beat_current=beat_current+4/save_data.subdivisions
      if beat_current>=save_data.measures*save_data.beats_per_measure and params:get("midimidi_loopplayback")==2 then
        -- reset
        beat_current=0
      end
    end
    self:playback_stop()
  end)
end

function Middy:recording_start()
  print("recording_start")
  params:set("midimidi_messsage","started recording.")
  self.recorded_notes={}
  self.recording_start_beat=clock.get_beats()
  self.is_recording=true
  self.clock_stop=clock.run(function()
    clock.sleep(clock.get_beat_sec()*params:get("midimidi_measures")*params:get("midimidi_beats_per_measure"))
    self:recording_stop()
  end)
end

function Middy:recording_stop()
  print("recording_stop")
  params:set("midimidi_messsage","stopped recording.")
  local fname=_path.data.."midimidi/"..params:get("midimidi_recordnum")..".json"
  file=io.open(fname,"w+")
  file:write(json.encode({notes=self.recording,subdivisions=params:get("midimidi_subdivision"),measures=params:get("midimidi_measures"),beats_per_measure=params:get("midimidi_beats_per_measure")}))
  file:close()
  self.is_recording=false
  clock.cancel(self.clock_stop)
end

function Middy:process_note(d)
  for k,v in pairs(d) do
    print(k,v)
  end
  if not self.is_recording then
    do return end
  end

  -- reset timer on first beat if initializing to first beat
  if Middy.table_empty(self.recorded_notes) and params:get("midimidi_playwithstart")==2 then
    self.recording_start_beat=clock.get_beats()
    -- restart stop clock
    clock.cancel(self.clock_stop)
    self.clock_stop=clock.run(function()
      clock.sleep(clock.get_beat_sec()*params:get("midimidi_measures")*params:get("midimidi_beats_per_measure"))
      self:recording_stop()
    end)
  end

  -- determine current beat
  beat=Middy.round_to_nearest(clock.get_beats()-self.recording_start_beat,4/params:get("midimidi_subdivision"))
  if beat>params:get("midimidi_measures")*params:get("midimidi_beats_per_measure") then
    return self:recording_stop()
  elseif beat==params:get("midimidi_measures")*params:get("midimidi_beats_per_measure") then
    beat=0
    table.insert(self.recorded_notes,{beat=beat,ch=d.ch,vel=d.vel,type=d.type,note=d.note})
    return self:recording_stop()
  end
  -- add note to recording
  print("adding note "..json.encode(d))
  table.insert(self.recorded_notes,{beat=beat,ch=d.ch,vel=d.vel,type=d.type,note=d.note})
end

function Middy:process(data)
  local d=midi.to_msg(data)
  if d.type=="clock" then do return end end
if d.type=="note_on" or d.type=="note_off" then
    return self:process_note(d)
  end
  if not self.is_recording and params:get("midimidi_op1")==2 then
    if d.type=="continue" then
      return self:playback_start()
    elseif d.type=="stop" then
      return self:playback_stop()
    end
  end
  print('Middy',d.type,d.cc,d.val)
  if not self.file_loaded then
    do return end
  end
  current_time=Middy.current_time()
  for i,e in pairs(self.events) do
    -- check if the midi is equal to the cc value
    if e.cc==d.cc then
      print("Middy",e.comment)
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
          print("Middy",e.comment,o.msg,send_val)
          osc.send({"localhost",10111},o.msg,{send_val})
          self.events[i].last_msg_time=current_time
          self.events[i].state[j].last_val=send_val
        end
      end
      break
    end
  end

end

Middy.current_time=function()
  return clock.get_beats()*clock.get_beat_sec()
end

Middy.deepcopy=function(orig)
  local orig_type=type(orig)
  local copy
  if orig_type=='table' then
    copy={}
    for orig_key,orig_value in next,orig,nil do
      copy[Middy.deepcopy(orig_key)]=Middy.deepcopy(orig_value)
    end
    setmetatable(copy,Middy.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy=orig
  end
  return copy
end

-- http://phrogz.net/round-to-nearest-via-modulus-division
Middy.round_to_nearest=function(i,n)
  local m=n/2
  return i+m-(i+m)%n
end

Middy.table_empty=function(t)
  for _,_ in pairs(t) do
    return false
  end
  return true
end

return Middy