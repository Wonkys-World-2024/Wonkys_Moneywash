vec3=function(x,y,z) return {x=x,y=y,z=z} end
-- Run from resource root using Lua 5.4. Isolated mocks; no game/database required.
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('config.lua')
local callbacks, rows, items, cash = {}, {}, {}, 0
local events,transactions={},0
local commands={}
RegisterCommand=function(name,fn) commands[name]=fn end
GetPlayers=function() return {1} end
source=1
IsPlayerAceAllowed=function() return true end
local nextId, seeded = 0, {}
local machines = {{id='w1',kind='washer',prop={x=0,y=0,z=0,h=0},x=0,y=0,z=0},{id='d1',kind='dryer',x=0,y=0,z=0}}
local clock=1000
os.time=function() return clock end
local function vector() return setmetatable({}, {__sub=function() return setmetatable({}, {__len=function() return 0 end}) end}) end
vec3=vector
GetEntityCoords=vector
GetPlayerPed=function() return 1 end
TriggerClientEvent=function() end
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function() end
local inventory={}
inventory.GetItemCount=function(_,src,name) return items[name] or 0 end
inventory.RemoveItem=function(_,src,name,count,metadata,slot)
 if slot then if not items[slot] then return false end; items[slot]=nil;return true end
 if (items[name] or 0)<count then return false end
 items[name]=items[name]-count; return true
end
inventory.CanCarryItem=function() return true end
inventory.AddItem=function(_,src,name,count,metadata) items[1]={name=name,metadata=metadata,slot=1};return true end
inventory.GetSlot=function(_,src,slot) return items[slot] end
exports={ox_inventory=inventory,qbx_core={GetPlayer=function(_,src) return {PlayerData={citizenid='char'..src}} end,AddMoney=function(_,src,kind,amount) cash=cash+amount;return true end}}
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
local function query(q,a)
 a=a or {}
 if q:find('CREATE TABLE IF NOT EXISTS') then return {} end
 if q=='SELECT * FROM ww_laundry_props' then return {} end
 if q=='SELECT * FROM ww_laundry_machines' then return machines end
 if q:find('INSERT IGNORE INTO ww_laundry_machines') then seeded[a[1]]=a; return {} end
 if q:find('ww_laundry_rentals') then return {} end
 if q:find('SELECT machine,stage,ready') then local result={}; for _,r in pairs(rows) do if r.machine and (r.stage=='washing' or r.stage=='drying') then result[#result+1]=r end end; return result end
 if q:find('DELETE FROM') then rows[a[1]]=nil; return {} end
 local row=rows[a[#a]]
 if q:find("SET stage='washing'") then row.stage='washing';row.ready=a[1]
 elseif q:find("SET stage='drying'") then row.stage='drying';row.ready=a[1]
 elseif q:find("SET stage='loading'") then row.stage='loading';row.machine=a[1]
 elseif q:find("SET stage='claiming'") then row.stage='claiming'
 elseif q:find('SET stage=%?,machine=NULL') then row.stage=a[1];row.machine=nil
 elseif q:find('SET stage=%?') then row.stage=a[1]
 else error('Unhandled SQL '..q) end
 return {}
end
MySQL={query={await=query},single={await=function(q,a)
 if q:find('ww_laundry_rentals') then if q:find('dryer=') then return nil end;return {owner='char1',washer='w1',dryer='d1',state='active',batch=q:find('batch=') and a[1] or nil} end
 if q:find('WHERE machine=') then for _,r in pairs(rows) do if r.machine==a[1] then return r end end
 else local r=rows[a[1]]; if r and r.owner==a[2] and r.stage=='wet' then return r end end
end},scalar={await=function(q,a) if q:find('ww_laundry_settings') or q:find('ww_laundry_rentals') then return nil end; if q:find('SELECT id FROM') then for _,r in pairs(rows) do if r.machine==a[1] then return r.id end end; return nil end; return 0 end},transaction={await=function() transactions=transactions+1;return true end},insert={await=function(q,a)
 nextId=nextId+1;rows[nextId]={id=nextId,owner=a[1],machine=a[2],stage='loading',amount=a[3],payout=a[4],ready=0};return nextId
end},ready=function(fn) fn() end}
dofile('server.lua')
local seeds=0
for id, a in pairs(seeded) do
 seeds=seeds+1
 if Config.Layout[id] then
 local v=Config.Layout[id].standing
 assert(math.abs(math.sqrt((a[3]-v.x)^2+(a[4]-v.y)^2)-0.65)<0.00001)
 assert(a[5]==v.z+Config.TargetHeight[a[2]])
 else assert(a[3]==0 and a[4]==0 and a[5]==0) end
end
assert(seeds==8)
local act=callbacks['ww_laundry:act']
items.black_money=10000
assert(act(1,'w1','wash',999).error)
assert(items.black_money==10000)
assert(act(1,'w1','wash',10000).message)
assert(items.black_money==0 and cash==0)
events['ww_laundry:placeBzzz']('w1',{x=0,y=0,z=0},90)
assert(transactions==0) -- cannot relocate occupied machine
local visuals=callbacks['ww_laundry:visuals'](1)
assert(visuals.w1.stage=='washing' and visuals.w1.remaining==Config.WashSeconds)
assert(visuals.w1.owner==nil and visuals.w1.payout==nil)
assert(callbacks['ww_laundry:visuals'](1)==nil) -- rate limit
assert(act(1,'w1','collect').error) -- early
assert(act(2,'w1','collect').error) -- another character
clock=clock+Config.WashSeconds
assert(act(1,'w1','collect').message)
assert(cash==0 and items[1].name==Config.WetItem)
assert(act(1,'w1','collect').error) -- no double wet bundle
assert(act(2,'d1','dry',1).error) -- bound bundle
assert(act(1,'d1','dry',1).message)
assert(items[1]==nil and cash==0)
assert(act(1,'d1','collect').error)
clock=clock+Config.DrySeconds
assert(act(1,'d1','collect').message)
assert(cash==8000)
assert(act(1,'d1','collect').error and cash==8000)
print('PASS: batch bounds, input removal, early collection, ownership, wet stage, drying, payout and duplicate collection')

events['ww_laundry:placeBzzz']('w1',{x=0,y=0,z=0},90)
assert(transactions==1)
print('PASS: occupied washer relocation refused, idle Bzzz placement transaction accepted')

IsPlayerAceAllowed=function() return false end
events['ww_laundry:placeBzzz']('w1',{x=0,y=0,z=0},90)
assert(transactions==1)
commands.washbzzzallow(1,{'1'}) -- player cannot grant permission
assert(transactions==1)
commands.washbzzzallow(0,{'1'}) -- server console can grant to this character
events['ww_laundry:placeBzzz']('w1',{x=0,y=0,z=0},90)
assert(transactions==2)
print('PASS: permission denial, player grant refusal, server console character grant')
