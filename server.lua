local machines, locks, ready = {}, {}, false
local desk
local function enabled(m) return m and (m.kind=='dryer' or m.prop~=nil) end
local inv = exports.ox_inventory
assert(type(Config.RentalFee)=='number' and Config.RentalFee>=0 and Config.RentalFee%1==0,'RentalFee must be a non-negative integer')
assert(Config.ReturnRate>0 and Config.ReturnRate<=1,'ReturnRate must be between zero and one')
local requestRates={}
local function registerCallback(name,handler)
    lib.callback.register(name,function(src,...)
        local now=os.time()
        requestRates[src]=requestRates[src] or {}
        local bucket=requestRates[src][name]
        if not bucket or now-bucket.start>=10 then bucket={start=now,count=0};requestRates[src][name]=bucket end
        bucket.count=bucket.count+1
        if bucket.count>20 then
            if name=='ww_laundry:list' or name=='ww_laundry:visuals' or name=='ww_laundry:deskInfo' then return nil end
            return {error='Too many requests. Wait a few seconds.'}
        end
        return handler(src,...)
    end)
end
AddEventHandler('playerDropped',function() requestRates[source]=nil end)
local function player(src) return exports.qbx_core:GetPlayer(src) end
local function owner(src)
    local p = player(src)
    return p and p.PlayerData.citizenid
end
local function near(src, m)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(m.x, m.y, m.z)) <= Config.Distance + 0.5
end
local function notify(src, msg, kind)
    TriggerClientEvent('ox_lib:notify', src, {title=Config.Title, description=msg, type=kind or 'inform'})
