--[[ ===================================================== ]]--
--[[       DPS Hookers - Client Controller                ]]--
--[[       Optimized for high-population servers          ]]--
--[[ ===================================================== ]]--

-- State tracking
local hooker = nil
local pimp = nil
local hookerBlip = nil
local isSignaling = false
local isBusy = false
local ageVerified = false

-- Performance: Cached values (updated once per cycle)
local cachedPed = nil
local cachedCoords = nil
local cachedVehicle = nil
local lastCacheUpdate = 0
local CACHE_INTERVAL = 100  -- Update cache every 100ms

-- LOD System: Only run intensive checks when near interaction points
local isNearPimp = false
local isNearHooker = false
local stripClubZone = nil

-- Performance thresholds
local DIST_INTERACTION = 5.0    -- Close enough to interact
local DIST_NEAR = 25.0          -- Near NPC
local DIST_MEDIUM = 75.0        -- Medium range
local DIST_FAR = 150.0          -- Far - cleanup range

--[[ ===================================================== ]]--
--[[                  PERFORMANCE UTILITIES                ]]--
--[[ ===================================================== ]]--

--- Update cached values (call sparingly)
local function updateCache()
    local now = GetGameTimer()
    if now - lastCacheUpdate < CACHE_INTERVAL then return end

    cachedPed = PlayerPedId()
    cachedCoords = GetEntityCoords(cachedPed)
    cachedVehicle = GetVehiclePedIsIn(cachedPed, false)
    lastCacheUpdate = now
end

--- Get cached player ped (or fresh if cache stale)
---@return number
local function getCachedPed()
    if not cachedPed then
        cachedPed = PlayerPedId()
    end
    return cachedPed
end

--- Get cached coords (or fresh if cache stale)
---@return vector3
local function getCachedCoords()
    if not cachedCoords then
        cachedCoords = GetEntityCoords(getCachedPed())
    end
    return cachedCoords
end

