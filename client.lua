local zones, busy = {}, false
local machineList = {}
local function tell(msg, kind) lib.notify({title=Config.Title,description=msg,type=kind or 'inform'}) end
-- Keep setup commands in the main client, independent of tablet/NUI startup.
RegisterCommand('washdesk',function()
    local pos=GetEntityCoords(cache.ped)
    print('[Wonkys Wash 1.4.0] Sending attendant placement to server.')
    tell('Saving rental attendant here...')
    TriggerServerEvent('ww_laundry:setDesk',{x=pos.x,y=pos.y,z=pos.z},GetEntityHeading(cache.ped))
end,false)
RegisterCommand('washcheck',function()
    local ok,result=pcall(function() return exports[GetCurrentResourceName()]:tabletReady() end)
    local state=ok and result and 'ready' or 'NOT LOADED: inspect F8 errors above'
    print('[Wonkys Wash 1.4.0] Main client loaded. Tablet: '..state)
    tell('Main client 1.4.0 | Tablet '..state,ok and result and 'success' or 'error')
end,false)
print('[Wonkys Wash 1.4.0] Main client loaded; washdesk and washcheck registered.')
local function act(id, action, value)
    if busy then return end
    busy = true
    local ok,err=xpcall(function()
        local completed=WonkysBagAction(machineList[id],action)
        if completed then
            local result=lib.callback.await('ww_laundry:act',false,id,action,value)
            if result then tell(result.error or result.message,result.error and 'error' or 'success') end
        end
    end,debug.traceback)
    busy=false
    if not ok then print(err);tell('Action interrupted. Check F8/server messages before retrying.','error') end
end

