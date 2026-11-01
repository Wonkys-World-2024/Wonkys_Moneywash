vec3=function(x,y,z) return {x=x,y=y,z=z} end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('config.lua')
local objects,models,events={}, {}, {}
local serial,step,cancelAt,failModel=0,0,nil,false
cache={ped=1}
lib={requestModel=function() if failModel then error('injected model failure') end end,requestAnimDict=function() end,notify=function() end,
 progressCircle=function() step=step+1;return step~=cancelAt end}
GetCurrentResourceName=function() return 'Wonkys_MoneyWash' end
AddEventHandler=function(name,fn) events[name]=fn end
joaat=function(x) return x end
IsEntityDead=function() return false end
IsPedInAnyVehicle=function() return false end
GetEntityHeading=function() return 0 end
GetOffsetFromEntityInWorldCoords=function() return {x=0,y=0,z=0} end
CreateObjectNoOffset=function(model) serial=serial+1;objects[serial]=true;models[#models+1]=model;return serial end
DoesEntityExist=function(id) return objects[id] end
DeleteEntity=function(id) objects[id]=nil end
GetPedBoneIndex=function() return 1 end
for _,name in ipairs({'SetEntityAsMissionEntity','SetEntityCollision','SetEntityHeading','FreezeEntityPosition','AttachEntityToEntity','StopAnimTask','TaskTurnPedToFaceCoord','SetModelAsNoLongerNeeded'}) do _G[name]=function() end end
dofile('handling.lua')
local machine={x=0,y=0,z=0}
assert(WonkysBagAction(machine,'wash'));assert(step==3 and next(objects)==nil and models[#models]==Config.BagHandling.emptyModel)
step=0;assert(WonkysBagAction(machine,'collect'));assert(step==3 and next(objects)==nil and models[#models]==Config.BagHandling.fullModel)
for i=1,3 do step=0;cancelAt=i;assert(not WonkysBagAction(machine,'dry'));assert(next(objects)==nil) end
cancelAt=nil;failModel=true;assert(not WonkysBagAction(machine,'wash'));assert(next(objects)==nil)
failModel=false;step=0;assert(WonkysBagAction(machine,'wash')) -- lock resets after errors
print('PASS: full-to-empty loading, full-bag collection, cancellation at each loading stage, cleanup after model failure, action unlock')
