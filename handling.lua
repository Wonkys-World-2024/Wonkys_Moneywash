-- Cosmetic bag sequence. Only the existing server callback can transfer currency.
local bag,active=false,false
local function removeBag()
    if bag and DoesEntityExist(bag) then DeleteEntity(bag) end
    bag=nil
end
local function spawnBag(model,ped,attached)
    lib.requestModel(model,5000)
    removeBag()
    local cfg=Config.BagHandling
    local pos=GetOffsetFromEntityInWorldCoords(ped,cfg.floorRight,cfg.floorForward,cfg.floorZ)
    bag=CreateObjectNoOffset(joaat(model),pos.x,pos.y,pos.z,false,false,false)
    SetModelAsNoLongerNeeded(joaat(model))
    if bag==0 then bag=nil;error('Could not create money bag') end
    SetEntityAsMissionEntity(bag,true,true)
    SetEntityCollision(bag,false,false)
    if attached then
        local o,r=cfg.handOffset,cfg.handRotation
        AttachEntityToEntity(bag,ped,GetPedBoneIndex(ped,cfg.handBone),o.x,o.y,o.z,r.x,r.y,r.z,true,true,false,true,1,true)
    else
        SetEntityHeading(bag,GetEntityHeading(ped))
        FreezeEntityPosition(bag,true)
    end
end
local function progress(duration,label,dict,clip)
    return lib.progressCircle({duration=duration,label=label,position='bottom',canCancel=true,
        useWhileDead=false,disable={move=true,car=true,combat=true},
        anim=dict and {dict=dict,clip=clip,flag=0} or nil})
end
function WonkysBagAction(machine,action)
    if active then return false end
    active=true
    local ped=cache.ped
    local ok,result=xpcall(function()
        if IsPedInAnyVehicle(ped,false) or IsEntityDead(ped) then return false end
        local cfg=Config.BagHandling
        -- Preload both variants before showing the progress sequence.
        for _,model in ipairs({cfg.fullModel,cfg.emptyModel}) do
            lib.requestModel(model,5000);SetModelAsNoLongerNeeded(joaat(model))
        end
        local unloading=action=='collect'
        local duration=math.max(3000,math.floor((unloading and cfg.unloadSeconds or cfg.loadSeconds)*1000))
        local pickup='pickup_object'
        local work=unloading and 'anim@heists@ornate_bank@grab_cash' or 'bzzz_money_washmoney'
        local clip=unloading and 'grab' or 'bzzz_money_washmoney'
        lib.requestAnimDict(pickup,5000);lib.requestAnimDict(work,5000)
        if machine then TaskTurnPedToFaceCoord(ped,machine.x,machine.y,machine.z,500) end
        if unloading then
            -- Fill the open bag beside the character, then pick it up.
            spawnBag(cfg.emptyModel,ped,false)
            if not progress(duration-2600,'Packing notes into the money bag...',work,clip) then return false end
            spawnBag(cfg.fullModel,ped,false)
            if not progress(1600,'Picking up your bag of bills...',pickup,'pickup_low') then return false end
            spawnBag(cfg.fullModel,ped,true)
            if not progress(1000,'Bag of bills collected...',nil,nil) then return false end
        else
            spawnBag(cfg.fullModel,ped,false)
            if not progress(1600,'Picking up the bag of bills...',pickup,'pickup_low') then return false end
            spawnBag(cfg.fullModel,ped,true)
            if not progress(duration-2600,action=='dry' and 'Loading wet bills from the bag...' or 'Emptying the bag into the washer...',work,clip) then return false end
            spawnBag(cfg.emptyModel,ped,true)
            if not progress(1000,'Putting the empty bag away...',pickup,'pickup_low') then return false end
        end
        return true
    end,debug.traceback)
    -- Always clean up, including cancellation, missing assets and callback errors.
    removeBag()
    StopAnimTask(ped,'pickup_object','pickup_low',2.0)
    StopAnimTask(ped,'bzzz_money_washmoney','bzzz_money_washmoney',2.0)
    StopAnimTask(ped,'anim@heists@ornate_bank@grab_cash','grab',2.0)
    active=false
    if not ok then
        print('[Wonkys Wash] Money bag animation failed: '..tostring(result))
        lib.notify({title=Config.Title,description='Could not load the bag animation. Check F8. No transfer requested.',type='error'})
        return false
    end
    return result==true
end
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() and name~='bzzz_money' then return end
    if active and lib.progressActive() then lib.cancelProgress() end
    removeBag()
    if active then
        StopAnimTask(cache.ped,'pickup_object','pickup_low',2.0)
        StopAnimTask(cache.ped,'bzzz_money_washmoney','bzzz_money_washmoney',2.0)
        StopAnimTask(cache.ped,'anim@heists@ornate_bank@grab_cash','grab',2.0)
    end
end)