--[[ ===================================================== ]]--
--[[                  UTILITY FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

--- Load model with waiting
---@param model string|number Model hash or name
---@return boolean
local function loadModel(model)
    local modelHash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(modelHash) then return false end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    return HasModelLoaded(modelHash)
end

--- Load animation dictionary
---@param dict string Animation dictionary name
---@return boolean
local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    return HasAnimDictLoaded(dict)
end

--- Play animation on entity
---@param entity number Entity handle
---@param dict string Animation dictionary
---@param name string Animation name
local function playAnim(entity, dict, name)
    if not DoesEntityExist(entity) or IsEntityDead(entity) then return end

    if loadAnimDict(dict) then
        TaskPlayAnim(entity, dict, name, 1.0, -1.0, -1, 1, 1, true, true, true)
    end
end

--- Draw 3D text above coordinates (only when very close)
---@param coords vector3 Coordinates
---@param text string Text to display
local function draw3DText(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(screenX, screenY)

        local factor = (string.len(text)) / 370
        DrawRect(screenX, screenY + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

--[[ ===================================================== ]]--
--[[                    NPC MANAGEMENT                     ]]--
--[[ ===================================================== ]]--

--- Delete hooker NPC with delay
local function deleteHooker()
    if not hooker then return end

    local hookerEntity = hooker
    local randomDelay = math.random(3000, 6000)

    -- Clear state bag
    if DoesEntityExist(hookerEntity) then
        Entity(hookerEntity).state:set('owner', nil, true)
    end

    SetTimeout(randomDelay, function()
        if DoesEntityExist(hookerEntity) then
            SetEntityAsMissionEntity(hookerEntity, true, true)
            DeleteEntity(hookerEntity)
        end
    end)

    hooker = nil
    isNearHooker = false

    if hookerBlip then
        RemoveBlip(hookerBlip)
        hookerBlip = nil
    end
end

--- Create hooker NPC at spawn location
local function createHooker()
    if hooker then
        lib.notify({
            title = 'DPS Hookers',
            description = lib.locale('notifications.already_busy'),
            type = 'error'
        })
        return
    end

    -- Random model selection
    local modelIndex = math.random(1, #Config.HookerModels)
    local model = Config.HookerModels[modelIndex]

    if not loadModel(model) then
        lib.notify({
            title = 'DPS Hookers',
            description = 'Failed to load hooker model',
            type = 'error'
        })
        return
    end

    -- Create ped
    local coords = Config.HookerSpawn
    hooker = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, true, true)

    if not DoesEntityExist(hooker) then return end

    -- Configure ped
    SetBlockingOfNonTemporaryEvents(hooker, true)
    SetEntityInvincible(hooker, true)
    FreezeEntityPosition(hooker, true)
    TaskStartScenarioInPlace(hooker, "WORLD_HUMAN_SMOKING", 0, false)

    -- Set state bag for ownership tracking
    Entity(hooker).state:set('owner', GetPlayerServerId(PlayerId()), true)
    Entity(hooker).state:set('type', 'dps_hooker', true)

    -- Create blip
    hookerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(hookerBlip, 280)
    SetBlipScale(hookerBlip, 0.8)
    SetBlipColour(hookerBlip, 48)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hooker")
    EndTextCommandSetBlipName(hookerBlip)

    -- Set waypoint
    SetNewWaypoint(coords.x, coords.y)

    lib.notify({
        title = 'DPS Hookers',
        description = lib.locale('hooker.approaching'),
        type = 'success'
    })

    SetModelAsNoLongerNeeded(model)
end

--- Create pimp NPC at strip club
local function createPimp()
    if pimp then return end

    local model = Config.PimpModel
    if not loadModel(model) then return end

    loadAnimDict("mini@strip_club@idles@bouncer@base")

    local coords = Config.PimpLocation
    pimp = CreatePed(1, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)

    if not DoesEntityExist(pimp) then return end

    -- Configure pimp
    FreezeEntityPosition(pimp, true)
    SetEntityInvincible(pimp, true)
    SetBlockingOfNonTemporaryEvents(pimp, true)
    TaskPlayAnim(pimp, "mini@strip_club@idles@bouncer@base", "base", 8.0, 0.0, -1, 1, 0, 0, 0, 0)

    -- Set state bag
    Entity(pimp).state:set('type', 'dps_pimp', true)

    -- Add ox_target interaction
    exports.ox_target:addLocalEntity(pimp, {
        {
            name = 'dps_hooker_pimp',
            icon = lib.locale('pimp.target_icon'),
            label = lib.locale('pimp.target_label'),
            onSelect = function()
                createHooker()
            end,
            canInteract = function()
                return hooker == nil and GetVehiclePedIsIn(getCachedPed(), false) == 0
            end,
            distance = 2.5
        }
    })

    SetModelAsNoLongerNeeded(model)
end

--- Delete pimp NPC
local function deletePimp()
    if not pimp then return end

    if DoesEntityExist(pimp) then
        exports.ox_target:removeLocalEntity(pimp, 'dps_hooker_pimp')
        SetEntityAsMissionEntity(pimp, true, true)
        DeleteEntity(pimp)
    end

    pimp = nil
end

--[[ ===================================================== ]]--
--[[                  SERVICE FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

--- Make hooker enter player's vehicle
---@param vehicle number Vehicle handle
local function hookerEnterVehicle(vehicle)
    if not hooker or not DoesEntityExist(hooker) then return end

    isSignaling = true
    isBusy = true

    -- Freeze vehicle while hooker gets in
    FreezeEntityPosition(vehicle, true)

    -- Voice line
    PlayAmbientSpeech1(hooker, "Generic_Hows_It_Going", "Speech_Params_Force")

    -- Unfreeze hooker and make her get in
    FreezeEntityPosition(hooker, false)
    SetEntityAsMissionEntity(hooker, true, true)
    SetBlockingOfNonTemporaryEvents(hooker, true)
    TaskEnterVehicle(hooker, vehicle, -1, 1, 1.0, 1, 0)  -- Seat 1 = passenger

    -- Remove blip
    if hookerBlip then
        RemoveBlip(hookerBlip)
        hookerBlip = nil
    end

    -- Wait for hooker to get in
    local timeout = 0
    while not IsPedInAnyVehicle(hooker, false) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end

    FreezeEntityPosition(vehicle, false)
    isBusy = false

    lib.notify({
        title = 'DPS Hookers',
        description = lib.locale('hooker.get_in'),
        type = 'info'
    })
end

--- Make hooker leave vehicle
---@param vehicle number Vehicle handle
local function hookerLeaveVehicle(vehicle)
    if not hooker or not DoesEntityExist(hooker) then return end

    isSignaling = false
    TaskLeaveVehicle(hooker, vehicle, 0)
    SetPedAsNoLongerNeeded(hooker)

    deleteHooker()
end

--- Open service selection context menu
local function openServiceMenu()
    if not hooker or isBusy then return end

    local options = {
        {
            title = lib.locale('menu.blowjob_title'),
            description = lib.locale('menu.blowjob_desc', {price = Config.Prices.Blowjob}),
            icon = 'hand-holding-dollar',
            onSelect = function()
                TriggerServerEvent('dps-hookers:server:pay', {type = 'blowjob'})
            end
        },
        {
            title = lib.locale('menu.sex_title'),
            description = lib.locale('menu.sex_desc', {price = Config.Prices.Sex}),
            icon = 'heart',
            onSelect = function()
                TriggerServerEvent('dps-hookers:server:pay', {type = 'havesex'})
            end
        },
        {
            title = lib.locale('menu.dismiss_title'),
            description = lib.locale('menu.dismiss_desc'),
            icon = 'door-open',
            onSelect = function()
                hookerLeaveVehicle(cachedVehicle)
            end
        }
    }

    lib.registerContext({
        id = 'dps_hooker_services',
        title = lib.locale('menu.title'),
        options = options
    })

    lib.showContext('dps_hooker_services')
end

--- Count nearby witness NPCs (for police dispatch)
---@return number count of nearby civilian peds
local function countWitnesses()
    if not Config.Police.RequireWitness then return 1 end  -- Skip check if disabled

    local witnessCount = 0
    local radius = Config.Police.WitnessRadius or 30.0
    local playerCoords = cachedCoords

    -- Get nearby peds
    local peds = GetGamePool('CPed')
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and ped ~= hooker then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)

            if dist <= radius then
                -- Check if ped can "see" the player (not in vehicle, not dead)
                if not IsPedInAnyVehicle(ped, false) and not IsPedDeadOrDying(ped, true) then
                    witnessCount = witnessCount + 1
                end
            end
        end
    end

    return witnessCount
end

--- Perform blowjob service
local function performBlowjob()
    if not hooker or isBusy then return end

    isBusy = true
    updateCache()
    local coords = cachedCoords

    -- Count witnesses and roll for police BEFORE service starts
    local witnesses = countWitnesses()
    TriggerServerEvent('dps-hookers:server:policeRoll', coords, witnesses)

    -- Progress bar with animations
    loadAnimDict("oddjobs@towing")

    -- Start animations
    playAnim(hooker, "oddjobs@towing", "f_blow_job_loop")
    playAnim(cachedPed, "oddjobs@towing", "m_blow_job_loop")

    local success = lib.progressCircle({
        duration = Config.Animations.BlowjobDuration,
        position = 'bottom',
        label = lib.locale('hooker.activity_blowjob'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    -- Clear animations
    ClearPedTasks(cachedPed)
    if hooker and DoesEntityExist(hooker) then
        ClearPedTasks(hooker)
    end

    if success then
        -- Voice lines
        if hooker and DoesEntityExist(hooker) then
            PlayAmbientSpeech1(hooker, "Sex_Finished", "Speech_Params_Force_Shouted_Clear")
            Wait(2000)
            PlayAmbientSpeech1(hooker, "Hooker_Offer_Again", "Speech_Params_Force_Shouted_Clear")
        end
    else
        lib.notify({
            title = 'DPS Hookers',
            description = lib.locale('notifications.cancelled'),
            type = 'error'
        })
    end

    isBusy = false
end

--- Perform sex service
local function performSex()
    if not hooker or isBusy then return end

    isBusy = true
    updateCache()
    local coords = cachedCoords

    -- Count witnesses and roll for police BEFORE service starts
    local witnesses = countWitnesses()
    TriggerServerEvent('dps-hookers:server:policeRoll', coords, witnesses)

    -- Progress bar with animations
    loadAnimDict("mini@prostitutes@sexlow_veh")

    -- Start animations
    playAnim(hooker, "mini@prostitutes@sexlow_veh", "low_car_sex_loop_female")
    playAnim(cachedPed, "mini@prostitutes@sexlow_veh", "low_car_sex_loop_player")

    local success = lib.progressCircle({
        duration = Config.Animations.SexDuration,
        position = 'bottom',
        label = lib.locale('hooker.activity_sex'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    -- Clear animations
    ClearPedTasks(cachedPed)
    if hooker and DoesEntityExist(hooker) then
        ClearPedTasks(hooker)
    end

    if success then
        -- Voice lines
        if hooker and DoesEntityExist(hooker) then
            PlayAmbientSpeech1(hooker, "Sex_Finished", "Speech_Params_Force_Shouted_Clear")
            Wait(2000)
            PlayAmbientSpeech1(hooker, "Hooker_Offer_Again", "Speech_Params_Force_Shouted_Clear")
        end
    else
        lib.notify({
            title = 'DPS Hookers',
            description = lib.locale('notifications.cancelled'),
            type = 'error'
        })
    end

    isBusy = false
end

--[[ ===================================================== ]]--
--[[                    CLIENT EVENTS                      ]]--
--[[ ===================================================== ]]--

--- Handle age restriction
RegisterNetEvent('dps-hookers:client:ageRestricted', function()
    lib.notify({
        title = lib.locale('age_verification.title'),
        description = lib.locale('age_verification.rejected'),
        type = 'error',
        duration = 10000
    })
end)

--- Handle successful join
RegisterNetEvent('dps-hookers:client:onJoin', function(data)
    if data.status then
        ageVerified = true
        createPimp()
    end
end)

--- Handle service action from server
RegisterNetEvent('dps-hookers:client:action', function(data)
    if not data.status then return end

    if data.type == 'blowjob' then
        performBlowjob()
    elseif data.type == 'havesex' then
        performSex()
    end
end)

--- Handle police notification
RegisterNetEvent('dps-hookers:client:policeNotified', function(data)
    lib.notify({
        title = 'DPS Hookers',
        description = lib.locale('police.witness_alert'),
        type = 'warning',
        duration = 5000
    })
end)

--- Handle qs-dispatch trigger (DPSRP 1.5)
RegisterNetEvent('dps-hookers:client:triggerDispatch', function(data)
    -- Get player info from qs-dispatch
    local playerData = exports['qs-dispatch']:GetPlayerInfo()

    -- Trigger qs-dispatch server event with proper format
    TriggerServerEvent("qs-dispatch:server:CreateDispatchCall", {
        job = "police",
        callLocation = data.coords,
        callCode = { code = data.code or "10-69", snippet = data.title or "Suspicious Activity" },
        message = data.message or "Suspicious activity reported in the area.",
        flashes = false,
        image = nil,
        blip = {
            sprite = 480,
            scale = 1.2,
            colour = 1,
            flashes = false,
            text = data.title or "Suspicious Activity",
            time = (data.blipTime or 120) * 1000,
        },
        otherData = {
            {
                text = data.street or "Unknown Location",
                icon = "fas fa-map-marker-alt",
            }
        }
    })
end)

--[[ ===================================================== ]]--
--[[              LOD ZONE MANAGEMENT                      ]]--
--[[ ===================================================== ]]--

--- Initialize strip club zone for LOD optimization
local function initializeZones()
    -- Create a sphere zone around the strip club for LOD
    stripClubZone = lib.zones.sphere({
        coords = vector3(Config.PimpLocation.x, Config.PimpLocation.y, Config.PimpLocation.z),
        radius = DIST_MEDIUM,
        debug = false,
        onEnter = function()
            isNearPimp = true
        end,
        onExit = function()
            isNearPimp = false
        end
    })
end

--[[ ===================================================== ]]--
--[[                   MAIN THREAD LOOP                    ]]--
--[[ ===================================================== ]]--

--- Check if hooker should be cleaned up (player too far)
local function checkHookerCleanup()
    if not hooker or not DoesEntityExist(hooker) then return end
    if isBusy then return end

    local hookerCoords = GetEntityCoords(hooker)
    local dist = #(cachedCoords - hookerCoords)

    -- If player drove too far away and hooker isn't in vehicle, cleanup
    if dist > DIST_FAR and not IsPedInAnyVehicle(hooker, false) then
        lib.notify({
            title = 'DPS Hookers',
            description = 'The hooker got tired of waiting and left.',
            type = 'info'
        })
        deleteHooker()
    end
end

--- Optimized main loop with LOD system
CreateThread(function()
    -- Wait for player to load
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    -- Initialize zones
    initializeZones()

    while true do
        -- Update cache at fixed interval
        updateCache()

        -- Calculate sleep based on state
        local sleep = 2000  -- Default: very low frequency

        -- If we have an active hooker, check more frequently
        if ageVerified and hooker and DoesEntityExist(hooker) then
            local hookerCoords = GetEntityCoords(hooker)
            local dist = #(cachedCoords - hookerCoords)

            -- Check for cleanup
            checkHookerCleanup()

            if dist < DIST_NEAR then
                sleep = 100  -- Near hooker
            elseif dist < DIST_MEDIUM then
                sleep = 500  -- Medium distance
            else
                sleep = 1000  -- Far but still tracking
            end

            -- Vehicle interaction logic
            if cachedVehicle ~= 0 and not isBusy then
                local isDriver = GetPedInVehicleSeat(cachedVehicle, -1) == cachedPed

                -- Hooker not in vehicle yet - waiting at spawn
                if not IsPedInAnyVehicle(hooker, false) then
                    if dist < DIST_INTERACTION then
                        sleep = 0  -- Need immediate response

                        if not isSignaling and isDriver then
                            draw3DText(hookerCoords + vector3(0, 0, 1.0), lib.locale('hooker.press_signal', {
                                key = Config.Controls.Signal.label
                            }))
                        end

                        -- Press E to signal hooker
                        if IsControlJustReleased(0, Config.Controls.Signal.key) and isDriver then
                            hookerEnterVehicle(cachedVehicle)
                        end
                    end

                -- Hooker is in vehicle - show service options
                elseif IsPedInAnyVehicle(hooker, false) and IsVehicleStopped(cachedVehicle) then
                    sleep = 0  -- Need immediate response

                    if isDriver then
                        -- E to open menu (replaces arrow keys)
                        if IsControlJustReleased(0, Config.Controls.Signal.key) then
                            openServiceMenu()
                        end

                        -- Legacy arrow key support
                        if IsControlJustReleased(0, Config.Controls.Blowjob.key) then
                            TriggerServerEvent('dps-hookers:server:pay', {type = 'blowjob'})
                        end

                        if IsControlJustReleased(0, Config.Controls.Sex.key) then
                            TriggerServerEvent('dps-hookers:server:pay', {type = 'havesex'})
                        end

                        if IsControlJustReleased(0, Config.Controls.Dismiss.key) or
                           IsControlJustReleased(0, Config.Controls.Dismiss.alt) then
                            hookerLeaveVehicle(cachedVehicle)
                        end
                    end
                end
            end
        elseif isNearPimp then
            -- Near pimp but no hooker - medium frequency for target responsiveness
            sleep = 500
        end

        Wait(sleep)
    end
end)

--[[ ===================================================== ]]--
--[[                  RESOURCE LIFECYCLE                   ]]--
--[[ ===================================================== ]]--

--- Trigger server on resource start
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerServerEvent('dps-hookers:server:onJoin')
    end
end)

--- Clean up on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        deleteHooker()
        deletePimp()

        -- Remove zone
        if stripClubZone then
            stripClubZone:remove()
        end
    end
end)

--- Trigger server when player loads
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('dps-hookers:server:onJoin')
end)

--- Clean up when player unloads (logout/disconnect)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    deleteHooker()
    deletePimp()
    ageVerified = false

    if stripClubZone then
        stripClubZone:remove()
        stripClubZone = nil
    end
end)

print("^2[DPS Hookers]^7 Client initialized (optimized)")
