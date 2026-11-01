vec3=function(x,y,z) return {x=x,y=y,z=z} end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('config.lua')
local events,threads,created,removed={}, {}, {}, 0
local calls,selected=0,nil
local machines={}
for id,entry in pairs(Config.Layout) do
 local v,h=entry.standing,math.rad(entry.standing.w)
 machines[id]={prop=id=='washer1' and {h=0} or nil,id=id,kind=entry.kind,x=v.x-math.sin(h)*.65,y=v.y+math.cos(h)*.65,z=v.z+Config.TargetHeight[entry.kind]}
end
machines.washer1={id='washer1',kind='washer',x=0,y=0,z=0,prop={h=90}}
machines.washer2={id='washer2',kind='washer',x=0,y=0,z=0}
exports=setmetatable({ox_target={addBoxZone=function(_,data) created[#created+1]=data; return #created end,removeZone=function() removed=removed+1 end}}, {__call=function() end})
lib={callback={await=function(name,delay,id)
 if name=='ww_laundry:list' then calls=calls+1;if calls==1 then return nil end;return machines end
 selected=id; return nil
end}}
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
RegisterCommand=function() end
CreateThread=function(fn) threads[#threads+1]=fn end
Wait=function() end
GetCurrentResourceName=function() return 'Wonkys_MoneyWash' end
dofile('client.lua')
threads[1]() -- delayed SQL readiness: first response nil, second response populated
assert(calls==2 and #created==5)
local identifiers={}
for _,zone in ipairs(created) do
 assert(zone.size.z>=1.65 and zone.size.y==1.8 and not zone.drawSprite)
 assert(zone.debug==false and type(zone.rotation)=='number')
 zone.options[1].onSelect()
 identifiers[selected]=true
end
local count=0;for _ in pairs(identifiers) do count=count+1 end;assert(count==5)
events['ww_laundry:machines'](machines)
assert(removed==5 and #created==10)
print('PASS: SQL readiness retry, one placed washer and four dryer targets, unique callbacks, recreation without duplicate zones')
