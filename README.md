# midimidi

expanding midi mapping functionality on norns.

to get started, add the following to any norns script, preferable in the `init()` function:

```lua
local MidiMidi=include("midimidi/lib/midimidi")
MidiMidi:init({log_level="debug",device=1})
```

then when you run that script, you will see the output of midi commands to maiden.

### basic button

to set those commands to do something, you need to create a *midimidi* json file. a simple json file might be like this:

```json
[
	{
	    "comment": "toggle compressor",
	    "button": true,
	    "cc": 58,
	    "commands": [ 
	    	{ "datas": [1, 2], "msg": "/param/compressor"} 
	    ]
	}
]
```

now make sure to designate where your file is in your script by changing the initilization to:

```
MidiMidi:init({log_level="debug",device=1,filename="<path to your file>"})
```

in that example, anytime a MIDI cc of 58 comes in, it will turn the compressor on/off, by toggling between the data values. the `button` directive indicates that these commands are only activated when the midi value comes in as 127.

### basic slider

if you leave off the `button` directive, the commands will act as a slider. 

if you include the `datas` directive it will map the 0-127 input to one of the discrete data in the array.

```json
[
	{
	    "comment": "discrete compressor mix",
	    "button":true,
	    "cc": 58,
	    "commands": [ 
	    	{ "datas": [0,0.5,1], "msg": "/param/comp_mix"} 
	    ]
	}
]
```

if you include the `bounds` it will map the 0-127 input continously to the bounds. in this case it needs to be triggered anytime cc comes in, so leave `button` as `false`, or don't include it at all:

```json
[
	{
	    "comment": "continuous compressor mix slider",
	    "cc": 0,
	    "commands": [ 
	    	{ "bounds": [0.2,0.9], "msg": "/param/comp_mix"} 
	    ]
	}
]
```

### chaining midi commands to single input

the nice thing about *midimidi* is that you can easily chain MIDI commands. for example, this will extend the previous example to also
change the compressor value after toggling.

```json
[
	{
	    "comment": "toggle compressor",
	    "button": true,
	    "cc": 58,
	    "commands": [ 
	    	{ "datas": [1, 2], "msg": "/param/compressor"},
	    	{ "data": 1, "msg": "/param/comp_mix"}
	    ]
	}
]
```

the `"data"` sends a single data no matter, while the compressor is toggled on or off as before.

### repetitive things

for repetitive things you can utilize the `X` notation:

```json
[{
    "comment": "volume X",
    "cc": 0,
    "add": 1,
    "count": 6,
    "commands": [
    	{ "bounds": [0,1], "msg": "/param/Xvol" }
    ]
}]
```

in that example the `count` is set to 6 so it will repeat 6 times and replace the `X` by the current count (1 through 6 here). on the first time it will start at `cc` of 0, and each time it will then add the `midi_add` to the `cc`.