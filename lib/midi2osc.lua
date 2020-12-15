-- A small library to do midi -> osc
local json=include("midi2osc/lib/json")
local midi2osc={devices={},input=nil,settings={},debug=true}
local PATH=_path.data..'midi2osc/'

function midi2osc:print(...)
  local arg={...}
  if midi2osc.debug and arg~=nil then
    printResult=""
    for i,v in ipairs(arg) do
      printResult=printResult..tostring(v).." "
    end
    print(printResult)
  end
end

function midi2osc:init(o)
	o= o or {}   -- create object if user does not provide one
      setmetatable(o, self)
      self.__index = self
  if debug~=nil then
    self.debug=debug
  else
    self.debug=false
  end
  
  -- check directory
  midi2osc.print(PATH)
  if not util.file_exists(PATH) then util.make_dir(PATH) end
  
  -- check if the file exists
  if not util.file_exists(PATH..filename) then
    print("midi2osc error: can not find '"..filename.."'")
    return
  end
  
  -- load the settings
  data=midi2osc.readAll(PATH..filename)
  self.settings=json.decode(data)
  -- explode the settings (in cases of multiple)
  events={}
  for i,e in pairs(self.settings.events) do
    event=e
    if e.count==nil then
      table.insert(events,e)
    else
      for j=1,e.count do
        e2={comment=e.comment..j,midi=e.midi+(j-1)*e.midi_add,osc={}}
        if e.button~=nil then
          e2.button=true
        end
        for k,o in pairs(e.osc) do
          o2=midi2osc.deepcopy(o)
          o2.msg=o2.msg:gsub("X",j)
          table.insert(e2.osc,o2)
        end
        table.insert(events,e2)
      end
    end
  end
  -- initialize the settings
  for i,_ in pairs(events) do
    events[i].state=0
    events[i].last_msg_time=midi2osc.current_time()
  end
  self.settings.events=events
  
  -- Get a list of midi devices
  for id,device in pairs(midi.vports) do
    midi2osc.print('midi2osc','Found device: '..device.name)
    self.devices[id]=device.name
  end
  -- Create Params
  params:add{type="option",id="midi_input",name="Midi Input",options=self.devices,default=1,action=self.set_input}
  params:add_separator()
  self.set_input()
end

midi2osc.get_input_name=function(self)
  return self.devices[params:get("midi_input")]
end

midi2osc.set_input=function(self,x)
  midi2osc.print('midi2osc','Set input device: '..midi2osc:get_input_name())
  midi2osc.input=midi.connect(params:get("midi_input"))
  midi2osc.input.event=midi2osc.on_input
end

midi2osc.on_input=function(data)
  local d=midi.to_msg(data)
  midi2osc.print('midi2osc',d.type,d.cc,d.val)
  nval=d.val/127.0
  current_time=midi2osc.current_time()
  for i,e in pairs(midi2osc.settings.events) do
    if e.midi==d.cc then
      if e.button~=nil and d.val~=127 then
        return
      end
      -- a small debouncer
      if current_time-e.last_msg_time<0.01 then
        return
      end
      for j,o in pairs(e.osc) do
        if o.bounds~=nil then
          nval=nval*(o.bounds[2]-o.bounds[1])
          nval=nval+o.bounds[1]
        elseif o.toggle~=nil then
          if e.state[j]==o.toggle[1] then
            nval=o.toggle[2]
          else
            nval=o.toggle[1]
          end
          midi2osc.settings.events[i].state[j]=nval
        elseif o.datas~=nil then 
          if (midi2osc.settings.events[i].state[j] == nil) then 
            midi2osc.settings.events[i].state[j] = 1
          end
          midi2osc.settings.events[i].state = midi2osc.settings.events[i].state + 1
          if midi2osc.settings.events[i].state[j] > #o.datas then 
            midi2osc.settings.events[i].state[j] = 1 
          end
          nval = o.datas[midi2osc.settings.events[i].state[j]]
        else
          nval=o.data
        end
	if nval ~= midi2osc.settings.events[i].nval then
		midi2osc.settings.events[i].nval = nval
        	midi2osc.print("midi2osc",o.msg,nval)
        	osc.send({"localhost",10111},o.msg,{nval})
        	midi2osc.settings.events[i].last_msg_time=current_time
	end
      end
      midi2osc.print('midi2osc',e.comment)
      break
    end
  end
  
end

-- utils

midi2osc.current_time=function()
  return clock.get_beats()*clock.get_beat_sec()
end

midi2osc.readAll=function(file)
  local f=assert(io.open(file,"rb"))
  local content=f:read("*all")
  f:close()
  return content
end

midi2osc.deepcopy=function(orig)
  local orig_type=type(orig)
  local copy
  if orig_type=='table' then
    copy={}
    for orig_key,orig_value in next,orig,nil do
      copy[midi2osc.deepcopy(orig_key)]=midi2osc.deepcopy(orig_value)
    end
    setmetatable(copy,midi2osc.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy=orig
  end
  return copy
end

return midi2osc