end
local function sync() TriggerClientEvent('ww_laundry:machines', -1, machines) end
local function query(q, args) return MySQL.query.await(q, args or {}) end
MySQL.ready(function()
    query([[CREATE TABLE IF NOT EXISTS ww_laundry_props (
        id VARCHAR(40) PRIMARY KEY, x DOUBLE NOT NULL, y DOUBLE NOT NULL,
        z DOUBLE NOT NULL, h DOUBLE NOT NULL
    )]])
    query([[CREATE TABLE IF NOT EXISTS ww_laundry_rentals (
        owner VARCHAR(64) PRIMARY KEY, washer VARCHAR(40) NOT NULL UNIQUE,
        dryer VARCHAR(40) NOT NULL UNIQUE, state VARCHAR(16) NOT NULL,
        fee INT NOT NULL, batch INT UNSIGNED NULL, created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])
    query([[CREATE TABLE IF NOT EXISTS ww_laundry_settings (id VARCHAR(32) PRIMARY KEY, value LONGTEXT NOT NULL)]])
    local savedDesk=MySQL.scalar.await("SELECT value FROM ww_laundry_settings WHERE id='desk'")
    if savedDesk then desk=json.decode(savedDesk) end
    -- Seed only missing IDs: never move an installed machine or an active batch.
    for id, entry in pairs(Config.Layout) do
        local v, h = entry.standing, math.rad(entry.standing.w)
        query('INSERT IGNORE INTO ww_laundry_machines (id,kind,x,y,z) VALUES (?,?,?,?,?)',
            {id,entry.kind,v.x-math.sin(h)*Config.FrontOffset,v.y+math.cos(h)*Config.FrontOffset,v.z+Config.TargetHeight[entry.kind]})
    end
    for _,id in ipairs(Config.WasherIds) do
        query('INSERT IGNORE INTO ww_laundry_machines (id,kind,x,y,z) VALUES (?,?,?,?,?)',{id,'washer',0,0,0})
    end
    for _, m in ipairs(query('SELECT * FROM ww_laundry_machines')) do machines[m.id] = m end
    for _, prop in ipairs(query('SELECT * FROM ww_laundry_props')) do
        if machines[prop.id] then machines[prop.id].prop=prop end
    end
    ready = true
    sync()
    TriggerClientEvent('ww_laundry:desk',-1,desk)
    print('[Wonkys_MoneyWash] Loaded machines. Interrupted loading/claiming rows require administrator reconciliation; see README.')
end)
registerCallback('ww_laundry:list', function()
    if not ready then return nil end
    return machines
end)
local visualRequests = {}
registerCallback('ww_laundry:visuals', function(src)
    if not ready or not owner(src) then return {} end
    local now = os.time()
    if visualRequests[src] and now-visualRequests[src]<2 then return nil end
    visualRequests[src] = now
    local ped = GetPlayerPed(src)
    if ped == 0 then return {} end
    local pos, nearby = GetEntityCoords(ped), false
    for _, m in pairs(machines) do
        if #(pos-vec3(m.x,m.y,m.z)) < 30 then nearby=true; break end
    end
    if not nearby then return {} end
    local result = {}
    for _, row in ipairs(query("SELECT machine,stage,ready FROM ww_laundry_batches WHERE stage IN ('washing','drying') AND machine IS NOT NULL")) do
        local m = machines[row.machine]
        if m and #(pos-vec3(m.x,m.y,m.z))<30 then
            result[row.machine] = {stage=row.stage,remaining=math.max(0,row.ready-os.time())}
        end
    end
    return result
end)
AddEventHandler('playerDropped', function() visualRequests[source]=nil end)
-- Locks cover both character and machine across all yielding database operations.
local function guarded(src, id, fn)
    if not ready or type(id) ~= 'string' then return {error='Laundry is not ready.'} end
    local cid, m = owner(src), machines[id]
    if not cid or not m or not near(src, m) then return {error='Stand beside the machine.'} end
    if locks.rental or locks[cid] or locks[id] then return {error='Please wait for the current action.'} end
    locks[cid], locks[id] = true, true
    local ok, result = xpcall(function() return fn(cid, m) end, debug.traceback)
    locks[cid], locks[id] = nil, nil
    if not ok then print(result); return {error='Operation interrupted. Contact an administrator; do not repeat payment.'} end
    return result
end
registerCallback('ww_laundry:inspect', function(src, id)
    return guarded(src, id, function(cid, m)
        local row = MySQL.single.await('SELECT * FROM ww_laundry_batches WHERE machine=?', {id})
        if not enabled(m) then return {error='This original washer is disabled. Use a placed Bzzz washer.'} end
        if not row then
            local booking=MySQL.single.await('SELECT owner FROM ww_laundry_rentals WHERE washer=? OR dryer=?',{id,id})
            if booking and booking.owner~=cid then return {error='This machine is rented by another customer.'} end
            if m.kind=='washer' and not booking then return {error='Rent a washer/dryer pair using your Wonkys Wash tablet first.'} end
            return {kind=m.kind, free=true}
        end
        if row.owner ~= cid then return {error='This machine is reserved by another customer.'} end
        return {kind=m.kind, batch=row.id, stage=row.stage, remaining=math.max(0,row.ready-os.time()), payout=row.payout}
    end)
end)
registerCallback('ww_laundry:act', function(src, id, action, value)
    return guarded(src, id, function(cid, m)
        local row = MySQL.single.await('SELECT * FROM ww_laundry_batches WHERE machine=?', {id})
        if action == 'wash' then
            if m.kind ~= 'washer' or not m.prop or row then return {error='Washer unavailable.'} end
            local rental=MySQL.single.await("SELECT * FROM ww_laundry_rentals WHERE owner=? AND state='active'",{cid})
            if not rental or rental.washer~=id or rental.batch then return {error='Rent an available washer/dryer pair at the desk first.'} end
            if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < Config.MinBatch or value > Config.MaxBatch then return {error='Invalid batch amount.'} end
            local count = MySQL.scalar.await("SELECT COUNT(*) FROM ww_laundry_batches WHERE owner=? AND stage IN ('washing','drying','loading')", {cid})
            if count >= Config.MaxActive then return {error='You already have the maximum active cycles.'} end
            if inv:GetItemCount(src, Config.DirtyItem) < value then return {error='Not enough dirty money.'} end
            local payout = math.floor(value * Config.ReturnRate)
            local batch = MySQL.insert.await("INSERT INTO ww_laundry_batches (owner,machine,stage,amount,payout) VALUES (?,?,'loading',?,?)", {cid,id,value,payout})
            -- Journal first. Ambiguous crash states are never automatically rewarded.
            if owner(src)~=cid then error('Character changed during loading; inspect journal') end
            if not inv:RemoveItem(src, Config.DirtyItem, value) then
                query('DELETE FROM ww_laundry_batches WHERE id=?', {batch})
                return {error='Could not take dirty money.'}
            end
            query('UPDATE ww_laundry_rentals SET batch=? WHERE owner=?',{batch,cid})
            query("UPDATE ww_laundry_batches SET stage='washing', ready=? WHERE id=?", {os.time()+Config.WashSeconds,batch})
            return {message='Wash started. Return when the cycle finishes.'}
        elseif action == 'dry' then
            if m.kind ~= 'dryer' or row then return {error='Dryer unavailable.'} end
            if type(value) ~= 'number' then return {error='Invalid inventory slot.'} end
            local item = inv:GetSlot(src, value)
            local bid = item and item.metadata and tonumber(item.metadata.batch)
            if not item or item.name ~= Config.WetItem or not bid then return {error='Select a valid wet bundle.'} end
            local wet = MySQL.single.await("SELECT * FROM ww_laundry_batches WHERE id=? AND owner=? AND stage='wet'", {bid,cid})
            if not wet then return {error='This bundle is invalid or belongs to another character.'} end
            local rental=MySQL.single.await('SELECT * FROM ww_laundry_rentals WHERE batch=?',{bid})
            if rental and (rental.owner~=cid or rental.dryer~=id or rental.state~='active') then return {error='Use the dryer assigned on your tablet.'} end
            local reserved=MySQL.single.await('SELECT * FROM ww_laundry_rentals WHERE dryer=?',{id})
            if reserved and reserved.owner~=cid then return {error='This dryer is rented by another customer.'} end
            local count = MySQL.scalar.await("SELECT COUNT(*) FROM ww_laundry_batches WHERE owner=? AND stage IN ('washing','drying','loading')", {cid})
            if count >= Config.MaxActive then return {error='Too many active cycles.'} end
            query("UPDATE ww_laundry_batches SET stage='loading',machine=? WHERE id=?", {id,bid})
            if owner(src)~=cid then error('Character changed during dryer loading; inspect journal') end
            if not inv:RemoveItem(src, Config.WetItem, 1, item.metadata, value) then
                query("UPDATE ww_laundry_batches SET stage='wet',machine=NULL WHERE id=?", {bid})
                return {error='Could not load bundle.'}
            end
            query("UPDATE ww_laundry_batches SET stage='drying',ready=? WHERE id=?", {os.time()+Config.DrySeconds,bid})
            return {message='Dryer started. Clean cash is available after drying.'}
        elseif action == 'collect' then
            if not row or row.owner ~= cid then return {error='No batch to collect.'} end
            if row.stage ~= 'washing' and row.stage ~= 'drying' then return {error='Interrupted operation. Contact an administrator.'} end
            if row.ready > os.time() then return {error='Cycle has not finished.'} end
            if row.stage == 'washing' and not inv:CanCarryItem(src, Config.WetItem, 1) then return {error='Make space for the wet bundle.'} end
            local stage = row.stage
            query("UPDATE ww_laundry_batches SET stage='claiming' WHERE id=?", {row.id})
            if owner(src)~=cid then error('Character changed during collection; inspect journal') end
            local success
            if stage == 'washing' then
                success = inv:AddItem(src, Config.WetItem, 1, {batch=row.id, description=('Batch #%s | $%s after drying | Owner bound'):format(row.id,row.payout)})
            else
                success = exports.qbx_core:AddMoney(src, 'cash', row.payout, 'laundry-batch-'..row.id)
            end
            if not success then
                query('UPDATE ww_laundry_batches SET stage=? WHERE id=?', {stage,row.id})
                return {error='Collection failed. Free inventory space and try again.'}
            end
            query('UPDATE ww_laundry_batches SET stage=?,machine=NULL WHERE id=?', {stage=='washing' and 'wet' or 'paid',row.id})
            if stage=='drying' then query('DELETE FROM ww_laundry_rentals WHERE owner=? AND batch=?',{cid,row.id}) end
            return {message=stage=='washing' and 'Wet bundle collected. Load it into a dryer.' or ('$%s clean cash collected.'):format(row.payout)}
        end
        return {error='Unknown action.'}
    end)
end)
RegisterNetEvent('ww_laundry:place', function(kind, id, coords)
    local src = source
    if not ready or not IsPlayerAceAllowed(src, 'wonkys.moneywash.admin') then return end
    if (kind ~= 'washer' and kind ~= 'dryer') or type(id) ~= 'string' or not id:match('^[%w_%-]+$') or #id > 40 then return end
    if type(coords) ~= 'table' then return end
    for _, k in ipairs({'x','y','z'}) do if type(coords[k]) ~= 'number' or coords[k] ~= coords[k] or math.abs(coords[k]) > 20000 then return end end
    if not near(src,coords) then return end
    if locks.rental or locks[id] then return end
    locks[id] = true
    local ok, err = xpcall(function()
        if MySQL.scalar.await('SELECT owner FROM ww_laundry_rentals WHERE washer=? OR dryer=?',{id,id}) then return notify(src,'End this machine rental before moving it.','error') end
        if MySQL.scalar.await('SELECT id FROM ww_laundry_batches WHERE machine=?', {id}) then return notify(src,'Machine has a batch; cannot move it.','error') end
        query('INSERT INTO ww_laundry_machines (id,kind,x,y,z) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE kind=VALUES(kind),x=VALUES(x),y=VALUES(y),z=VALUES(z)', {id,kind,coords.x,coords.y,coords.z})
        local prop=machines[id] and machines[id].prop
        machines[id] = {id=id,kind=kind,x=coords.x,y=coords.y,z=coords.z,prop=prop}
        sync(); notify(src,'Saved '..kind..' '..id,'success')
    end, debug.traceback)
    locks[id] = nil
    if not ok then print(err);notify(src,'Placement failed. Check the server console for the database error.','error') end
end)

local placementGrants={}
RegisterCommand('washbzzzallow',function(src,args)
    if src~=0 then return notify(src,'Run washbzzzallow in the SERVER console.','error') end
    local target=tonumber(args[1])
    if not target then
        local players=GetPlayers()
        if #players==1 then target=tonumber(players[1]) end
    end
    if not target or not owner(target) then
        print('[Wonkys_MoneyWash] Usage: washbzzzallow SERVER_ID (or omit ID if only one player is connected)')
        return
    end
    placementGrants[target]=owner(target)
    notify(target,'Laundry placement enabled for this character until disconnect/resource restart.','success')
    print(('[Wonkys_MoneyWash] Placement enabled for server ID %s.'):format(target))
end,true)
AddEventHandler('playerDropped',function() placementGrants[source]=nil end)

RegisterNetEvent('ww_laundry:placeBzzz', function(id, coords, heading)
    local src=source
    if not ready then return notify(src,'Laundry database is not ready. Check server errors.','error') end
    if not IsPlayerAceAllowed(src,'wonkys.moneywash.admin') and (not owner(src) or placementGrants[src]~=owner(src)) then
        return notify(src,'Placement denied. In SERVER console run: washbzzzallow '..src,'error')
    end
    if type(id)~='string' or not machines[id] or machines[id].kind~='washer' then return notify(src,'Unknown washer ID. Use washer1 to washer4.','error') end
    if type(coords)~='table' or type(heading)~='number' or heading~=heading or math.abs(heading)>3600 then return end
    for _,k in ipairs({'x','y','z'}) do
        if type(coords[k])~='number' or coords[k]~=coords[k] or math.abs(coords[k])>20000 then return end
    end
    if not near(src,coords) then return notify(src,'Floor position is too far away. Stand closer.','error') end
    if locks.rental or locks[id] then return notify(src,'Machine busy. Try again shortly.','error') end
    locks[id]=true
    local ok,err=xpcall(function()
        if MySQL.scalar.await('SELECT owner FROM ww_laundry_rentals WHERE washer=? OR dryer=?',{id,id}) then return notify(src,'End this machine rental before moving it.','error') end
        if MySQL.scalar.await('SELECT id FROM ww_laundry_batches WHERE machine=?',{id}) then
            return notify(src,'Collect the current batch before moving this machine.','error')
        end
        local h=heading%360
        local saved=MySQL.transaction.await({
            {query='INSERT INTO ww_laundry_props (id,x,y,z,h) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE x=VALUES(x),y=VALUES(y),z=VALUES(z),h=VALUES(h)',values={id,coords.x,coords.y,coords.z,h}},
            {query='UPDATE ww_laundry_machines SET x=?,y=?,z=? WHERE id=?',values={coords.x,coords.y,coords.z+Config.Bzzz.targetHeight,id}}
        })
        if not saved then return notify(src,'Could not save the Bzzz machine.','error') end
        local m=machines[id]
        m.x,m.y,m.z=coords.x,coords.y,coords.z+Config.Bzzz.targetHeight
        m.prop={id=id,x=coords.x,y=coords.y,z=coords.z,h=h}
        sync();notify(src,'Bzzz washer saved. Target it to start washing.','success')
    end,debug.traceback)
    locks[id]=nil
    if not ok then print(err);notify(src,'Placement failed. Check the server console for the database error.','error') end
end)

local function atDesk(src)
    return desk and near(src,desk)
end
local function canUseTablet(src) return atDesk(src) or inv:GetItemCount(src,'ww_wash_tablet')>0 end
registerCallback('ww_laundry:getTablet',function(src)
    if not ready or not atDesk(src) or not owner(src) then return {error='Stand beside the attendant.'} end
    if inv:GetItemCount(src,'ww_wash_tablet')>0 then return {ok=true} end
    if not inv:CanCarryItem(src,'ww_wash_tablet',1) then return {error='Make space for your tablet.'} end
    if not inv:AddItem(src,'ww_wash_tablet',1) then return {error='Could not hand over the tablet. Check the inventory item is installed.'} end
    return {ok=true}
end)
local function cleanPaidRentals()
    query("DELETE r FROM ww_laundry_rentals r JOIN ww_laundry_batches b ON b.id=r.batch WHERE b.stage='paid'")
end
registerCallback('ww_laundry:deskInfo',function() return {ready=ready,desk=desk} end)
registerCallback('ww_laundry:tablet',function(src)
    if not ready or not canUseTablet(src) then return {error='Collect a tablet from the rental attendant.'} end
    local cid=owner(src)
    if not cid then return {error='Character not ready.'} end
    cleanPaidRentals()
    local reservation=MySQL.single.await('SELECT * FROM ww_laundry_rentals WHERE owner=?',{cid})
    local status
    if reservation and reservation.batch then
        status=MySQL.single.await('SELECT * FROM ww_laundry_batches WHERE id=?',{reservation.batch})
        if status then status={stage=status.stage,remaining=math.max(0,status.ready-os.time())} end
    end
    local busyMachines={}
    for _,r in ipairs(query('SELECT washer,dryer FROM ww_laundry_rentals')) do busyMachines[r.washer]=true;busyMachines[r.dryer]=true end
    for _,b in ipairs(query('SELECT machine FROM ww_laundry_batches WHERE machine IS NOT NULL')) do busyMachines[b.machine]=true end
    local washers,dryers={},{}
    for id,m in pairs(machines) do
        if enabled(m) and not busyMachines[id] then
            local list=m.kind=='washer' and washers or dryers
            list[#list+1]=id
        end
    end
    table.sort(washers);table.sort(dryers)
    if reservation then reservation={washer=reservation.washer,dryer=reservation.dryer,state=reservation.state,batch=reservation.batch,fee=reservation.fee} end
    return {fee=Config.RentalFee,account=Config.RentalAccount,returnRate=math.floor(Config.ReturnRate*100),washSeconds=Config.WashSeconds,drySeconds=Config.DrySeconds,
        washers=washers,dryers=dryers,rental=reservation,status=status}
end)
registerCallback('ww_laundry:rent',function(src,washer,dryer)
    if not ready or not canUseTablet(src) then return {error='Collect a tablet from the rental attendant.'} end
    local cid=owner(src)
    if not cid or type(washer)~='string' or type(dryer)~='string' then return {error='Select a washer and dryer.'} end
    if locks.rental or locks[cid] or locks[washer] or locks[dryer] then return {error='Machines are being updated. Try again.'} end
    locks.rental=true
    local ok,result=xpcall(function()
        cleanPaidRentals()
        if not machines[washer] or not machines[washer].prop or machines[washer].kind~='washer' or not machines[dryer] or machines[dryer].kind~='dryer' then return {error='Invalid machine pair.'} end
        if MySQL.scalar.await('SELECT owner FROM ww_laundry_rentals WHERE owner=? OR washer=? OR dryer=?',{cid,washer,dryer}) then return {error='You or those machines already have a rental.'} end
        if MySQL.scalar.await('SELECT id FROM ww_laundry_batches WHERE machine=? OR machine=?',{washer,dryer}) then return {error='A machine still contains a batch.'} end
        if (exports.qbx_core:GetMoney(src,Config.RentalAccount) or 0)<Config.RentalFee then return {error='Not enough '..Config.RentalAccount..' for the rental fee.'} end
        query("INSERT INTO ww_laundry_rentals (owner,washer,dryer,state,fee) VALUES (?,?,?,'pending',?)",{cid,washer,dryer,Config.RentalFee})
        if owner(src)~=cid then error('Character changed during rental payment; inspect pending rental') end
        if not exports.qbx_core:RemoveMoney(src,Config.RentalAccount,Config.RentalFee,'wonkys-wash-rental') then
            query('DELETE FROM ww_laundry_rentals WHERE owner=?',{cid})
            return {error='Payment failed. No rental started.'}
        end
        query("UPDATE ww_laundry_rentals SET state='active' WHERE owner=?",{cid})
        return {message=('Paid $%s. Reserved %s and %s for one full batch.'):format(Config.RentalFee,washer,dryer)}
    end,debug.traceback)
    locks.rental=nil
    if not ok then print(result);return {error='Rental interrupted. Ask staff to check payment and pending rental; do not pay again.'} end
    return result
end)
registerCallback('ww_laundry:endRental',function(src)
    if not ready or not canUseTablet(src) then return {error='Collect a tablet from the attendant.'} end
    local cid=owner(src)
    if not cid or locks.rental or locks[cid] then return {error='Please wait.'} end
    locks.rental=true
    local ok,result=xpcall(function()
        cleanPaidRentals()
        local r=MySQL.single.await('SELECT * FROM ww_laundry_rentals WHERE owner=?',{cid})
        if not r then return {message='No active rental.'} end
        if r.batch or r.state~='active' or MySQL.scalar.await('SELECT id FROM ww_laundry_batches WHERE machine=? OR machine=?',{r.washer,r.dryer}) then return {error='Finish your full batch first, or ask staff about an interrupted rental.'} end
        query('DELETE FROM ww_laundry_rentals WHERE owner=?',{cid})
        return {message='Unused rental ended. The rental fee is non-refundable.'}
    end,debug.traceback)
    locks.rental=nil
    if not ok then print(result);return {error='Could not end rental.'} end
    return result
end)
RegisterNetEvent('ww_laundry:setDesk',function(coords,heading)
    local src=source
    if not ready or (not IsPlayerAceAllowed(src,'wonkys.moneywash.admin') and (not owner(src) or placementGrants[src]~=owner(src))) then return notify(src,'Placement permission required. Use washbzzzallow in server console.','error') end
    if type(coords)~='table' or type(heading)~='number' or heading~=heading or math.abs(heading)>3600 then return end
    for _,k in ipairs({'x','y','z'}) do if type(coords[k])~='number' or coords[k]~=coords[k] or math.abs(coords[k])>20000 then return end end
    if not near(src,coords) then return end
    local value={x=coords.x,y=coords.y,z=coords.z,h=heading%360}
    local ok,err=pcall(query,"INSERT INTO ww_laundry_settings (id,value) VALUES ('desk',?) ON DUPLICATE KEY UPDATE value=VALUES(value)",{json.encode(value)})
    if not ok then print(err);return notify(src,'Could not save rental desk.','error') end
    desk=value;TriggerClientEvent('ww_laundry:desk',-1,desk);notify(src,'Rental attendant position saved.','success')
end)

RegisterCommand('washbuild',function(src)
    if src~=0 then return end
    local resource=GetCurrentResourceName()
    local tablet=LoadResourceFile(resource,'tablet.lua')
    local manifest=LoadResourceFile(resource,'fxmanifest.lua') or ''
    print(('[Wonkys Wash] Running resource: %s | version: %s'):format(resource,GetResourceMetadata(resource,'version',0) or 'unknown'))
    print('[Wonkys Wash] Loaded directory: '..GetResourcePath(resource))
    print('[Wonkys Wash] tablet.lua present: '..tostring(tablet~=nil)..' | listed in manifest: '..tostring(manifest:find('tablet.lua',1,true)~=nil))
end,true)
