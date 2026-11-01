Config = {}
Config.Title = "Wonkys Wash"
-- Count-based dirty currency: ONE item = ONE dollar. Not markedbills metadata.
Config.DirtyItem = 'black_money'
Config.WetItem = 'ww_wet_cash'
Config.MinBatch = 1000
Config.MaxBatch = 50000
Config.ReturnRate = 0.80 -- 20% laundering cut; fixed at wash start
Config.WashSeconds = 180
Config.DrySeconds = 180
Config.Distance = 2.5
Config.MaxActive = 2 -- per character, across washers and dryers
-- Coordinates supplied are standing positions, facing towards each machine.
-- FrontOffset and Height convert them into target centres at the machine fronts.
Config.FrontOffset = 0.65
Config.TargetHeight = {washer=1.0, dryer=0.75}
-- Narrow across each machine, deep enough to catch the MLO's collision face.
Config.TargetBox = {washer=vec3(0.90,1.80,2.0), dryer=vec3(0.54,1.80,1.65)}
Config.TargetDebug = false
-- Washer IDs are placeholders until placed; no original washer coordinates remain.
Config.WasherIds = {'washer1','washer2','washer3','washer4'}
Config.Layout = {
    dryer1 = {kind='dryer', standing=vec4(1138.22,-991.98,46.11,279.10)},
    dryer2 = {kind='dryer', standing=vec4(1138.22,-991.33,46.11,281.42)},
    dryer3 = {kind='dryer', standing=vec4(1138.11,-990.59,46.11,279.65)},
    dryer4 = {kind='dryer', standing=vec4(1138.02,-989.84,46.11,278.88)},
}
-- Bzzz props stay in a separate resource. Place a washer on clear floor with
-- /washbzzz washer1 [heading]. Aim at the floor where its base should sit.
Config.Bzzz = {idle='bzzz_money_washing_a',running='bzzz_money_washing_d',
    drawDistance=30.0, targetHeight=0.65, showTimer=true}
-- Only placed Bzzz washers are enabled. Original MLO washer targets are disabled.
-- No map blips or polygon wash overlays are created.

Config.RentalFee = 500 -- paid ONCE per batch, separately from the laundering cut
Config.RentalAccount = 'cash'
Config.DeskModel = 's_f_y_shop_mid'
-- Set the NPC location in-game using /washdesk with placement permission.

-- Cosmetic money-bag handling. No separate bag item is required.
Config.BagHandling = {
    fullModel='bzzz_money_bag_b', emptyModel='bzzz_money_bag_a',
    loadSeconds=8, unloadSeconds=6,
    -- Adjust only if the Bzzz bag needs aligning with the character's right hand.
    handBone=57005, handOffset=vec3(0.12,0.02,-0.12),
    handRotation=vec3(0.0,90.0,0.0),
    floorForward=0.45, floorRight=0.04, floorZ=-1.0,
}
