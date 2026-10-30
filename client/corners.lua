-- DPS 2026-10-29 (Damon): street girls who work the pavement outside the night spots,
-- call out to people walking past, and hand over to the existing car flow (E) when a
-- car stops beside them. They are LOCAL peds like the pimp's girl (each client sees its
-- own), so nothing to clean on the server. Never in the street: every spot is snapped
-- to pavement and refused near a road node or a parked car.

local corners = Config.Corners or {}
local cornerCfg = Config.Corner or {}
local girls = {}          -- cornerIdx -> { peds = { ped, ... } }
local lastCallAt = 0
local floating = nil      -- { ped = , text = , until = }
local unicornBlip = nil
local SCEN = { low = 'WORLD_HUMAN_PROSTITUTE_LOW_CLASS', high = 'WORLD_HUMAN_PROSTITUTE_HIGH_CLASS' }

local function isNight()
    local n = Config.Night or { start = 21, stop = 5 }
    local h = GetClockHours()
    if n.start > n.stop then return h >= n.start or h < n.stop end
    return h >= n.start and h < n.stop
end

---The street rule. Returns a pavement point near x,y,z or nil.
local function pavementSpot(x, y, z)
    local rule = Config.StreetRule or {}
    local roadMin, vehMin = rule.roadNodeMin or 3.0, rule.vehicleMin or 5.0
    local ok, px, py, pz = GetSafeCoordForPed(x, y, z, true, 16)
    if not ok then ok, px, py, pz = GetSafeCoordForPed(x, y, z, false, 16) end
    if not ok then return nil end
    -- (bool, vector3, heading) on this build; pcall-guarded against a pathfind fault.
    local got, found, node = pcall(GetClosestVehicleNodeWithHeading, px, py, pz, 1, 3.0, 0)
    if got and found and node then
        local away = vector3(px - node.x, py - node.y, 0.0)
        local d = #away
        if d < roadMin then
            if d < 0.1 then return nil end
            away = away / d
            px, py = node.x + away.x * (roadMin + 0.5), node.y + away.y * (roadMin + 0.5)
            local g, gz = GetGroundZFor_3dCoord(px, py, pz + 2.0, false)
            if g then pz = gz end
        end
    end
    if GetClosestVehicle(px, py, pz, vehMin, 0, 70) ~= 0 then return nil end
    return vector3(px, py, pz)
end

