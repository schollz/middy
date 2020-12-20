# middy

library to add on chaining-commands and looping for midi.

this script is something i've found very useful to add some extra functionality to midi while within other scripts on norns. i made it specifically for using with *oooooo* and *otis* but it should work with any script.

*middy* does two things:

- it will listen to midi and map input to any number of outputs in a multitude of ways (see "mapping" below)
- it will let you record midi in tempo and play it back as a mini midi loop (see "looping" below)

## Requirements

- norns script
- midi device

## Documentation

to get started, add the following to any norns script, preferable in the `init()` function:

```lua
local Middy=include("middy/lib/middy")
Middy:init()
```

this will add a new menu called `MIDDY` which you can access the functionality from. there are two main functions described below.

### mapping

*middy* lets you map any number of midi inputs to any number of internal parameter in a norns script. the real power here is that, unlike `PSET`, here you can map a single midi input to multiple parameters. 

it uses a configuration file written in JSON syntax. when loading the script from the `MIDDY` menu you will have access to the the midi mapping from your device. an example of the syntax is below.

all the configuration files need to be written and saved to the folder at

```bash
~/dust/data/middy/maps/
```

or alternatively you can start midi with the filename

```lua
Middy:init({filename="/home/we/dust/mymap.json"})
```


#### mapping: basic button

to set those commands to do something, you need to create a *middy* json file. a simple json file might be like this, which simply toggles the compressor on/off:

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

in that example, anytime a MIDI cc of 58 comes in, it will turn the compressor on/off, by toggling between the data values. the `button` directive indicates that these commands are only activated when the midi value comes in as 127 (and it ignores values of 0).

#### mapping: basic slider

if you leave off the `button` directive, the commands will act as a slider. by using the `datas` directive it will map the 0-127 input to one of the discrete data in the array - either 0, 0.5, or 1:

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

if you include the `bounds` instead of `datas`, then it will map the 0-127 input continously. in this case it needs to be triggered anytime cc comes in, so leave `button` as `false`, or don't include it at all:

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

#### mapping: chaining midi commands to single input

the nice thing about *middy* is that you can easily chain MIDI commands. for example, this will extend the previous example to also
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

### looping

*middy* is also equipped with a single basic midi looper. it basically lets you play a midi loop directly from any script in norns. to use it follow these steps:

1. go to the `MIDDY` params and first `initialize midi`.
2. select a `recording number` (each recording is designated by a number).
3. set the `measures` for how long you want the loop to be
4. start recording by pressing `toggle recording`. play something on your midi device.  
5. to playback, simply press `toggle playback`. you can keep it looping by turning `loop playback`.

## license

mit
