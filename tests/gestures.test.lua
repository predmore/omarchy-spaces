local timers, gestures, events, commands = {}, {}, {}, {}
local now = 100
local original_time = os.time
os.time = function() return now end
hl = {
  gesture = function(value) table.insert(gestures,value) end,
  dispatch = function(value) table.insert(events,value) end,
  dsp = { event = function(value) return value end },
  exec_cmd = function(value) table.insert(commands,value) end,
  timer = function(fn,options) table.insert(timers,{fn=fn,options=options}); return timers[#timers] end,
}
local path = 'gestures.lua'
local module = dofile(path)
assert(#gestures==0, 'importing must not change any bindings')
assert(not pcall(function() module.setup({horizontal=true}) end), 'must reject missing restore before changing bindings')
assert(#gestures==0)
local restored = 0
module.setup({horizontal=true,restore=function() restored=restored+1 end})
assert(#gestures==6, 'only explicit vertical/pinch gestures are installed at setup')
assert(gestures[1].direction=='down' and gestures[2].direction=='up')
omarchy_spaces_gesture(true)
assert(omarchy_spaces_gesture_active)
local action=gestures[#gestures].action
assert(type(action)=='table')
action.start({time_ms=1,delta={x=-5,y=0}})
action.update({time_ms=1,delta={x=-5,y=0}})
assert(events[#events]=='predmore.spaces:swipe,update,-5.000,1,0', 'first delta must not be doubled')
action.finish({time_ms=2,cancelled=true})
assert(events[#events]=='predmore.spaces:swipe,finish,-5.000,2,1')
omarchy_spaces_gesture(false)
assert(restored==1 and not omarchy_spaces_gesture_active)
omarchy_spaces_gesture(false)
assert(restored==1, 'repeated close is a no-op')
omarchy_spaces_gesture(true)
now=103; omarchy_spaces_gesture(true)
now=105; timers[1].fn(); assert(omarchy_spaces_gesture_active,'renewal should retain routing')
now=108; timers[1].fn(); assert(not omarchy_spaces_gesture_active and restored==2,'expired lease must restore owner binding')
assert(timers[1].options.timeout==1000 and timers[1].options.type=='repeat')
local standalone=dofile(path)
standalone.setup({horizontal=false,open='up',pinch=false,fingers=4})
omarchy_spaces_gesture(true)
assert(not omarchy_spaces_gesture_active, 'vertical-only integration must not take horizontal gestures')
gestures[#gestures-1].action()
assert(commands[#commands]:find('predmore.spaces',1,true))
os.time = original_time
print('Gesture integration tests passed: opt-in, restore, delta handling, cancellation, renewal and crash recovery.')