local function loadModelHash(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    lib.requestModel(hash, 5000)
    return hash
end

local function sayLine(ped)
    local lines = Config.CallOuts or {}
    if #lines == 0 then return end
    local line = lines[math.random(#lines)]
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), 2000)
    PlayAmbientSpeech1(ped, "Hooker_Offer_Again", "Speech_Params_Force")
    floating = { ped = ped, text = line, till = GetGameTimer() + 3500 }
end

local function spawnCorner(idx)
    local c = corners[idx]
    local set = { peds = {} }
    for i = 1, (c.count or 1) do
        local off = (i - 1) * 2.2
        local spot = pavementSpot(c.coords.x + off, c.coords.y - off, c.coords.z)
        if spot then
            local model = loadModelHash(Config.HookerModels[math.random(#Config.HookerModels)])
            if model then
                -- heading: face the road (towards the nearest vehicle node)
                local heading = 0.0
                local gotN, foundN, node = pcall(GetClosestVehicleNodeWithHeading, spot.x, spot.y, spot.z, 1, 3.0, 0)
                if gotN and foundN and node then heading = GetHeadingFromVector_2d(node.x - spot.x, node.y - spot.y) end
                local ped = CreatePed(0, model, spot.x, spot.y, spot.z, heading, false, true)
                if DoesEntityExist(ped) then
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetEntityInvincible(ped, true)
                    SetPedCanRagdollFromPlayerImpact(ped, false)
                    TaskStartScenarioInPlace(ped, SCEN[c.style or 'low'] or SCEN.low, 0, true)
                    Entity(ped).state:set('type', 'dps_hooker', false)
                    Entity(ped).state:set('corner', idx, false)
                    exports.ox_target:addLocalEntity(ped, { {
                        name = 'dps_hooker_corner',
                        icon = 'fa-solid fa-comment',
                        label = 'Talk',
                        distance = 2.5,
                        canInteract = function()
                            return HookerAgeOk() and (HookerActive() == nil or HookerActive() == ped)
                        end,
                        onSelect = function()
                            sayLine(ped)
                            if HookerAttach(ped) then
                                lib.notify({ title = 'DPS Hookers', description = 'Pull up in a car, sugar.', type = 'inform' })
                            end
                        end,
                    } })
                    set.peds[#set.peds + 1] = ped
                end
                SetModelAsNoLongerNeeded(model)
            end
        end
    end
    girls[idx] = set
end

local function removeCorner(idx)
    local set = girls[idx]
    if not set then return end
    for _, ped in ipairs(set.peds) do
        if DoesEntityExist(ped) then
            if HookerActive() == ped then HookerDetach(ped) end
            exports.ox_target:removeLocalEntity(ped, 'dps_hooker_corner')
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
    girls[idx] = nil
end

-- Corners come and go with distance and the clock.
CreateThread(function()
    while not Bridge.IsPlayerLoaded() do Wait(500) end
    if cornerCfg.blip and Config.PimpLocation then
        local b = cornerCfg.blip
        unicornBlip = AddBlipForCoord(Config.PimpLocation.x, Config.PimpLocation.y, Config.PimpLocation.z)
        SetBlipSprite(unicornBlip, b.sprite or 121); SetBlipColour(unicornBlip, b.colour or 48)
        SetBlipScale(unicornBlip, b.scale or 0.8); SetBlipAsShortRange(unicornBlip, true)
        BeginTextCommandSetBlipName("STRING"); AddTextComponentString(b.label or 'Vanilla Unicorn'); EndTextCommandSetBlipName(unicornBlip)
    end
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local night = isNight()
        for idx, c in ipairs(corners) do
            local dist = #(me - c.coords)
            local wanted = (night or c.allDay) and dist < (cornerCfg.spawnRange or 120.0)
            if wanted and not girls[idx] then
                spawnCorner(idx)
            elseif girls[idx] then
                local active = HookerActive()
                local holding = false
                for _, ped in ipairs(girls[idx].peds) do if ped == active then holding = true end end
                if not holding and (dist > (cornerCfg.despawnRange or 170.0) or not (night or c.allDay)) then
                    removeCorner(idx)
                end
            end
        end
        Wait(2000)
    end
end)

-- Enticing passers-by, and handing a stopped car to the existing E flow.
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local me = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        local now = GetGameTimer()
        for idx, set in pairs(girls) do
            for _, g in ipairs(set.peds) do
                if DoesEntityExist(g) then
                    local d = #(me - GetEntityCoords(g))
                    if veh == 0 then
                        if d < (cornerCfg.callRange or 12.0) and now - lastCallAt > (cornerCfg.callCooldown or 60000) and HookerAgeOk() then
                            lastCallAt = now
                            sayLine(g)
                        end
                    elseif GetPedInVehicleSeat(veh, -1) == ped and HookerAgeOk() then
                        if HookerActive() == nil and d < (cornerCfg.attachRange or 10.0) and GetEntitySpeed(veh) < 1.0 then
                            HookerAttach(g)   -- the main loop now shows "press E" and runs the ride
                        elseif HookerActive() == g and d > (cornerCfg.detachRange or 40.0) and not IsPedInAnyVehicle(g, false) then
                            HookerDetach(g)   -- drove off without her: she goes back to her corner
                        end
                    end
                    if d < 20.0 then sleep = 250 end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Floating line above her head while she speaks.
CreateThread(function()
    while true do
        if floating and DoesEntityExist(floating.ped) and GetGameTimer() < floating.till then
            local c = GetEntityCoords(floating.ped)
            local onScreen, sx, sy = World3dToScreen2d(c.x, c.y, c.z + 1.05)
            if onScreen then
                SetTextScale(0.33, 0.33); SetTextFont(4); SetTextProportional(1)
                SetTextColour(255, 255, 255, 230); SetTextCentre(true); SetTextEntry("STRING")
                AddTextComponentString(floating.text); DrawText(sx, sy)
                local factor = string.len(floating.text) / 370
                DrawRect(sx, sy + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
            end
            Wait(0)
        else
            floating = nil
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for idx in pairs(girls) do removeCorner(idx) end
    if unicornBlip then RemoveBlip(unicornBlip) end
end)