local function open(id)
    if busy then return end
    local status = lib.callback.await('ww_laundry:inspect', false, id)
    if not status then return end
    if status.error then return tell(status.error,'error') end
    local options = {}
    if status.free and status.kind == 'washer' then
        options[1] = {title='Load dirty money',icon='money-bill-wave',description=('Wash %s–%s | Return %s%% | %ss wash + %ss dry'):format(Config.MinBatch,Config.MaxBatch,math.floor(Config.ReturnRate*100),Config.WashSeconds,Config.DrySeconds),onSelect=function()
            local input = lib.inputDialog(Config.Title, {{type='number',label='Dirty money amount',min=Config.MinBatch,max=Config.MaxBatch,required=true}})
            if input then act(id,'wash',input[1]) end
        end}
    elseif status.free then
        for _, item in pairs(exports.ox_inventory:Search('slots',Config.WetItem) or {}) do
            local slot = item.slot
            options[#options+1] = {title='Dry wet bundle #'..tostring(item.metadata.batch or '?'),description=item.metadata.description,icon='wind',onSelect=function() act(id,'dry',slot) end}
        end
        if #options == 0 then options[1]={title='No wet money bundles',description='Wash dirty money and collect the wet bundle first.',disabled=true} end
    else
        local valid = status.stage=='washing' or status.stage=='drying'
        options[1] = {title=not valid and 'Administrator recovery required' or status.remaining>0 and ('Cycle running: %ss remaining'):format(status.remaining) or 'Collect finished batch',icon='clock',description=('Batch #%s | Clean return $%s'):format(status.batch,status.payout),disabled=not valid or status.remaining>0,onSelect=function() act(id,'collect') end}
    end
    lib.registerContext({id='ww_laundry_menu',title=Config.Title..' | '..id,options=options})
    lib.showContext('ww_laundry_menu')
end
local function setup(machines)
    for _, zone in pairs(zones) do exports.ox_target:removeZone(zone) end
    zones = {}
    machineList = machines
    for id, m in pairs(machines) do
        if m.kind=='dryer' or m.prop then
        local machineId = id
        local entry = Config.Layout[id]
        zones[id] = exports.ox_target:addBoxZone({
            coords=vec3(m.x,m.y,m.z),
            size=Config.TargetBox[m.kind],
            rotation=m.prop and m.prop.h or (entry and entry.standing.w or 0),
            debug=Config.TargetDebug,
            drawSprite=false,
            options={{name='ww_laundry_'..id,
                label=(m.kind=='washer' and 'Use washing machine | ' or 'Use dryer | ')..id,
                icon=m.kind=='washer' and 'fas fa-soap' or 'fas fa-wind',
                distance=Config.Distance,
                onSelect=function() open(machineId) end}}
        })
        end
    end
end
RegisterNetEvent('ww_laundry:machines', setup)
local function loadMachines()
    for attempt=1,30 do
        local ok, result = pcall(lib.callback.await, 'ww_laundry:list', false)
        if ok and result and next(result) then
            setup(result)
            print(('[Wonkys_MoneyWash] Machine targets loaded (%s attempts).'):format(attempt))
            return
        end
        Wait(2000)
    end
    print('[Wonkys_MoneyWash] No machines loaded. Check server console and SQL import; use /washreload after resolving.')
end
CreateThread(function() Wait(1500); loadMachines() end)
AddEventHandler('onClientResourceStart', function(name)
    if name=='ox_target' then CreateThread(function() Wait(1000); loadMachines() end) end
end)
RegisterCommand('washreload',function() CreateThread(loadMachines) end,false)
RegisterCommand('laundry',function(_,args)
    local pos,best,bestDistance=GetEntityCoords(cache.ped),nil,Config.Distance
    for id,m in pairs(machineList) do
        local distance=#(pos-vec3(m.x,m.y,m.z))
        if (m.kind=='dryer' or m.prop) and distance<=bestDistance and (not args[1] or args[1]==id) then
            best,bestDistance=id,distance
        end
    end
    if best then open(best) else tell('No loaded machine within reach. Use /washreload if targets are missing.','error') end
end,false)
RegisterCommand('washplace', function(_, args)
    if (args[1]~='washer' and args[1]~='dryer') or not args[2] then return tell('/washplace washer washer1 OR /washplace dryer dryer1') end
    local raycast = lib.raycast.fromCamera or lib.raycast.cam
    local hit, _, coords = raycast(511,4,5)
    if not hit or #(GetEntityCoords(cache.ped)-coords)>Config.Distance then return tell('Stand close and aim at the machine front.','error') end
    TriggerServerEvent('ww_laundry:place',args[1],args[2],{x=coords.x,y=coords.y,z=coords.z})
end, false)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    for _, zone in pairs(zones) do exports.ox_target:removeZone(zone) end
end)

exports('LaundryMachines', function() return machineList end)

RegisterCommand('washbzzz',function(_,args)
    local id=args[1]
    if not id or not machineList[id] or machineList[id].kind~='washer' then
        return tell('/washbzzz washer1 [heading] — aim at a CLEAR FLOOR location','error')
    end
    if GetResourceState('bzzz_money')~='started' then return tell('Start bzzz_money first.','error') end
    for _,name in ipairs({Config.Bzzz.idle,Config.Bzzz.running}) do
        local hash=joaat(name)
        if not IsModelInCdimage(hash) or not IsModelValid(hash) then return tell('Bzzz model not registered: '..name..'. Check bzzz_money and restart the server.','error') end
        local ok,err=pcall(lib.requestModel,hash,5000)
        if not ok then print(err);return tell('Could not load Bzzz model '..name..'. See F8.','error') end
        SetModelAsNoLongerNeeded(hash)
    end
    local raycast=lib.raycast.fromCamera or lib.raycast.cam
    local hit,_,coords=raycast(511,4,5)
    if not hit or #(GetEntityCoords(cache.ped)-coords)>Config.Distance then
        return tell('Stand close and aim at the clear FLOOR where the washer should sit.','error')
    end
    local heading=tonumber(args[2]) or GetEntityHeading(cache.ped)
    tell('Bzzz models loaded. Requesting saved placement...')
    TriggerServerEvent('ww_laundry:placeBzzz',id,{x=coords.x,y=coords.y,z=coords.z},heading)
end,false)
