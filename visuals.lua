-- Bzzz animated washer props. Server state decides idle/running; no money logic here.
-- Local non-networked replicas avoid network ownership changes and duplicate spawns.
local cycles, fetched, machineList, spawned = {}, 0, {}, {}
local stopping=false
local function remove(id)
    local old=spawned[id]
    if old and DoesEntityExist(old.entity) then DeleteEntity(old.entity) end
    spawned[id]=nil
end
local function spawn(id,m,running)
    local model=joaat(running and Config.Bzzz.running or Config.Bzzz.idle)
    local ok,err=pcall(lib.requestModel,model,5000)
    if not ok then print('[Wonkys_MoneyWash] Bzzz model unavailable: '..tostring(err));return end
    if stopping then SetModelAsNoLongerNeeded(model);return end
    local prop=m.prop
    -- Keep the current object until its replacement model has loaded.
    remove(id)
    local entity=CreateObjectNoOffset(model,prop.x,prop.y,prop.z,false,false,false)
    if entity==0 then SetModelAsNoLongerNeeded(model);return end
    SetEntityHeading(entity,prop.h)
    FreezeEntityPosition(entity,true)
    SetEntityAsMissionEntity(entity,true,true)
    SetEntityCollision(entity,true,true)
    spawned[id]={entity=entity,running=running,x=prop.x,y=prop.y,z=prop.z,h=prop.h}
    -- bzzz_money_washing_d starts its money animation automatically, per pack docs.
    SetModelAsNoLongerNeeded(model)
end
local function label(pos,text)
    SetDrawOrigin(pos.x,pos.y,pos.z,0)
    SetTextScale(0.0,0.25);SetTextFont(4);SetTextCentre(true)
    SetTextColour(65,190,255,220);SetTextOutline()
    BeginTextCommandDisplayText('STRING');AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0,0.0);ClearDrawOrigin()
end
CreateThread(function()
    while not stopping do
        machineList=exports[GetCurrentResourceName()]:LaundryMachines()
        local nearby=false
        local pos=GetEntityCoords(cache.ped)
        for _,m in pairs(machineList) do
            if #(pos-vec3(m.x,m.y,m.z))<25 then nearby=true;break end
        end
        if nearby then
            local ok,result=pcall(lib.callback.await,'ww_laundry:visuals',false)
            if ok and result then cycles=result;fetched=GetGameTimer() end
        else cycles={} end
        Wait(2500)
    end
end)
CreateThread(function()
    while not stopping do
        local pos,now=GetEntityCoords(cache.ped),GetGameTimer()
        for id,old in pairs(spawned) do
            local m=machineList[id]
            if not m or not m.prop or #(pos-vec3(m.x,m.y,m.z))>Config.Bzzz.drawDistance or GetResourceState('bzzz_money')~='started' then remove(id) end
        end
        if GetResourceState('bzzz_money')=='started' then
            for id,m in pairs(machineList) do
                if m.prop and #(pos-vec3(m.x,m.y,m.z))<=Config.Bzzz.drawDistance then
                    local state=cycles[id]
                    local running=state~=nil and state.stage=='washing' and now-fetched<10000 and state.remaining-(now-fetched)/1000>0
                    local old,prop=spawned[id],m.prop
                    if not old or not DoesEntityExist(old.entity) or old.running~=running or old.x~=prop.x or old.y~=prop.y or old.z~=prop.z or old.h~=prop.h then spawn(id,m,running) end
                end
            end
        end
        Wait(500)
    end
end)
CreateThread(function()
    while not stopping do
        local delay=500
        local now,pos=GetGameTimer(),GetEntityCoords(cache.ped)
        if Config.Bzzz.showTimer and now-fetched<10000 then
            for id,state in pairs(cycles) do
                local m=machineList[id]
                if m and #(pos-vec3(m.x,m.y,m.z))<12 then
                    delay=0
                    local remaining=math.max(0,math.ceil(state.remaining-(now-fetched)/1000))
                    local z=m.prop and m.prop.z+1.20 or m.z-0.25
                    label(vec3(m.x,m.y,z),remaining>0 and ('%s %02d:%02d'):format(state.stage=='washing' and 'WASH' or 'DRY',math.floor(remaining/60),remaining%60) or 'READY TO COLLECT')
                end
            end
        end
        Wait(delay)
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() and name~='bzzz_money' then return end
    if name==GetCurrentResourceName() then stopping=true end
    for id in pairs(spawned) do remove(id) end
end)
