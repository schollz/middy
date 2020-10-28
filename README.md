# midi2osc

Add more customization to your MIDI controller. 


Save your configuration file to `~/dust/data/midi2osc/yourfile.json` and then add the following two lines at the top of your script.

```lua
local midi2osc = include('midi2osc/lib/midi2osc')
midi2osc:init('yourfile.json')
```