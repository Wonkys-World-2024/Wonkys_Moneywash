local vector
vector=function(x,y,z) return setmetatable({x=x,y=y,z=z},{__sub=function(a,b) return vector(a.x-b.x,a.y-b.y,a.z-b.z) end,__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end}) end
vec3=vector
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('config.lua')
local threads,events,clock,remaining,objects,serial={}, {}, 0,180,{},0
local m={kind='washer',x=0,y=0,z=.65,prop={x=0,y=0,z=0,h=90}}
local list={washer1=m}
exports={Wonkys_MoneyWash={LaundryMachines=function() return list end}}
GetCurrentResourceName=function() return 'Wonkys_MoneyWash' end
GetResourceState=function() return 'started' end
GetEntityCoords=function() return vector(0,1,0) end
GetGameTimer=function() return clock end
cache={ped=1}
lib={callback={await=function() return {washer1={stage='washing',remaining=remaining}} end},requestModel=function() end}
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
AddEventHandler=function(name,fn) events[name]=fn end
joaat=function(x) return x end
CreateObjectNoOffset=function(model,x,y,z,networked) assert(networked==false);serial=serial+1;objects[serial]=model;return serial end
DoesEntityExist=function(id) return objects[id]~=nil end
DeleteEntity=function(id) objects[id]=nil end
for _,name in ipairs({'SetEntityHeading','FreezeEntityPosition','SetEntityAsMissionEntity','SetEntityCollision','SetModelAsNoLongerNeeded'}) do _G[name]=function() end end
dofile('visuals.lua')
local function step(i) local ok,err=coroutine.resume(threads[i]);assert(ok,err) end
step(1);step(2)
assert(objects[1]==Config.Bzzz.running)
step(2);assert(serial==1) -- no duplicate object per poll
remaining=0;clock=2500;step(1);step(2)
assert(objects[1]==nil and objects[2]==Config.Bzzz.idle)
list={};step(1);step(2);assert(next(objects)==nil)
list={washer1=m};step(1);step(2)
events.onResourceStop('Wonkys_MoneyWash');assert(next(objects)==nil)
print('PASS: running Bzzz model, no duplicates, idle after cycle, remove stale placements, stop cleanup')
