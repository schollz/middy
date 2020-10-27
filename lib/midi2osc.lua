-- A small library to do midi -> osc
local json=include("lib/json")
local MIDIOSC={devices={},input=nil,settings={},debug=true}
local PATH=_path.data..'midi2osc/'

MIDIOSC.print=function(...)
  local arg={...}
  if MIDIOSC.debug and arg~=nil then
    printResult=""
    for i,v in ipairs(arg) do
      printResult=printResult..tostring(v).." "
    end
    print(printResult)
  end
end

MIDIOSC.init=function(self,filename)
  -- check directory
  MIDIOSC.print(PATH)
  if not util.file_exists(PATH) then util.make_dir(PATH) end
  
  data=MIDIOSC.readAll(PATH..filename)
  self.settings=json.decode(data)
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
          o2=MIDIOSC.deepcopy(o)
          o2.msg=o2.msg:gsub("X",j)
          table.insert(e2.osc,o2)
        end
        table.insert(events,e2)
      end
    end
  end
  for i,_ in pairs(events) do
    events[i].state=0
    events[i].last_msg_time=MIDIOSC.current_time()
  end
  self.settings.events=events
  
  -- Get a list of midi devices
  for id,device in pairs(midi.vports) do
    MIDIOSC.print('MIDIOSC','Found device: '..device.name)
    self.devices[id]=device.name
  end
  -- Create Params
  params:add{type="option",id="midi_input",name="Midi Input",options=self.devices,default=1,action=self.set_input}
  params:add_separator()
  self.set_input()
end

MIDIOSC.get_input_name=function(self)
  return self.devices[params:get("midi_input")]
end

MIDIOSC.set_input=function(self,x)
  MIDIOSC.print('MIDIOSC','Set input device: '..MIDIOSC:get_input_name())
  MIDIOSC.input=midi.connect(params:get("midi_input"))
  MIDIOSC.input.event=MIDIOSC.on_input
end

MIDIOSC.on_input=function(data)
  local d=midi.to_msg(data)
  MIDIOSC.print('MIDIOSC',d.type,d.cc,d.val)
  nval=d.val/127.0
  current_time=MIDIOSC.current_time()
  for i,e in pairs(MIDIOSC.settings.events) do
    if e.midi==d.cc then
      if e.button~=nil and d.val~=127 then
        return
      end
      -- a small debouncer
      if current_time-e.last_msg_time<0.05 then
        return
      end
      for _,o in pairs(e.osc) do
        if o.bounds~=nil then
          nval=nval*(o.bounds[2]-o.bounds[1])
          nval=nval+o.bounds[1]
        elseif o.toggle~=nil then
          if e.state==o.toggle[1] then
            nval=o.toggle[2]
          else
            nval=o.toggle[1]
          end
          MIDIOSC.settings.events[i].state=nval
        else
          nval=o.data
        end
        MIDIOSC.print("MIDIOSC",o.msg,nval)
        osc.send({"localhost",10111},o.msg,nval)
        MIDIOSC.settings.events[i].last_msg_time=current_time
      end
      MIDIOSC.print('MIDIOSC',e.comment)
      break
    end
  end
  
end

-- utils

MIDIOSC.current_time=function()
  return clock.get_beats()*clock.get_beat_sec()
end

MIDIOSC.readAll=function(file)
  local f=assert(io.open(file,"rb"))
  local content=f:read("*all")
  f:close()
  return content
end

MIDIOSC.deepcopy=function(orig)
  local orig_type=type(orig)
  local copy
  if orig_type=='table' then
    copy={}
    for orig_key,orig_value in next,orig,nil do
      copy[MIDIOSC.deepcopy(orig_key)]=MIDIOSC.deepcopy(orig_value)
    end
    setmetatable(copy,MIDIOSC.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy=orig
  end
  return copy
end

return MIDIOSC
