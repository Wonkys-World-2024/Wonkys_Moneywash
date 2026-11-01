local npc,tablet,opened,desk,deskVersion=nil,nil,false,nil,0
local function notice(text,kind) lib.notify({title='Wonkys Wash',description=text,type=kind or 'inform'}) end
local function close()
    opened=false;SetNuiFocus(false,false);SendNUIMessage({action='close'})
    if tablet and DoesEntityExist(tablet) then DeleteEntity(tablet) end
    tablet=nil
    StopAnimTask(cache.ped,'amb@world_human_seat_wall_tablet@female@base','base',2.0)
end
local function openTablet()
    if opened then return end
    local ok,data=pcall(lib.callback.await,'ww_laundry:tablet',false)
    if not ok or not data then return notice('Tablet unavailable. Check F8/server errors.','error') end
    if data.error then return notice(data.error,'error') end
    opened=true;SetNuiFocus(true,true);SendNUIMessage({action='open',data=data})
    CreateThread(function()
        local okModel=pcall(lib.requestModel,'prop_cs_tablet',3000)
        if okModel and opened then
            local pos=GetEntityCoords(cache.ped)
            tablet=CreateObjectNoOffset(joaat('prop_cs_tablet'),pos.x,pos.y,pos.z,false,false,false)
            SetEntityCollision(tablet,false,false)
            AttachEntityToEntity(tablet,cache.ped,GetPedBoneIndex(cache.ped,28422),0.0,0.0,0.03,0.0,0.0,0.0,true,true,false,true,1,true)
            SetModelAsNoLongerNeeded(joaat('prop_cs_tablet'))
        end
        if pcall(lib.requestAnimDict,'amb@world_human_seat_wall_tablet@female@base',3000) and opened then
            TaskPlayAnim(cache.ped,'amb@world_human_seat_wall_tablet@female@base','base',4.0,-4.0,-1,49,0,false,false,false)
        end
    end)
end
exports('openTablet',openTablet)
RegisterNUICallback('close',function(_,cb) close();cb({ok=true}) end)
local function bridge(name,fn)
    RegisterNUICallback(name,function(data,cb)
        if not opened then return cb({error='Tablet closed.'}) end
        local ok,result=pcall(fn,data)
        cb(ok and (result or {error='No server response.'}) or {error='Request failed. Check server logs.'})
    end)
end
bridge('refresh',function() return lib.callback.await('ww_laundry:tablet',false) end)
bridge('rent',function(data) return lib.callback.await('ww_laundry:rent',false,data.washer,data.dryer) end)
bridge('endRental',function() return lib.callback.await('ww_laundry:endRental',false) end)
local function setDesk(value)
    desk=value;deskVersion=deskVersion+1
    local generation=deskVersion
    if npc and DoesEntityExist(npc) then exports.ox_target:removeLocalEntity(npc);DeleteEntity(npc) end
    npc=nil
    if not desk then return end
    CreateThread(function()
        local ok=pcall(lib.requestModel,Config.DeskModel,5000)
        if not ok or generation~=deskVersion then return end
        -- Stored player standing position: subtract one metre for ped creation.
        npc=CreatePed(4,joaat(Config.DeskModel),desk.x,desk.y,desk.z-1.0,desk.h,false,true)
        SetEntityInvincible(npc,true);FreezeEntityPosition(npc,true);SetBlockingOfNonTemporaryEvents(npc,true)
        TaskStartScenarioInPlace(npc,'WORLD_HUMAN_CLIPBOARD',0,true)
        SetModelAsNoLongerNeeded(joaat(Config.DeskModel))
        exports.ox_target:addLocalEntity(npc,{{name='ww_wash_attendant',label='Wonkys Wash | Get rental tablet',icon='fas fa-tablet-screen-button',distance=2.5,onSelect=function()
            local result=lib.callback.await('ww_laundry:getTablet',false)
            if result and result.error then return notice(result.error,'error') end
            openTablet()
        end}})
    end)
end
RegisterNetEvent('ww_laundry:desk',setDesk)
CreateThread(function()
    Wait(2000)
    for attempt=1,30 do
        local ok,result=pcall(lib.callback.await,'ww_laundry:deskInfo',false)
        if ok and result and result.ready then setDesk(result.desk);return end
        Wait(2000)
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    deskVersion=deskVersion+1;close()
    if npc and DoesEntityExist(npc) then exports.ox_target:removeLocalEntity(npc);DeleteEntity(npc) end
end)
CreateThread(function()
    while true do
        if opened and (IsEntityDead(cache.ped) or IsPedInAnyVehicle(cache.ped,false)) then close() end
        Wait(500)
    end
end)

exports('tabletReady',function() return true end)
print('[Wonkys Wash 1.4.0] Tablet client loaded.')
