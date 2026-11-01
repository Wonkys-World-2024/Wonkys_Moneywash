vec3=function() return setmetatable({}, {__sub=function() return setmetatable({}, {__len=function() return 0 end}) end}) end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('config.lua')
local callbacks,rentals,batches,balances={}, {}, {}, {[1]=5000,[2]=5000}
local cashCalls,failMoney,failActivation,hasTablet=0,false,false,true
local machines={{id='w1',kind='washer',x=0,y=0,z=0},{id='w2',kind='washer',x=0,y=0,z=0},{id='d1',kind='dryer',x=0,y=0,z=0},{id='d2',kind='dryer',x=0,y=0,z=0}}
GetPlayerPed=function() return 1 end
GetEntityCoords=vec3
TriggerClientEvent=function() end
RegisterNetEvent=function() end
RegisterCommand=function() end
AddEventHandler=function() end
lib={callback={register=function(n,f) callbacks[n]=f end}}
exports={ox_inventory={GetItemCount=function() return hasTablet and 1 or 0 end},qbx_core={
 GetPlayer=function(_,src) return {PlayerData={citizenid='char'..src}} end,
 GetMoney=function(_,src) return balances[src] end,
 RemoveMoney=function(_,src,account,amount)
  cashCalls=cashCalls+1
  if failMoney then return false end
  balances[src]=balances[src]-amount;return true
 end}}
local function query(q,a)
 a=a or {}
 if q:find('CREATE TABLE') or q:find('INSERT IGNORE INTO ww_laundry_machines') then return {} end
 if q=='SELECT * FROM ww_laundry_machines' then return machines end
 if q=='SELECT * FROM ww_laundry_props' then return {{id='w1',x=0,y=0,z=0,h=0},{id='w2',x=0,y=0,z=0,h=0}} end
 if q:find('DELETE r FROM') then for cid,r in pairs(rentals) do if batches[r.batch] and batches[r.batch].stage=='paid' then rentals[cid]=nil end end;return {} end
 if q:find('INSERT INTO ww_laundry_rentals') then rentals[a[1]]={owner=a[1],washer=a[2],dryer=a[3],state='pending',fee=a[4]};return {} end
 if q:find("UPDATE ww_laundry_rentals SET state='active'") then if failActivation then error('injected commit failure') end;rentals[a[1]].state='active';return {} end
 if q:find('DELETE FROM ww_laundry_rentals') then rentals[a[1]]=nil;return {} end
 if q:find('SELECT washer,dryer') then local r={};for _,row in pairs(rentals) do r[#r+1]=row end;return r end
 if q:find('SELECT machine FROM') then return {} end
 error('Unhandled SQL '..q)
end
local function single(q,a)
 if q:find('ww_laundry_rentals WHERE owner=') then return rentals[a[1]] end
 if q:find('ww_laundry_batches WHERE id=') then return batches[a[1]] end
 error('Unhandled single '..q)
end
local function scalar(q,a)
 if q:find('ww_laundry_settings') then return nil end
 if q:find('ww_laundry_rentals') then
  for _,r in pairs(rentals) do if r.owner==a[1] or r.washer==a[2] or r.dryer==a[3] then return r.owner end end
  return nil
 end
 if q:find('ww_laundry_batches') then return nil end
 error('Unhandled scalar '..q)
end
MySQL={query={await=query},single={await=single},scalar={await=scalar},ready=function(fn) fn() end}
dofile('server.lua')
local rent=callbacks['ww_laundry:rent']
hasTablet=false;assert(rent(1,'w1','d1').error);assert(cashCalls==0);hasTablet=true
assert(rent(1,'w1','d1').message and balances[1]==4500)
assert(rentals.char1.state=='active')
assert(rent(1,'w2','d2').error and rent(2,'w1','d1').error and cashCalls==1)
local info=callbacks['ww_laundry:tablet'](1)
assert(info.rental.washer=='w1' and info.rental.owner==nil)
assert(#info.washers==1 and info.washers[1]=='w2')
rentals.char1.batch=42;batches[42]={stage='washing',ready=os.time()+180}
assert(callbacks['ww_laundry:endRental'](1).error)
batches[42].stage='paid'
assert(rent(1,'w1','d1').message and balances[1]==4000) -- completed pair released
assert(callbacks['ww_laundry:endRental'](1).message and rentals.char1==nil and balances[1]==4000)
balances[2]=1;assert(rent(2,'w2','d2').error and cashCalls==2);balances[2]=5000
failMoney=true;assert(rent(2,'w2','d2').error and rentals.char2==nil and balances[2]==5000);failMoney=false
failActivation=true;assert(rent(2,'w2','d2').error and rentals.char2.state=='pending' and balances[2]==4500)
local calls=cashCalls;assert(rent(2,'w2','d2').error and cashCalls==calls)
print('PASS: tablet authorisation, server fee, duplicate/other-owner refusal, private response, occupied cancellation, paid release, no-refund cancellation, insufficient funds, failed payment rollback, interrupted payment journal')

local last
for i=1,25 do last=callbacks['ww_laundry:tablet'](1) end
assert(last.error and last.error:find('Too many'))
print('PASS: per-player callback request limit')
